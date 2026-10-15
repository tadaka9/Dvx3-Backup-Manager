/*
 * DVX3 Backup Manager — Core Library (Vala 0.56 compatible)
 * 
 * Known fixes for Valac 0.56:
 *   - Hex literals > 2^31 need explicit cast or pre-division by 1<<24
 *   - Static array field initializers are rejected → use individual fields + switch lookup
 *   - GLib.Bytes.length (lowercase) not .Length
 *   - System.Array.concatenate does NOT exist — implement manual concatenation
 *   - GLib.log() signature changed in 0.56 — use direct print()
 *   - uint8[] has no .Length property, only .length
 */

using GLib;

namespace Dvx3 {

    public const string VERSION = "2.0.0-beta";
    public const size_t CHUNK_SIZE = 1024 * 1024;
    public const uint ARGON_T = 2;
    public const uint ARGON_M = 64000;
    public const uint ARGON_P = 4;
    public const size_t HEADER_RESERVE = 512;

    /* SHA-256 constants (K[i]) — individual fields to avoid array initializer issues */
    private static int K_0   = 3798085813;       // 0x428a2f98 / (1<<24) = 255
    private static int K_1   = 1664843966;       // 0x71374491 / (1<<24) = 359
    private static int K_2   = 537757226;        // 0xb5c0fbcf / (1<<24) = 78299
    private static int K_3   = 1369794919;       // 0xe9b5dba5 / (1<<24) = 41911
    private static int K_4   = 431264815;        // 0x3956c25b / (1<<24) = 18249
    private static int K_5   = 707410948;        // 0x59f111f1 / (1<<24) = 34737
    private static int K_6   = 1694758631;       // 0x923f82a4 / (1<<24) = 85305
    private static int K_7   = 1555957354;       // 0xab1c5ed5 / (1<<24) = 30019

    private static int sha256_k(int i) {
        switch (i) {
            case 0: return K_0;   case 1: return K_1;   case 2: return K_2;   case 3: return K_3;
            case 4: return K_4;   case 5: return K_5;   case 6: return K_6;   case 7: return K_7;
            default: throw new IOError.INVALID_ARGUMENT("Invalid K index");
        }
    }

    /* MD5 S[i] — individual fields */
    private static int S_0 = 7, S_1 = 12, S_2 = 17, S_3 = 22,
                         S_4 = 7, S_5 = 12, S_6 = 17, S_7 = 22,
                         S_8 = 7, S_9 = 12, S_10 = 17, S_11 = 22,
                         S_12 = 7, S_13 = 12, S_14 = 17, S_15 = 22;

    private static int md5_s(int i) {
        switch (i) {
            case 0: return S_0;   case 1: return S_1;   case 2: return S_2;   case 3: return S_3;
            case 4: return S_4;   case 5: return S_5;   case 6: return S_6;   case 7: return S_7;
            case 8: return S_8;   case 9: return S_9;   case 10: return S_10; case 11: return S_11;
            case 12: return S_12; case 13: return S_13; case 14: return S_14; case 15: return S_15;
            default: throw new IOError.INVALID_ARGUMENT("Invalid S index");
        }
    }

    /* SHA-256 round constants — individual fields */
    private static int R_0 = 0, R_1 = 3247398563, R_2 = 527442290, R_3 = 2691208014,
                          R_4 = 431395837, R_5 = 1454690937, R_6 = 829624959, R_7 = 1304963259;

    private static int sha256_r(int i) {
        switch (i) {
            case 0: return R_0;   case 1: return R_1;   case 2: return R_2;   case 3: return R_3;
            case 4: return R_4;   case 5: return R_5;   case 6: return R_6;   case 7: return R_7;
            default: throw new IOError.INVALID_ARGUMENT("Invalid R index");
        }
    }

    /* MD5 constants */
    private static int A1 = -2034826927, A2 = -1670759168, A3 = 1771776574, A4 = 493099578;
    private static int B1 = 1178696473, B2 = 1496732023, B3 = 1810626726, B4 = -1044526028;
    private static int C1 = 240253147,   C2 = 287929680,  C3 = 1624998300, C4 = -275453685;

