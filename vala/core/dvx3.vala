/* Canonical archive engine. GIO owns paths, streams, temporary files and processes. */
using GLib;

namespace Dvx3 {
    public const string VERSION = "1.0.0-dev";
    public const size_t CHUNK_SIZE = 1024 * 1024;
    public const uint ARGON_T = 2;
    public const uint ARGON_M = 64000;
    public const uint ARGON_P = 4;
    public const size_t HEADER_RESERVE = 512;
    public enum EncryptionMode { WITH_INTEGRITY, WITHOUT_INTEGRITY }
    public delegate void ProgressCallback (uint64 processed, uint64 total, uint64 output_bytes);

    internal void remove_tree (File file) throws Error {
        if (file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.DIRECTORY) {
            var entries = file.enumerate_children ("standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
            FileInfo? info;
            while ((info = entries.next_file ()) != null) remove_tree (file.get_child (info.get_name ()));
            entries.close ();
        }
        file.delete ();
    }

    internal void run (string[] argv, string? cwd = null, string? input = null, string? output = null) throws Error {
        var launcher = new SubprocessLauncher (SubprocessFlags.NONE);
        if (cwd != null) launcher.set_cwd (cwd);
        if (input != null) launcher.set_stdin_file_path (input);
        if (output != null) launcher.set_stdout_file_path (output);
        var process = launcher.spawnv (argv);
        process.wait_check ();
    }

    public string tar_program () throws Error {
        var override_path = Environment.get_variable ("DVX3_TAR");
        var name = override_path ?? (Environment.find_program_in_path ("gtar") != null ? "gtar" : "tar");
        var path = Environment.find_program_in_path (name);
        if (path == null) throw new IOError.NOT_FOUND ("Required archive tool not found: %s", name);
        return path;
    }

    public string[] codec_names () {
        string[] names = { "none", "zstd", "gzip", "bzip2", "xz", "lzma", "lz4", "brotli", "7z", "zpaq", "razor" };
        try {
            var profiles = codec_profiles ();
            foreach (var name in profiles.get_groups ()) {
                bool found = false;
                foreach (var existing in names) if (existing == name) found = true;
                if (!found) names += name;
            }
        } catch (Error e) { /* An absent optional profile file leaves built-in codecs available. */ }
        return names;
    }
    private KeyFile codec_profiles () throws Error {
        var key = new KeyFile ();
        var path = Environment.get_variable ("DVX3_CODECS") ??
            Path.build_filename (Environment.get_user_config_dir (), "dvx3", "codecs.ini");
        key.load_from_file (path, KeyFileFlags.NONE);
        return key;
    }

    private string codec_program (string codec) throws Error {
        string name;
        switch (codec) {
            case "none": return "";
            case "gzip": case "bzip2": case "xz": case "lz4": case "brotli": case "zstd": case "zpaq": name = codec; break;
            case "lzma": name = "xz"; break;
            case "7z": name = Environment.find_program_in_path ("7zz") != null ? "7zz" : "7z"; break;
            default:
                // A trusted local adapter accepts: compress|decompress INPUT OUTPUT.
                // No shell strings or executable paths are read from archive metadata.
                var key = codec_profiles ();
                if (key.has_key (codec, "adapter")) name = key.get_string (codec, "adapter");
                else {
                    var compress = key.get_string_list (codec, "compress");
                    var decompress = key.get_string_list (codec, "decompress");
                    if (compress.length == 0 || decompress.length == 0) throw new IOError.INVALID_DATA ("Empty codec command");
                    if (Environment.find_program_in_path (decompress[0]) == null)
                        throw new IOError.NOT_FOUND ("Decoder missing: %s", decompress[0]);
                    name = compress[0];
                }
                break;
        }
        var path = Environment.find_program_in_path (name);
        if (path == null) throw new IOError.NOT_FOUND ("Codec '%s' requires executable '%s'", codec, name);
        return path;
    }

    public bool codec_available (string codec) {
        try { validate_codec (codec, 0); return true; }
        catch (Error e) { return false; }
    }

    private void validate_codec (string codec, int depth) throws Error {
        if (depth > 8) throw new IOError.INVALID_DATA ("Codec pipeline nesting limit exceeded");
        if (!Regex.match_simple ("^[a-z0-9][a-z0-9_-]{0,63}$", codec))
            throw new IOError.INVALID_ARGUMENT ("Invalid codec identifier");
        switch (codec) {
            case "none": case "zstd": case "gzip": case "bzip2": case "xz": case "lzma":
            case "lz4": case "brotli": case "7z": case "zpaq": codec_program (codec); return;
            default:
                var key = codec_profiles ();
                if (key.has_key (codec, "pipeline")) {
                    var steps = key.get_string_list (codec, "pipeline");
                    if (steps.length == 0) throw new IOError.INVALID_DATA ("Empty codec pipeline");
                    foreach (var step in steps) validate_codec (step, depth + 1);
                } else codec_program (codec);
                return;
        }
    }

    private void transform (string codec, bool decompress, string dir, int depth = 0) throws Error {
        validate_codec (codec, depth);
        // Pipelines process files in private isolated stages and invert step order on restore.
        switch (codec) {
            case "none": case "zstd": case "gzip": case "bzip2": case "xz": case "lzma":
            case "lz4": case "brotli": case "7z": case "zpaq": break;
            default:
                var profiles = codec_profiles ();
                if (profiles.has_key (codec, "pipeline")) {
                    var steps = profiles.get_string_list (codec, "pipeline");
                    string current = Path.build_filename (dir, decompress ? "payload.bin" : "payload.tar");
                    for (int i = 0; i < steps.length; i++) {
                        var stage = Path.build_filename (dir, "stage-" + i.to_string ());
                        File.new_for_path (stage).make_directory ();
                        File.new_for_path (current).copy (File.new_for_path (Path.build_filename (stage, decompress ? "payload.bin" : "payload.tar")), FileCopyFlags.NONE);
                        transform (steps[decompress ? steps.length - i - 1 : i], decompress, stage, depth + 1);
                        current = Path.build_filename (stage, decompress ? "payload.tar" : "payload.bin");
                    }
                    File.new_for_path (current).copy (File.new_for_path (Path.build_filename (dir, decompress ? "payload.tar" : "payload.bin")), FileCopyFlags.NONE);
                    return;
                }
                break;
        }
        var program = codec_program (codec);
        var raw = Path.build_filename (dir, "payload.tar");
        var packed = Path.build_filename (dir, "payload.bin");
        string input = decompress ? packed : raw;
        string output = decompress ? raw : packed;
        if (codec == "none") { File.new_for_path (input).copy (File.new_for_path (output), FileCopyFlags.NONE); return; }
        switch (codec) {
            case "zstd": case "gzip": case "bzip2": case "xz": case "lz4": case "brotli":
                run ({ program, decompress ? "-dc" : "-c" }, dir, input, output);
                break;
            case "lzma":
                run ({ program, "--format=lzma", decompress ? "-dc" : "-c" }, dir, input, output);
                break;
            case "7z":
                if (decompress) run ({ program, "x", "-so", "payload.bin", "payload.tar" }, dir, null, output);
                else run ({ program, "a", "-t7z", "payload.bin", "payload.tar" }, dir);
                break;
            case "zpaq":
                if (decompress) run ({ program, "extract", "payload.bin", "payload.tar" }, dir);
                else run ({ program, "add", "payload.bin", "payload.tar", "-method", "1", "-threads", "1" }, dir);
                break;
            default:
                var profiles = codec_profiles ();
                if (profiles.has_key (codec, "adapter"))
                    run ({ program, decompress ? "decompress" : "compress", input, output }, dir);
                else {
                    var command = profiles.get_string_list (codec, decompress ? "decompress" : "compress");
                    for (int i = 0; i < command.length; i++)
                        command[i] = command[i].replace ("{input}", input).replace ("{output}", output);
                    run (command, dir);
                }
                break;
        }
        if (!FileUtils.test (output, FileTest.IS_REGULAR))
            throw new IOError.FAILED ("Codec '%s' did not produce its output", codec);
    }

    private uint8[] random_bytes (size_t count) {
        var result = new uint8[count];
        Sodium.Random.buffer (result, count);
        return result;
    }

    private uint8[] derive_key (string password, uint8[] salt) throws Error {
        if (Sodium.init () < 0) throw new IOError.FAILED ("libsodium initialization failed");
        if (salt.length != Sodium.CRYPTO_PWHASH_SALTBYTES) throw new IOError.INVALID_DATA ("Invalid salt length");
        var key = new uint8[Sodium.Symmetric.KEY_BYTES];
        if (Sodium.crypto_pwhash (key, key.length, password, password.length, salt,
                                 ARGON_T, ARGON_M * 1024, Sodium.CRYPTO_PWHASH_ALG_ARGON2ID13) != 0)
            throw new IOError.FAILED ("Argon2id key derivation failed");
        return key;
    }

    private void write_bytes (OutputStream stream, uint8[] bytes) throws Error {
        size_t count;
        stream.write_all (bytes, out count);
    }

    private void read_exact (InputStream stream, uint8[] bytes) throws Error {
        size_t count;
        stream.read_all (bytes, out count);
        if (count != bytes.length) throw new IOError.INVALID_DATA ("Truncated archive");
    }

    private uint8[] header_bytes (Json.Object obj) throws Error {
        var node = new Json.Node (Json.NodeType.OBJECT);
        node.set_object (obj);
        var gen = new Json.Generator ();
        gen.set_root (node);
        var json = gen.to_data (null);
        if (json.length >= HEADER_RESERVE) throw new IOError.FAILED ("Archive header too large");
        var bytes = new uint8[HEADER_RESERVE];
        for (int i = 0; i < json.length; i++) bytes[i] = json[i];
        return bytes;
    }

    private string authenticate_header (Json.Object hdr, uint8[] key) throws Error {
        var bytes = header_bytes (hdr);
        var tag = new uint8[Sodium.AUTH_BYTES];
        if (Sodium.auth (tag, bytes, bytes.length, key) != 0) throw new IOError.FAILED ("Header authentication failed");
        return Base64.encode (tag);
    }

    /** Encrypt using the legacy API's default codec (zstd). */
    public void encrypt (File src_dir, File out_file, string password, string? exclude_path = null,
                         ProgressCallback? progress = null, EncryptionMode mode = EncryptionMode.WITH_INTEGRITY) throws Error {
        encrypt_with_codec (src_dir, out_file, password, "zstd", exclude_path, progress, mode);
    }

    /** Codec selection belongs to the Vala engine, shared by every frontend. */
    public void encrypt_with_codec (File src_dir, File out_file, string password, string codec,
                                   string? exclude_path = null, ProgressCallback? progress = null,
                                   EncryptionMode mode = EncryptionMode.WITH_INTEGRITY) throws Error {
        if (src_dir.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS) != FileType.DIRECTORY)
            throw new IOError.NOT_DIRECTORY ("Source must be a local directory");
        if (src_dir.get_path () == null || out_file.get_path () == null)
            throw new IOError.NOT_SUPPORTED ("Only local file paths are supported");
        validate_codec (codec, 0);
        var tar = tar_program ();
        if (out_file.equal (src_dir) || src_dir.has_prefix (out_file))
            throw new IOError.INVALID_ARGUMENT ("Output cannot be the source or its ancestor");
        if (out_file.has_prefix (src_dir)) {
            if (exclude_path == null || !(out_file.equal (File.new_for_path (exclude_path)) ||
                                         out_file.has_prefix (File.new_for_path (exclude_path))))
                throw new IOError.INVALID_ARGUMENT ("Output inside source requires an exclusion");
        }
        var temp = File.new_for_path (DirUtils.make_tmp ("dvx3-XXXXXX"));
        string dir = temp.get_path ();
        uint8[] key = {};
        Error? failure = null;
        FileIOStream? staged_stream = null;
        File? staged = null;
        try {
            string[] args = { tar, "-cf", "-" };
            if (exclude_path != null) {
                var exclude = File.new_for_path (exclude_path);
                var rel = src_dir.get_relative_path (exclude);
                if (rel != null && rel != "") args += "--exclude=./" + rel.replace ("\\", "/");
            }
            args += ".";
            run (args, src_dir.get_path (), null, Path.build_filename (dir, "payload.tar"));
            transform (codec, false, dir);
            var packed = File.new_for_path (Path.build_filename (dir, "payload.bin"));
            var total = packed.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
            var salt = random_bytes (Sodium.CRYPTO_PWHASH_SALTBYTES);
            key = derive_key (password, salt);
            // Same-directory staging makes final replacement atomic on the local filesystem.
            var parent = out_file.get_parent ();
            if (parent == null) throw new IOError.INVALID_ARGUMENT ("Output needs a parent directory");
            staged = parent.get_child (".dvx3-" + Uuid.string_random () + ".partial");
            staged_stream = staged.create_readwrite (FileCreateFlags.PRIVATE);
            var output = staged_stream.output_stream;
            write_bytes (output, { 0, 0, 2, 0 }); // 512-byte, big-endian JSON header
            write_bytes (output, new uint8[HEADER_RESERVE]);
            var input = packed.read ();
            var checksum = new Checksum (ChecksumType.SHA256);
            var buffer = new uint8[CHUNK_SIZE];
            uint64 chunks = 0, last = 0, processed = 0, written = 0;
            while (true) {
                size_t count;
                input.read_all (buffer, out count);
                if (count == 0) break;
                var plain = buffer[0:count];
                checksum.update (plain, count);
                var nonce = random_bytes (Sodium.Symmetric.NONCE_BYTES);
                var cipher = new uint8[count + Sodium.Symmetric.MAC_BYTES];
                if (Sodium.Symmetric.secretbox (cipher, plain, count, nonce, key) != 0)
                    throw new IOError.FAILED ("Encryption failed");
                write_bytes (output, nonce);
                write_bytes (output, cipher);
                chunks++; last = count; processed += count; written += nonce.length + cipher.length;
                if (progress != null) progress (processed, total, written);
            }
            input.close ();
            var hdr = new Json.Object ();
            hdr.set_string_member ("salt", Base64.encode (salt));
            hdr.set_int_member ("chunks", (int64)chunks);
            hdr.set_int_member ("last_chunk_size", (int64)last);
            hdr.set_string_member ("codec", codec);
            hdr.set_int_member ("version", 2);
            if (mode == EncryptionMode.WITH_INTEGRITY) hdr.set_string_member ("sha256", checksum.get_string ());
            hdr.set_boolean_member ("integrity_verified", mode == EncryptionMode.WITH_INTEGRITY);
            var argon = new Json.Object ();
            argon.set_int_member ("time_cost", ARGON_T);
            argon.set_int_member ("memory_kib", ARGON_M);
            argon.set_int_member ("parallelism", ARGON_P);
            argon.set_string_member ("type", "argon2id");
            hdr.set_object_member ("argon2", argon);
            hdr.set_string_member ("header_mac", authenticate_header (hdr, key));
            if (!(output is Seekable) || !((Seekable)output).can_seek ()) throw new IOError.NOT_SUPPORTED ("Output must be seekable");
            ((Seekable)output).seek (4, SeekType.SET);
            write_bytes (output, header_bytes (hdr));
            staged_stream.close ();
            staged.move (out_file, FileCopyFlags.OVERWRITE);
        } catch (Error e) { failure = e; }
        finally {
            if (key.length > 0) Sodium.memzero (key, key.length);
            try { if (staged_stream != null) staged_stream.close (); }
            catch (Error e) { if (failure == null) failure = e; else warning ("Cleanup: %s", e.message); }
            try { if (staged != null && staged.query_exists ()) staged.delete (); }
            catch (Error e) { if (failure == null) failure = e; else warning ("Cleanup: %s", e.message); }
            try { remove_tree (temp); }
            catch (Error e) { if (failure == null) failure = e; else warning ("Cleanup: %s", e.message); }
        }
        if (failure != null) throw failure;
    }

