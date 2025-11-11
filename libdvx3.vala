/* -*- coding: utf-8 -*- */

/**
 * libdvx3 - Encrypted archive library
 * 
 * Provides secure encryption/decryption using:
 * tar → zstd → Argon2id → Secretbox (XSalsa20-Poly1305)
 */

using GLib;
using Json;
using Sodium;

/* Direct C bindings for low-level POSIX I/O */
[CCode (cname = "read", cheader_filename = "unistd.h")]
extern ssize_t posix_read (int fd, void* buf, size_t count);
[CCode (cname = "write", cheader_filename = "unistd.h")]
extern ssize_t posix_write (int fd, void* buf, size_t count);
[CCode (cname = "close", cheader_filename = "unistd.h")]
extern int posix_close (int fd);
#if POSIX
[CCode (cname = "waitpid", cheader_filename = "sys/wait.h")]
extern int posix_waitpid (int pid, out int status, int options);
#endif

namespace Dvx3 {

    /* Configuration constants */
    public const size_t CHUNK_SIZE = 1024 * 1024;  // 1 MiB
    public const uint   ARGON_T   = 2;             // Argon2 time cost
    public const uint   ARGON_M   = 64000;         // Argon2 memory (KiB)
    public const uint   ARGON_P   = 4;             // Argon2 parallelism
    
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

    /* Big-endian helpers */
    private uint8[] uint64_to_be (uint64 v) {
        uint8[] buf = new uint8[8];
        for (int i = 0; i < 8; i++) {
            buf[7 - i] = (uint8) (v >> (i * 8));
        }
        return buf;
    }

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
     * 
     * @param processed Number of bytes processed so far
     * @param total Total bytes to process (may be estimate)
     * @param output_bytes Number of output bytes written
     */
    public delegate void ProgressCallback (uint64 processed, uint64 total, uint64 output_bytes);

    /**
     * Encrypt a directory to an encrypted archive
     * 
     * @param src_dir Source directory to encrypt
     * @param out_file Output .dvx3 file
     * @param password Password for encryption
     * @param exclude_path Optional path to exclude from archive (for in-place mode)
     * @param progress Optional progress callback
     * @throws Error on encryption failure
     */
    public void encrypt (
        File src_dir,
        File out_file,
        string password,
        string? exclude_path = null,
        ProgressCallback? progress = null
    ) throws Error {
        
        var src_path = src_dir.get_path ();
        
        /* Calculate source size for progress estimation (compressed will be ~30-50% of this) */
        uint64 source_size = compute_directory_size (src_dir, exclude_path);
        uint64 estimated_compressed = source_size / 2; // Rough estimate: 50% compression
        
        /* Generate salt and derive key */
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

        var gen = new Json.Generator();
        var root_node = new Json.Node(Json.NodeType.OBJECT);
        root_node.set_object(placeholder_header);
        gen.set_root(root_node);
        var placeholder_json_str = gen.to_data (null);
        uint8[] placeholder_json = new uint8[placeholder_json_str.length];
        for (int i = 0; i < placeholder_json_str.length; i++) {
            placeholder_json[i] = (uint8) placeholder_json_str[i];
        }
        uint32 placeholder_len = (uint32) placeholder_json.length;

        /* Open output file and write placeholder header */
        size_t written;
        var fout = out_file.replace (null, false, FileCreateFlags.PRIVATE);
        fout.write_all (uint32_to_be (placeholder_len), out written);
        fout.write_all (placeholder_json, out written);

        /* Create chunk encoder */
        var encoder = new ChunkEncoder (fout, master);

        /* Launch tar | zstd pipeline */
        string[] pipeline_cmd;
        if (exclude_path != null) {
            var exclude_rel = exclude_path.has_prefix(src_path + "/") 
                ? exclude_path.substring(src_path.length + 1) 
                : exclude_path;
            pipeline_cmd = {
                "sh", "-c",
                "tar -c --exclude='%s' -C '%s' . | zstd -T16 -22 -c".printf(
                    exclude_rel.replace("'", "'\\''"),
                    src_path.replace("'", "'\\''")
                )
            };
        } else {
            pipeline_cmd = {
                "sh", "-c",
                "tar -c -C '%s' . | zstd -T16 -22 -c".printf(
                    src_path.replace("'", "'\\''")
                )
            };
        }

        int pipe_stdout;
        Pid child_pid;
        Process.spawn_async_with_pipes (
            null,
            pipeline_cmd,
            null,
            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
            null,
            out child_pid,
            null,
            out pipe_stdout,
            null);

        uint64 compressed_bytes = 0;

        /* Read from pipeline, encrypt and write chunks */
        uint8[] buffer = new uint8[CHUNK_SIZE];
        while (true) {
            ssize_t bytes_read = posix_read (pipe_stdout, buffer, CHUNK_SIZE);
            if (bytes_read <= 0)
                break;
            
            uint8[] blk = buffer[0:bytes_read];
            compressed_bytes += (uint64) bytes_read;
            encoder.write (blk);
            
            if (progress != null)
                progress (compressed_bytes, estimated_compressed, encoder.cipher_bytes);
        }

        posix_close (pipe_stdout);
        encoder.close ();

        /* Wait for pipeline to complete */
#if POSIX
        int child_status;
        posix_waitpid (child_pid, out child_status, 0);
        if (child_status != 0)
            throw new IOError.FAILED ("tar|zstd pipeline failed");
#endif
        Process.close_pid (child_pid);

        /* Rewrite header with correct chunk count */
        var final_header = new Json.Object();
        final_header.set_string_member("salt", Base64.encode(salt));
        final_header.set_int_member("chunks", (int64)encoder.chunks);
        final_header.set_int_member("last_chunk_size", (int64)encoder.last_chunk_size);
        final_header.set_object_member("argon2", argon);

        gen = new Json.Generator();
        root_node = new Json.Node(Json.NodeType.OBJECT);
        root_node.set_object(final_header);
        gen.set_root(root_node);
        var final_json_str = gen.to_data (null);
        uint8[] final_json = new uint8[final_json_str.length];
        for (int i = 0; i < final_json_str.length; i++) {
            final_json[i] = (uint8) final_json_str[i];
        }
        uint32 final_len = (uint32) final_json.length;

        if (final_len != placeholder_len)
            throw new IOError.FAILED ("Header size changed unexpectedly");

        /* Rewind and overwrite header */
        fout.seek (0, SeekType.SET);
        fout.write_all (uint32_to_be (final_len), out written);
        fout.write_all (final_json, out written);
        fout.flush ();
        fout.close ();
    }