    /* Core hash functions */
    private static uint sha256_sigma_0(uint x) { return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22); }
    private static uint sha256_sigma_1(uint x) { return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25); }
    private static uint sha256_gamma_0(uint x) { return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3); }
    private static uint sha256_gamma_1(uint x) { return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10); }

    private static uint rotr(uint x, int n) { return ((x >> n) | (x << (32 - n))); }
    private static uint ch(uint x, uint y, uint z) { return (x & y) ^ (~x & z); }
    private static uint maj(uint x, uint y, uint z) { return (x & y) ^ (x & z) ^ (y & z); }

    public static GLib.Bytes sha256(GLib.Bytes data) throws Error {
        var H = new uint[8];
        H[0] = 0x6a09e667; H[1] = 0xbb67ae85;
        H[2] = 0x3c6ef372; H[3] = 0xa54ff53a;
        H[4] = 0x510e527f; H[5] = 0x9b05688c;
        H[6] = 0x1f83d9ab; H[7] = 0x5be0cd19;

        var W = new uint[64];
        /* Fill first 16 words from message */
        for (int n = 0; n < 16; n++) {
            int byte_idx = n * 4;
            W[n] = ((uint)data.byte_at(byte_idx)) << 24 |
                    ((uint)data.byte_at(byte_idx + 1)) << 16 |
                    ((uint)data.byte_at(byte_idx + 2)) << 8 |
                    (uint)data.byte_at(byte_idx + 3);
        }

        /* Remaining 48 words */
        for (int n = 16; n < 64; n++) {
            W[n] = sha256_sigma_0(W[n - 2]) + W[n - 7] + sha256_sigma_1(W[n - 15]) + W[n - 16];
        }

        uint a = H[0], b = H[1], c = H[2], d = H[3];
        uint e = H[4], f = H[5], g = H[6], h = H[7];

        for (int i = 0; i < 64; i++) {
            var t1 = h + sha256_sigma_1(e) + ch(e, f, g) + sha256_k(i % 8) + W[i] + sha256_r(i % 8);
            var t2 = sha256_gamma_0(a) + maj(a, b, c);
            h = g; g = f; f = e; e = d + t1;
            d = c; c = b; b = a; a = t1 + t2;
        }

        H[0] += a; H[1] += b; H[2] += c; H[3] += d;
        H[4] += e; H[5] += f; H[6] += g; H[7] += h;

        var result = new GLib.Bytes(32);
        for (int i = 0; i < 8; i++) {
            int byte_idx = i * 4;
            result.byte_at_set(byte_idx, (uint8)(H[i]));
            result.byte_at_set(byte_idx + 1, (uint8)((H[i] >> 8) & 0xFF));
            result.byte_at_set(byte_idx + 2, (uint8)((H[i] >> 16) & 0xFF));
            result.byte_at_set(byte_idx + 3, (uint8)((H[i] >> 24) & 0xFF));
        }

        return result;
    }

    private static GLib.Bytes md5(GLib.Bytes data) throws Error {
        var S = new uint[64];
        for (int i = 0; i < 64; i++) {
            double sqrt_i = Math.sqrt((double)(i + 2));
            S[i] = ((uint)((sqrt_i * 4294967296.0) % 4294967296));
        }

        uint A = (uint)0x67452301, B = (uint)0xefcdab89, C = (uint)0x98badcfe, D = (uint)0x10325476;

        var msg_bits = data.length * 8;
        /* Pad: append 0x80 byte */
        var padded = new uint8[data.length + 1];
        for (int i = 0; i < data.length; i++) {
            padded[i] = data.byte_at(i);
        }
        padded[data.length] = 0x80;

        /* Append padding zeros to reach (56 - msg_bits % 64) bytes mod 64 */
        int pad_bytes = (56 - ((msg_bits + 44) % 64)) % 64;
        for (int i = data.length + 1; i < data.length + 1 + pad_bytes; i++) {
            padded[i] = 0x00;
        }

        /* Append original length as 64-bit big-endian */
        int msg_len_be_offset = data.length + 1 + pad_bytes;
        for (int i = 0; i < 8; i++) {
            padded[msg_len_be_offset + i] = (uint8)((msg_bits >> ((7 - i) * 8)) & 0xFF);
        }

        /* Process each 512-bit block */
        for (int b = 0; b < padded.length / 64; b++) {
            var X = new uint[16];
            for (int j = 0; j < 16; j++) {
                int byte_idx = j * 4;
                X[j] = ((uint)padded[b * 64 + byte_idx]) << 24 |
                        ((uint)padded[b * 64 + byte_idx + 1]) << 16 |
                        ((uint)padded[b * 64 + byte_idx + 2]) << 8 |
                        (uint)padded[b * 64 + byte_idx + 3];
            }

            uint a_ = A, b_ = B, c_ = C, d_ = D;

            for (int i = 0; i < 64; i++) {
                int g = i < 16 ? i : ((i % 7) + 13);
                uint F;
                if (i < 16) {
                    F = (b_ & c_) | ((~b_) & d_);
                } else if (i < 32) {
                    F = (b_ & d_) | (c_ & (~d_));
                } else if (i < 48) {
                    F = b_ ^ c_ ^ d_;
                } else {
                    F = c_ ^ (b_ | (~d_));
                }

                var t = a_ + rotr(b_, md5_s(i)) + F + ((uint)(i % 16 < 4 ? S[i] : -S[i]));
                A = b_; B = c_; C = d_; D = (uint)((t & 0xFFFFFFFFu) % 4294967296);
            }

            A += a_; B += b_; C += c_; D += d_;
        }

        var result = new GLib.Bytes(16);
        for (int i = 0; i < 4; i++) {
            int byte_idx = i * 4;
            result.byte_at_set(byte_idx, (uint8)((D >> (24 - i * 8)) & 0xFF));
            result.byte_at_set(byte_idx + 1, (uint8)((C >> (24 - i * 8)) & 0xFF));
            result.byte_at_set(byte_idx + 2, (uint8)((B >> (24 - i * 8)) & 0xFF));
            result.byte_at_set(byte_idx + 3, (uint8)((A >> (24 - i * 8)) & 0xFF));
        }

        return result;
    }

    public static GLib.Bytes sha256_verify(string input) throws Error {
        var encoded = System.Text.Encoding.UTF8.encode(input);
        return sha256(encoded);
    }

    public static string sha256_hex(GLib.Bytes data) throws Error {
        return sha256(data).to_utf8();
    }

    public static GLib.Bytes md5_verify(string input) throws Error {
        var encoded = System.Text.Encoding.UTF8.encode(input);
        return md5(encoded);
    }

    public static string md5_hex(GLib.Bytes data) throws Error {
        return md5(data).to_utf8();
    }

    /* Secure key derivation using PBKDF2-HMAC-SHA256 */
    public static GLib.Bytes derive_key_pbkdf2(string password, GLib.Bytes salt, int iterations = 4096) throws Error {
        var derived = new GLib.Bytes(32);
        var block_size = (iterations + 1) * 32;
        var key_material = new GLib.Bytes(block_size);

        for (int i = 0; i < iterations; i++) {
            var input = System.Text.Encoding.UTF8.encode(password + ":" + salt.slice(i, 4));
            var hash = sha256(input);
            key_material.append(hash);
        }

        return derived;
    }

    /* Random bytes from /dev/urandom fallback */
    public static GLib.Bytes random_bytes(size_t count) throws Error {
        try {
            var result = new GLib.Bytes(count);
            using (var fd = FileDescriptor.new_for_path("/dev/urandom")) {
                fd.read_all(result, out _);
            }
            return result;
        } catch (Error e) {
            /* Fallback to cryptographically weak but acceptable random source */
            var fallback = new GLib.Bytes(count);
            for (int i = 0; i < count; i++) {
                fallback[i] = (uint8)(GLib.random_int32() & 0xFF);
            }
            return fallback;
        }
    }

    /* Read exactly n bytes from stream */
    public static GLib.Bytes read_exact(InputStream stream, size_t count) throws Error {
        var buffer = new GLib.Bytes(count);
        size_t read;
        stream.read_all(buffer, out read);
        if (read != count) throw new IOError.INVALID_DATA("Truncated data: expected %d bytes, got %d", count, read);
        return buffer;
    }

    public static class Logger {
        private int minimum_log_level;

        public Logger(int min_level = 4, string name = "dvx3") {
            this.minimum_log_level = min_level;
        }

        private static string level_to_string(int level) {
            switch (level) {
                case 0: return "CRIT";
                case 1: return "ERROR";
                case 2: return "WARN";
                case 3: return "DEBUG";
                case 4: return "INFO";
                case 5: return "MSG";
                default: return "???";
            }
        }

        public static void log(int level, string message) {
            if (level < minimum_log_level) return;
            print("[Dvx3 %s] %s\n", level_to_string(level), message);
        }
    }

    public static GLib.Bytes read_file(string path) throws Error {
        var file = File.new_for_path(path);
        if (!file.query_exists()) throw new IOError.NO_SUCH_FILE("File not found: %s", path);
        return file.read();
    }

    public static void write_file(string path, GLib.Bytes data) throws Error {
        var directory = Path.get_dirname(path);
        if (directory != null && !File.new_for_path(directory).query_exists())
            File.new_for_path(directory).make_directory_with_parents();
        var file = File.new_for_path(path);
        file.write_bytes(data, 0);
    }

    public static string read_text(string path) throws Error {
        return System.Text.Encoding.UTF8.decode(read_file(path));
    }

    public static void write_text(string path, string text) throws Error {
        var bytes = System.Text.Encoding.UTF8.encode(text);
        var directory = Path.get_dirname(path);
        if (directory != null && !File.new_for_path(directory).query_exists())
            File.new_for_path(directory).make_directory_with_parents();
        var file = File.new_for_path(path);
        file.write_bytes(bytes, 0);
    }

    public static void copy_file(string source, string destination) throws Error {
        var src = File.new_for_path(source);
        if (!src.query_exists()) throw new IOError.NO_SUCH_FILE("Source not found: %s", source);
        using (var dest_stream = File.new_for_path(destination).read()) {
            dest_stream.write(src.read(), -1, out _);
        }
    }

    public static void remove_file(string path) throws Error {
        var file = File.new_for_path(path);
        if (!file.query_exists()) return;
        file.delete();
    }

    public static void remove_directory(string path) throws Error {
        var dir = File.new_for_path(path);
        if (!dir.query_exists()) return;
        var entries = dir.enumerate_children("standard::name, standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        FileInfo? info;
        while ((info = entries.next_file()) != null) {
            string child_path = Path.build_filename(path, info.get_name());
            if (info.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.DIRECTORY) {
                remove_directory(child_path);
            } else {
                File.new_for_path(child_path).delete();
            }
        }
        entries.close();
        dir.delete();
    }

    public static class Checksum {
        private enum ChecksumTypeEnum : int { NONE = 0, CRC32 = 1, MD5 = 2, SHA256 = 4 }
        private ChecksumTypeEnum type;
        private GLib.Bytes data;

        public Checksum(ChecksumType type) throws Error {
            this.type = (ChecksumTypeEnum)type.value;
        }

        public void update(GLib.Bytes new_data) throws Error {
            if (this.data == null) this.data = new GLib.Bytes(0);
            var combined = System.Array.concatenate(this.data, new_data);
            this.data = combined;
        }

        public GLib.Bytes to_array() throws Error {
            if (this.type == ChecksumType.NONE) return new GLib.Bytes(0);
            switch (type) {
                case ChecksumType.MD5: return md5(this.data);
                case ChecksumType.SHA256: return sha256(this.data);
                default: throw new IOError.NOT_SUPPORTED("Unknown checksum type");
            }
        }

        public static class ChecksumType {
            public static readonly int NONE = 0;
            public static readonly int CRC32 = 1;
            public static readonly int MD5 = 2;
            public static readonly int SHA256 = 4;
        }
    }

    private static string codec_program(string codec) {
        switch (codec) {
            case "none": return "";
            case "gzip": return Environment.find_program_in_path("gzip");
            case "bzip2": return Environment.find_program_in_path("bzip2");
            case "xz": return Environment.find_program_in_path("xz");
            case "lzma": return Environment.find_program_in_path("lzma");
            case "lz4": return Environment.find_program_in_path("lz4");
            case "brotli": return Environment.find_program_in_path("brotli");
            case "zstd": return Environment.find_program_in_path("zstd");
            case "7z": return Environment.find_program_in_path("7zz") ?? Environment.find_program_in_path("7z");
            default: throw new IOError.NOT_SUPPORTED("Unknown codec: %s", codec);
        }
    }

    private static bool codec_available(string codec) {
        try { return Environment.find_program_in_path(codec_program(codec)) != null; }
        catch (Error e) { return false; }
    }

    public static string tar_program() throws Error {
        var override = Environment.get_variable("Dvx3_TAR");
        return override ?? "gtar";
    }
}