    public void decrypt (File enc_file, File dst_dir, string password, ProgressCallback? progress = null,
                         EncryptionMode mode = EncryptionMode.WITH_INTEGRITY) throws Error {
        var tar = tar_program ();
        var temp = File.new_for_path (DirUtils.make_tmp ("dvx3-XXXXXX"));
        string dir = temp.get_path ();
        uint8[] key = {};
        Error? failure = null;
        try {
            var input = enc_file.read ();
            var length = new uint8[4];
            read_exact (input, length);
            uint32 hlen = 0;
            foreach (uint8 b in length) hlen = (hlen << 8) | b;
            if (hlen == 0 || hlen > 65536) throw new IOError.INVALID_DATA ("Invalid archive header length");
            var raw_header = new uint8[hlen + 1];
            read_exact (input, raw_header[0:hlen]);
            var parser = new Json.Parser ();
            parser.load_from_data ((string)raw_header);
            if (parser.get_root ().get_node_type () != Json.NodeType.OBJECT) throw new IOError.INVALID_DATA ("Invalid JSON header");
            var hdr = parser.get_root ().get_object ();
            foreach (var member in new string[] { "salt", "chunks", "last_chunk_size" })
                if (!hdr.has_member (member)) throw new IOError.INVALID_DATA ("Missing archive field: %s", member);
            if (hdr.get_member ("salt").get_value_type () != typeof (string) ||
                hdr.get_member ("chunks").get_value_type () != typeof (int64) ||
                hdr.get_member ("last_chunk_size").get_value_type () != typeof (int64))
                throw new IOError.INVALID_DATA ("Invalid archive field types");
            int64 chunks = hdr.get_int_member ("chunks"), last = hdr.get_int_member ("last_chunk_size");
            int64 size = enc_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
            int64 overhead = (int64)(Sodium.Symmetric.NONCE_BYTES + Sodium.Symmetric.MAC_BYTES);
            if (chunks < 1 || last < 1 || last > CHUNK_SIZE || chunks > size / overhead)
                throw new IOError.INVALID_DATA ("Invalid chunk counts");
            int64 remainder = size - 4 - hlen - last - overhead;
            int64 block = (int64)CHUNK_SIZE + overhead;
            if (remainder < 0 || remainder % block != 0 || remainder / block != chunks - 1)
                throw new IOError.INVALID_DATA ("Archive size does not match chunk metadata");
            string codec = "zstd"; // Existing archives omitted codec metadata.
            if (hdr.has_member ("codec")) {
                if (hdr.get_member ("codec").get_value_type () != typeof (string)) throw new IOError.INVALID_DATA ("Invalid codec field");
                codec = hdr.get_string_member ("codec");
            }
            key = derive_key (password, Base64.decode (hdr.get_string_member ("salt")));
            if (hdr.has_member ("version")) {
                if (hdr.get_member ("version").get_value_type () != typeof (int64) || hdr.get_int_member ("version") != 2)
                    throw new IOError.NOT_SUPPORTED ("Unsupported archive version");
                if (!hdr.has_member ("header_mac") || hdr.get_member ("header_mac").get_value_type () != typeof (string))
                    throw new IOError.INVALID_DATA ("Missing header authentication tag");
            }
            if (hdr.has_member ("header_mac")) {
                if (hdr.get_member ("header_mac").get_value_type () != typeof (string))
                    throw new IOError.INVALID_DATA ("Invalid header authentication tag");
                var stored = hdr.get_string_member ("header_mac");
                hdr.remove_member ("header_mac");
                if (stored != authenticate_header (hdr, key)) throw new IOError.INVALID_DATA ("Archive header authentication failed");
            }
            validate_codec (codec, 0);
            var output = File.new_for_path (Path.build_filename (dir, "payload.bin")).create (FileCreateFlags.PRIVATE);
            var checksum = new Checksum (ChecksumType.SHA256);
            uint64 processed = 0;
            for (int64 i = 0; i < chunks; i++) {
                var nonce = new uint8[Sodium.Symmetric.NONCE_BYTES];
                var count = i == chunks - 1 ? last : (int64)CHUNK_SIZE;
                var cipher = new uint8[count + Sodium.Symmetric.MAC_BYTES];
                read_exact (input, nonce); read_exact (input, cipher);
                var plain = new uint8[count];
                if (Sodium.Symmetric.secretbox_open (plain, cipher, cipher.length, nonce, key) != 0)
                    throw new IOError.INVALID_DATA ("Authentication failed (wrong password or damaged archive)");
                checksum.update (plain, plain.length);
                write_bytes (output, plain);
                processed += cipher.length + nonce.length;
                if (progress != null) progress (processed, size - 4 - hlen, (uint64)output.tell ());
            }
            input.close (); output.close ();
            if (mode == EncryptionMode.WITH_INTEGRITY && hdr.has_member ("sha256")) {
                if (hdr.get_member ("sha256").get_value_type () != typeof (string) ||
                    checksum.get_string () != hdr.get_string_member ("sha256"))
                    throw new IOError.INVALID_DATA ("Archive integrity verification failed");
            }
            // Authenticate the entire compressed payload before invoking any extractor.
            transform (codec, true, dir);
            if (dst_dir.query_exists ()) {
                var entries = dst_dir.enumerate_children ("standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                if (entries.next_file () != null) throw new IOError.EXISTS ("Restore destination must be empty");
                entries.close ();
            } else dst_dir.make_directory_with_parents ();
            run ({ tar, "-xf", "-", "--no-same-owner" }, dst_dir.get_path (), Path.build_filename (dir, "payload.tar"));
        } catch (Error e) { failure = e; }
        finally {
            if (key.length > 0) Sodium.memzero (key, key.length);
            try { remove_tree (temp); }
            catch (Error e) { if (failure == null) failure = e; else warning ("Cleanup: %s", e.message); }
        }
        if (failure != null) throw failure;
    }
}