    /**
     * Decrypt an encrypted archive to a directory
     * 
     * @param enc_file Encrypted .dvx3 file
     * @param dst_dir Destination directory to extract to
     * @param password Password for decryption
     * @param progress Optional progress callback
     * @throws Error on decryption failure
     */
    public void decrypt (
        File enc_file,
        File dst_dir,
        string password,
        ProgressCallback? progress = null
    ) throws Error {
        
        var enc_info = enc_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
        uint64 enc_bytes = enc_info.get_attribute_uint64 (FileAttribute.STANDARD_SIZE);

        var fin = enc_file.read();
        uint8[] len_buf = fin.read_bytes(4).get_data();
        if (len_buf.length != 4)
            throw new IOError.FAILED("Missing header length");
        
        uint32 hlen = be_to_uint32(len_buf);
        uint8[] hdr_json = fin.read_bytes((size_t)hlen).get_data();

        var parser = new Json.Parser();
        parser.load_from_data ((string) hdr_json, (ssize_t) hdr_json.length);
        var hdr = parser.get_root().get_object();

        var salt = Base64.decode(hdr.get_string_member("salt"));
        var master = derive_key(password, salt);
        uint64 chunks = (uint64)hdr.get_int_member("chunks");
        uint64 last = (uint64)hdr.get_int_member("last_chunk_size");

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

        for (uint64 i = 0; i < chunks; i++) {
            uint8[] nonce = fin.read_bytes((uint)Sodium.Symmetric.NONCE_BYTES).get_data();
            if (nonce.length != Sodium.Symmetric.NONCE_BYTES)
                throw new IOError.FAILED ("Truncated nonce at chunk %llu".printf(i));

            uint64 expected_plain = (i == chunks - 1) ? last : CHUNK_SIZE;
            uint64 ct_len = expected_plain + SECRETBOX_MAC;
            uint8[] ct = fin.read_bytes((size_t)ct_len).get_data();
            if (ct.length != (size_t)ct_len)
                throw new IOError.FAILED ("Truncated ciphertext at chunk %llu".printf(i));

            uint8[] plain = new uint8[(int)expected_plain];
            int ret = Sodium.Symmetric.secretbox_open (
                plain,
                ct,
                (ulong)ct.length,
                nonce,
                master
            );
            if (ret != 0)
                throw new IOError.FAILED ("Decryption failed at chunk %llu (wrong password?)".printf(i));

            ssize_t written = posix_write (pipe_stdin, plain, plain.length);
            if (written != plain.length)
                throw new IOError.FAILED ("Failed to write decrypted data to pipe");

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
    }
}
