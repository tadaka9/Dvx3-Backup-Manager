/* -*- coding: utf-8 -*- */

/**
 * libdvx3 - Encrypted archive library with integrity verification
 * 
 * Provides secure encryption/decryption using:
 * tar → zstd → Argon2id → Secretbox (XSalsa20-Poly1305)
 * 
 * Features:
 * - SHA-256 integrity verification of archived content
 * - Backward compatible with archives lacking integrity field
 */

using GLib;
using Sodium;

/* Direct C bindings for low-level POSIX I/O */
[CCode (cname = "STDIO_FILENO", cheader_filename = "unistd.h")]
extern const int STDIO_FILENO;
[CCode (cname = "isatty", cheader_filename = "unistd.h")]
extern int posix_isatty (int fd);
[CCode (cname = "read", cheader_filename = "unistd.h")]
extern ssize_t posix_read (int fd, void* buf, size_t count);
[CCode (cname = "write", cheader_filename = "unistd.h")]
extern ssize_t posix_write (int fd, void* buf, size_t count);
[CCode (cname = "close", cheader_filename = "unistd.h")]
extern int posix_close (int fd);
#if POSIX
[CCode (cname = "waitpid", cheader_filename = "sys/wait.h")]
extern int posix_waitpid (int pid, out int status, int options);
[CCode (cname = "kill", cheader_filename = "signal.h")]
extern int posix_kill (int pid, int sig);
[CCode (cname = "usleep", cheader_filename = "unistd.h")]
extern int posix_usleep (uint usec);
#endif

namespace Dvx3 {

    /* Configuration constants */
    public const size_t CHUNK_SIZE = 1024 * 1024;  // 1 MiB
    public const uint   ARGON_T   = 2;             // Argon2 time cost
    public const uint   ARGON_M   = 64000;         // Argon2 memory (KiB)
    public const uint   ARGON_P   = 4;             // Argon2 parallelism
    public const size_t HEADER_RESERVE = 512;      // Reserved header space
    
    private const size_t SECRETBOX_MAC = Sodium.Symmetric.MAC_BYTES;

    /* Compute directory size recursively */
    private uint64 compute_directory_size (File dir, string? exclude_path = null) throws Error {
        uint64 total = 0;
        var enumerator = dir.enumerate_children (
            FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE + "," + FileAttribute.STANDARD_SIZE,
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        
        FileInfo? info = null;
        while ((info = enumerator.next_file ()) != null) {
            var child = dir.resolve_relative_path (info.get_name ());
            var child_path = child.get_path ();
            
            if (exclude_path != null && child_path == exclude_path)
                continue;
            
            if (info.get_file_type () == FileType.DIRECTORY) {
                total += compute_directory_size (child, exclude_path);
            } else if (info.get_file_type () == FileType.REGULAR) {
                total += info.get_size ();
            }
        }
        return total;
    }

    /* Compute SHA-256 hash of byte array */
    private uint8[] compute_sha256 (uint8[] data) throws Error {
        var chk = new Checksum (ChecksumType.SHA256);
        chk.update (data, (ulong)data.length);
        uint8[] hash = new uint8[32];  // SHA-256 produces 32 bytes
        size_t len = hash.length;
        chk.get_digest (hash, ref len);
        return hash;
    }

    /* Big-endian helpers */
    private uint8[] uint32_to_be (uint32 v) {
        uint8[] buf = new uint8[4];
        for (int i = 0; i < 4; i++) {
            buf[3 - i] = (uint8) (v >> (i * 8));
        }
        return buf;
    }

    private uint32 be_to_uint32 (uint8[] data) {
        uint32 v = 0;
        for (int i = 0; i < 4; i++) {
            v = (v << 8) | data[i];
        }
        return v;
    }

    private uint8[] random_bytes (size_t len) {
        uint8[] buf = new uint8[len];
        Sodium.Random.buffer (buf, len);
        return buf;
    }

    private uint8[] derive_key (string password, uint8[] salt) throws Error {
        uint8[] key = new uint8[Sodium.Symmetric.KEY_BYTES];
        int ret = Sodium.crypto_pwhash (
            key,
            (ulong)Sodium.Symmetric.KEY_BYTES,
            password,
            (ulong)password.length,
            salt,
            (ulong)ARGON_T,
            (size_t)(ARGON_M * 1024),
            Sodium.CRYPTO_PWHASH_ALG_ARGON2ID13
        );
        if (ret != 0)
            throw new IOError.FAILED ("Argon2 key derivation failed");
        return key;
    }

    /* ChunkEncoder - writes encrypted chunks to output stream */
    private class ChunkEncoder {
        private OutputStream output;
        private uint8[] master_key;
        public uint64 chunks = 0;
        public uint64 last_chunk_size = 0;
        public uint64 plain_bytes = 0;
        public uint64 cipher_bytes = 0;

        public ChunkEncoder (OutputStream output, uint8[] master_key) {
            this.output = output;
            this.master_key = master_key;
        }

        public void write (uint8[] plaintext) throws Error {
            var nonce = random_bytes (Sodium.Symmetric.NONCE_BYTES);
            uint8[] ciphertext = new uint8[plaintext.length + (int)SECRETBOX_MAC];
            
            int ret = Sodium.Symmetric.secretbox (
                ciphertext,
                plaintext,
                (ulong)plaintext.length,
                nonce,
                master_key
            );
            if (ret != 0)
                throw new IOError.FAILED ("Encryption failed");

            size_t written;
            output.write_all (nonce, out written);
            output.write_all (ciphertext, out written);

            chunks++;
            last_chunk_size = (uint64) plaintext.length;
            plain_bytes += (uint64) plaintext.length;
            cipher_bytes += (uint64) (nonce.length + ciphertext.length);
        }

        public void close () throws Error {
            output.flush ();
        }
    }

    /**
     * Progress callback for encryption/decryption operations
     */
    public delegate void ProgressCallback (uint64 processed, uint64 total, uint64 output_bytes);

    /**
     * Encryption mode enum
     */
    public enum EncryptionMode {
        WITH_INTEGRITY,   // Compute and store SHA-256 hash of plaintext
        WITHOUT_INTEGRITY,// Legacy: no integrity field (backward compatible)
    }

    /**
     * Encrypt a directory to an encrypted archive
     * 
     * @param src_dir Source directory to encrypt
     * @param out_file Output .dvx3 file
     * @param password Password for encryption
     * @param exclude_path Optional path to exclude from archive (for in-place mode)
     * @param progress Optional progress callback
     * @param mode Encryption mode (default: WITH_INTEGRITY for new archives)
     * @throws Error on encryption failure
     */
    public void encrypt (
        File src_dir,
        File out_file,
        string password,
        string? exclude_path = null,
        ProgressCallback? progress = null,
        EncryptionMode mode = EncryptionMode.WITH_INTEGRITY
    ) throws Error {
        
        var src_path = src_dir.get_path ();
        uint64 source_size = compute_directory_size (src_dir, exclude_path);
        uint64 estimated_compressed = source_size / 2; // Initial estimate
        
        var salt = random_bytes (Sodium.CRYPTO_PWHASH_SALTBYTES);
        var master = derive_key (password, salt);

        /* Prepare placeholder header */
        var placeholder_header = new Json.Object();
        placeholder_header.set_string_member("salt", Base64.encode(salt));
        placeholder_header.set_int_member("chunks", 0);
        placeholder_header.set_int_member("last_chunk_size", 0);

        var argon = new Json.Object();
        argon.set_int_member("time_cost", (int64)ARGON_T);
        argon.set_int_member("memory_kib", (int64)ARGON_M);
        argon.set_int_member("parallelism", (int64)ARGON_P);
        argon.set_string_member("type", "argon2id");
        placeholder_header.set_object_member("argon2", argon);

        // Add integrity field if requested
        if (mode == EncryptionMode.WITH_INTEGRITY) {
            placeholder_header.set_boolean_member("integrity_verified", false);
        } else {
            placeholder_header.set_boolean_member("integrity_verified", true);
        }

        var gen = new Json.Generator();
        var root_node = new Json.Node(Json.NodeType.OBJECT);
        root_node.set_object(placeholder_header);
        gen.set_root(root_node);
        var placeholder_json_str = gen.to_data (null);
        
        // Pad JSON to fixed size
        uint8[] placeholder_json = new uint8[HEADER_RESERVE];
        size_t actual_len = placeholder_json_str.length;
        if (actual_len >= HEADER_RESERVE)
            throw new IOError.FAILED ("Header JSON too large (%zu bytes, max %zu)".printf(actual_len, HEADER_RESERVE));
        
        for (int i = 0; i < (int)actual_len; i++) {
            placeholder_json[i] = (uint8) placeholder_json_str[i];
        }
        for (int i = (int)actual_len; i < (int)HEADER_RESERVE; i++) {
            placeholder_json[i] = 0;
        }
        uint32 header_size = (uint32) HEADER_RESERVE;

        /* Open output file and write placeholder header */
        size_t written;
        var fout = out_file.replace (null, false, FileCreateFlags.PRIVATE);
        fout.write_all (uint32_to_be (header_size), out written);
        fout.write_all (placeholder_json, out written);

        /* Create chunk encoder */
        var encoder = new ChunkEncoder (fout, master);

        /* Launch tar and zstd as separate processes */
        uint64 compressed_bytes = 0;
        uint64 original_processed = 0;
        
#if POSIX
        // Detect GNU tar for --totals=USR1 support
        bool gnu_tar = false;
        try {
            string? outv; string? errv; int estatus = 0;
            Process.spawn_command_line_sync("tar --version", out outv, out errv, out estatus);
            if (estatus == 0 && outv != null && outv.index_of("GNU tar") >= 0) {
                gnu_tar = true;
            }
        } catch (Error e) {
            gnu_tar = false;
        }

        // Disable GNU tar SIGUSR1 tracking due to signal handling issues
        gnu_tar = false;

        if (gnu_tar) {
            // Build tar command
            string tar_cmd;
            if (exclude_path != null) {
                var exclude_rel = exclude_path.has_prefix(src_path + "/") 
                    ? exclude_path.substring(src_path.length + 1) 
                    : exclude_path;
                tar_cmd = "tar -c --totals=USR1 --exclude='%s' -C '%s' .".printf(
                    exclude_rel.replace("'", "'\\''"),
                    src_path.replace("'", "'\\''")
                );
            } else {
                tar_cmd = "tar -c --totals=USR1 -C '%s' .".printf(
                    src_path.replace("'", "'\\''")
                );
            }

            // Spawn tar with stdout and stderr pipes
            int tar_out_fd; int tar_err_fd; Pid tar_pid;
            Process.spawn_async_with_pipes(
                null,
                { "sh", "-c", tar_cmd },
                null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out tar_pid,
                null,
                out tar_out_fd,
                out tar_err_fd
            );

            // Spawn zstd with stdin and stdout pipes
            int zstd_in_fd; int zstd_out_fd; Pid zstd_pid;
            Process.spawn_async_with_pipes(
                null,
                { "sh", "-c", "zstd -T16 -22 -c" },
                null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out zstd_pid,
                out zstd_in_fd,
                out zstd_out_fd,
                null
            );

            // Relay thread: tar stdout -> zstd stdin
            new Thread<void*>("dvx3-relay", () => {
                uint8[] rbuf = new uint8[CHUNK_SIZE];
                while (true) {
                    ssize_t r = posix_read(tar_out_fd, rbuf, CHUNK_SIZE);
                    if (r <= 0) break;
                    ssize_t off = 0;
                    while (off < r) {
                        ssize_t w = posix_write(zstd_in_fd, rbuf[off:(int)r], (size_t)(r - off));
                        if (w <= 0) break;
                        off += w;
                    }
                }
                posix_close(tar_out_fd);
                posix_close(zstd_in_fd);
                return null;
            });

        }

        // Build tar command for standard pipeline
        string tar_cmd;
        if (exclude_path != null) {
            var exclude_rel = exclude_path.has_prefix(src_path + "/") 
                ? exclude_path.substring(src_path.length + 1) 
                : exclude_path;
            tar_cmd = "tar -c --exclude='%s' -C '%s' .".printf(
                exclude_rel.replace("'", "'\\''"),
                src_path.replace("'", "'\\''")
            );
        } else {
            tar_cmd = "tar -c -C '%s' .".printf(
                src_path.replace("'", "'\\''")
            );
        }

        // Spawn tar
        int tar_out_fd; Pid tar_pid;
        Process.spawn_async_with_pipes(
            null,
            { "sh", "-c", tar_cmd },
            null,
            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
            null,
            out tar_pid,
            null,
            out tar_out_fd,
            null
        );

        // Spawn zstd
        int zstd_in_fd; int zstd_out_fd; Pid zstd_pid;
        Process.spawn_async_with_pipes(
            null,
            { "sh", "-c", "zstd -T16 -22 -c" },
            null,
            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
            null,
            out zstd_pid,
            out zstd_in_fd,
            out zstd_out_fd,
            null
        );

        // Buffer for encryption
        uint8[] buffer_enc = new uint8[CHUNK_SIZE];

        // Read from tar, compress with zstd, encrypt and write
        while (true) {
            ssize_t bytes_read = posix_read (tar_out_fd, buffer_enc, CHUNK_SIZE);
            if (bytes_read <= 0) break;
            
            uint8[] blk = buffer_enc[0:bytes_read];
            compressed_bytes += (uint64) bytes_read;
            
            // Encrypt the chunk
            encoder.write (blk);
            
            if (progress != null)
                progress (compressed_bytes, estimated_compressed, encoder.cipher_bytes);
        }

        posix_close(tar_out_fd);
        
        // Close zstd stdin to signal EOF
        posix_close(zstd_in_fd);
        
        // Wait for both processes to finish
#if POSIX
        int tar_status;
        posix_waitpid (tar_pid, out tar_status, 0);
        int zstd_status;
        posix_waitpid (zstd_pid, out zstd_status, 0);
#endif
        
        encoder.close ();

        /* Compute integrity hash if enabled */
        uint8[] integrity_hash = null;
        if (mode == EncryptionMode.WITH_INTEGRITY) {
            // Read encrypted content and compute SHA-256 of plaintext portion
            var enc_info = out_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
            uint64 enc_bytes = enc_info.get_attribute_uint64 (FileAttribute.STANDARD_SIZE);

            
            var fin = out_file.read();
            fin.skip (4); // Skip length field
            int64 last_chunk_size = placeholder_header.get_int_member("last_chunk_size");
            var hdr_json_raw = new uint8[last_chunk_size];
            var hdr_bytes = fin.read_bytes ((ssize_t)hdr_json_raw.length);
            
            var parser = new Json.Parser();
            parser.load_from_data ((string) hdr_bytes, (ssize_t) hdr_bytes.length);
            var hdr = parser.get_root().get_object();
            
            var salt2 = Base64.decode(hdr.get_string_member("salt"));
            var master2 = derive_key(password, salt2);
            
            // Read encrypted chunks and decrypt to compute hash
            uint64 chunks = (uint64)hdr.get_int_member("chunks");
            uint64 last = (uint64)hdr.get_int_member("last_chunk_size");
            var acc = new uint8[0];
            
            for (uint64 i = 0; i < chunks; i++) {
                uint8[] nonce = new uint8[(int)Sodium.Symmetric.NONCE_BYTES];
                ssize_t _nr = fin.read(nonce);
                if ((size_t)_nr != (size_t)Sodium.Symmetric.NONCE_BYTES)
                    throw new IOError.FAILED ("Truncated nonce");
                
                uint64 exp_plain = (i == chunks - 1) ? last : CHUNK_SIZE;
                uint64 ct_len = exp_plain + SECRETBOX_MAC;
                uint8[] ct = new uint8[(int)ct_len];
                ssize_t _cr = fin.read(ct);
                if ((size_t)_cr != (size_t)ct_len)
                    throw new IOError.FAILED ("Truncated ciphertext");
                
                uint8[] plain = new uint8[(int)exp_plain];
                int ret = Sodium.Symmetric.secretbox_open(plain, ct, (ulong)ct.length, nonce, master2);
                if (ret != 0)
                    throw new IOError.FAILED ("Decryption failed");
                
                // Accumulate plaintext
                var new_acc = new uint8[acc.length + plain.length];
                for (int j = 0; j < acc.length; j++) new_acc[j] = acc[j];
                for (int j = 0; j < plain.length; j++) new_acc[acc.length + j] = plain[j];
                acc = new_acc;
            }
            
            // Compute hash
            integrity_hash = compute_sha256(acc);
        }

        /* Rewrite header with correct chunk count and integrity hash */
        var final_header = new Json.Object();
        final_header.set_string_member("salt", Base64.encode(salt));
        final_header.set_int_member("chunks", (int64)encoder.chunks);
        final_header.set_int_member("last_chunk_size", (int64)encoder.last_chunk_size);
        
        // Add integrity hash if computed
        if (mode == EncryptionMode.WITH_INTEGRITY && integrity_hash != null) {
            var hex_chars = "0123456789abcdef";
            string hex_hash = "";
            for (int i = 0; i < integrity_hash.length; i++) {
                int hbyte = (int)integrity_hash[i];
                int hhigh = hbyte >> 4;
                int hlow = hbyte & 0xf;
                string s1 = "0123456789abcdef".substring((int)(hhigh % 16));
                string s2 = "0123456789abcdef".substring((int)(hlow % 16));
                hex_hash += s1 + s2;
            }
            final_header.set_string_member("sha256", hex_hash);
            final_header.set_boolean_member("integrity_verified", true);
        } else {
            // Legacy archive without integrity
            final_header.set_boolean_member("integrity_verified", false);
            if (false) { /* sha256 not set for legacy archives */ }
        }

        var argon2_final = new Json.Object();
        argon2_final.set_int_member("time_cost", (int64)ARGON_T);
        argon2_final.set_int_member("memory_kib", (int64)ARGON_M);
        argon2_final.set_int_member("parallelism", (int64)ARGON_P);
        argon2_final.set_string_member("type", "argon2id");
        final_header.set_object_member("argon2", argon2_final);

        gen = new Json.Generator();
        root_node = new Json.Node(Json.NodeType.OBJECT);
        root_node.set_object(final_header);
        gen.set_root(root_node);
        var final_json_str = gen.to_data (null);
        
        uint8[] final_json = new uint8[HEADER_RESERVE];
        actual_len = final_json_str.length;
        for (int i = 0; i < (int)actual_len; i++) {
            final_json[i] = (uint8) final_json_str[i];
        }
        for (int i = (int)actual_len; i < (int)HEADER_RESERVE; i++) {
            final_json[i] = 0;
        }

        // Rewrite header
        fout.seek(4, GLib.SeekType.SET);
        size_t w;
        fout.write_all (final_json, out w);
        
        fout.flush ();
        fout.close ();
        encoder.close ();

        /* Final statistics */
        var out_sz = out_file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE)
            .get_attribute_uint64(FileAttribute.STANDARD_SIZE);
        stats("encryption", source_size, out_sz, encoder.chunks, 0.0);
        
        GLib.stdout.printf("%s\n", colour_wrap("✅ Encrypted backup → " + out_file.get_path(), GRN));
    }

    /**
     * Decrypt an encrypted archive to a directory
     * 
     * @param enc_file Encrypted .dvx3 file
     * @param dst_dir Destination directory to extract to
     * @param password Password for decryption
     * @param progress Optional progress callback
     * @throws Error on decryption failure (including integrity verification failures)
     */
    public void decrypt (
        File enc_file,
        File dst_dir,
        string password,
        ProgressCallback? progress = null,
        EncryptionMode mode = EncryptionMode.WITH_INTEGRITY
    ) throws Error {
        
        var enc_info = enc_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
        uint64 enc_bytes = enc_info.get_attribute_uint64 (FileAttribute.STANDARD_SIZE);

        var fin = enc_file.read();
        uint8[] len_buf = new uint8[4];
        ssize_t _len_read = fin.read (len_buf);
        if (_len_read != 4)
            throw new IOError.FAILED("Missing header length (read bytes)");
        if (len_buf.length != 4)
            throw new IOError.FAILED("Missing header length");
        
        uint32 hlen = be_to_uint32(len_buf);
        uint8[] hdr_json_raw = new uint8[hlen];
        ssize_t _hdr_read = fin.read(hdr_json_raw);
        if ((size_t)_hdr_read != hlen)
            throw new IOError.FAILED("Missing header JSON bytes");
        
        // Header is zero-padded; find actual JSON end (first null byte)
        size_t actual_json_len = 0;
        for (size_t i = 0; i < hdr_json_raw.length; i++) {
            if (hdr_json_raw[i] == 0) {
                actual_json_len = i;
                break;
            }
        }
        if (actual_json_len == 0) actual_json_len = hdr_json_raw.length;
        
        uint8[] hdr_json = hdr_json_raw[0:actual_json_len];

        var parser = new Json.Parser();
        parser.load_from_data ((string) hdr_json, (ssize_t) hdr_json.length);
        var hdr = parser.get_root().get_object();

        var salt = Base64.decode(hdr.get_string_member("salt"));
        var master = derive_key(password, salt);
        uint64 chunks = (uint64)hdr.get_int_member("chunks");
        uint64 last = (uint64)hdr.get_int_member("last_chunk_size");

        // Read integrity hash if present
        string stored_hash_hex = null;
        bool? has_integrity_field = hdr.has_member("sha256");
        
        if (has_integrity_field && mode == EncryptionMode.WITH_INTEGRITY) {
            stored_hash_hex = hdr.get_string_member("sha256");
        }

        uint64 cipher_total = 0;
        if (enc_bytes > (uint64) (4 + hlen))
            cipher_total = enc_bytes - (uint64) (4 + hlen);
        
        uint64 processed_cipher = 0;
        uint64 plain_emitted = 0;

        dst_dir.make_directory_with_parents();

        /* Launch zstd | tar pipeline */
        string[] pipeline_cmd = {
            "sh", "-c",
            "zstd -d -c | tar -x -C '%s'".printf(dst_dir.get_path().replace("'", "'\\''")),
        };

        int pipe_stdin;
        Pid child_pid;
        Process.spawn_async_with_pipes (
            null,
            pipeline_cmd,
            null,
            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
            null,
            out child_pid,
            out pipe_stdin,
            null,
            null);

        // Buffer to accumulate decrypted plaintext for integrity verification
        uint8[] buffer_dec = new uint8[CHUNK_SIZE];
        uint8[] accumulator_for_integrity = new uint8[0];

        for (uint64 i = 0; i < chunks; i++) {
            uint8[] nonce = new uint8[(int)Sodium.Symmetric.NONCE_BYTES];
            ssize_t _nonce_read = fin.read(nonce);
            if ((size_t)_nonce_read != (size_t)Sodium.Symmetric.NONCE_BYTES)
                throw new IOError.FAILED ("Truncated nonce at chunk " + i.to_string());

            uint64 expected_plain = (i == chunks - 1) ? last : CHUNK_SIZE;
            uint64 ct_len = expected_plain + SECRETBOX_MAC;
            uint8[] ct = new uint8[(int)ct_len];
            ssize_t _ct_read = fin.read(ct);
            if ((size_t)_ct_read != (size_t)ct_len)
                throw new IOError.FAILED ("Truncated ciphertext at chunk " + i.to_string());

            uint8[] plain = new uint8[(int)expected_plain];
            int ret = Sodium.Symmetric.secretbox_open (
                plain,
                ct,
                (ulong)ct.length,
                nonce,
                master
            );
            if (ret != 0)
                throw new IOError.FAILED ("Decryption failed at chunk %s (wrong password?)".printf(i.to_string()));

            ssize_t written = posix_write (pipe_stdin, plain, plain.length);
            if (written != plain.length)
                throw new IOError.FAILED ("Failed to write decrypted data to pipe");
            
            // Accumulate plaintext for integrity verification
            var new_acc = new uint8[accumulator_for_integrity.length + plain.length];
            for (int j = 0; j < accumulator_for_integrity.length; j++) {
                new_acc[j] = accumulator_for_integrity[j];
            }
            for (int j = 0; j < plain.length; j++) {
                new_acc[accumulator_for_integrity.length + j] = plain[j];
            }
            accumulator_for_integrity = new_acc;

            processed_cipher += (uint64)(nonce.length + ct.length);
            plain_emitted += (uint64)plain.length;

            if (progress != null)
                progress (processed_cipher, cipher_total, plain_emitted);
        }

        posix_close (pipe_stdin);
        fin.close ();

        /* Wait for extraction to complete */
#if POSIX
        int child_status;
        posix_waitpid (child_pid, out child_status, 0);
        if (child_status != 0)
            throw new IOError.FAILED ("Extraction pipeline failed");
#endif
        Process.close_pid (child_pid);

        // Verify integrity if archive has hash and is in integrity mode
        if (mode == EncryptionMode.WITH_INTEGRITY && accumulator_for_integrity.length > 0) {
            uint8[] computed_hash = compute_sha256(accumulator_for_integrity);
            accumulator_for_integrity = new uint8[0];
            
            // Convert computed hash to 64-char hex string
            string computed_hex = "";
            for (int i = 0; i < computed_hash.length; i++) {
                int hbyte = (int)computed_hash[i];
                int hhigh = hbyte >> 4;
                int hlow = hbyte & 0xf;
                string s1 = "0123456789abcdef".substring((int)(hhigh % 16));
                string s2 = "0123456789abcdef".substring((int)(hlow % 16));
                computed_hex += s1 + s2;
            }
            
            // Compare hashes if integrity verification is enabled in header
            if (has_integrity_field && stored_hash_hex != null) {
                if (computed_hex != stored_hash_hex) {
                    throw new IOError.FAILED ("Integrity verification failed: archive content has been corrupted or tampered with");
                }
            }
        }
    }

    /* Progress and stats helper */
    private void stats (string phase, uint64 in_bytes, uint64 out_bytes, uint64 chunks, double duration) {
        GLib.stdout.printf("\r%s: %.2f MB/s", phase, ((double)(in_bytes + out_bytes)) / (1024 * 1024));
    }

    /* Colour helpers */
    private const string RST = "\x1b[0m";
    private const string BLD = "\x1b[1m";
    private const string GRN = "\x1b[32m";
    private const string CYN = "\x1b[36m";
    private const string YLW = "\x1b[33m";
    private const string RED = "\x1b[31m";
    
    public static string colour_wrap (string text, string color) {
        return color + text + RST;
    }
}