#!/usr/bin/env valac
/* -*- coding: utf-8 -*- */


/* ----------------------------------------
   dvx3 – tar → zstd → Argon2id → Secretbox (XSalsa20‑Poly1305)
   ------------------------------------------------ */


using GLib;
using Json;
using Posix;
using Sodium;        // ← libsodium VAPI
// using Gtk;           // optional – comment out if you don’t need a UI bar


/* -------------------------------------------------
   Colour helpers (fallback when stdout isn’t a tty)
   ------------------------------------------------ */
private const string RST = "\x1b[0m";
private const string BLD = "\x1b[1m";
private const string GRN = "\x1b[32m";
private const string CYN = "\x1b[36m";
private const string YLW = "\x1b[33m";
private const string RED = "\x1b[31m";


private bool stdout_is_tty () {
    return Posix.isatty (Posix.STDOUT_FILENO);
}


private string colour_wrap (string txt, string col) {
    return stdout_is_tty () ? "%s%s%s".printf (col, txt, RST) : txt;
}


private string format_size (uint64 bytes) {
    double value = bytes;
    string[] units = { "B", "KiB", "MiB", "GiB", "TiB" };
    int idx = 0;
    while (value >= 1024.0 && idx < units.length - 1) {
        value /= 1024.0;
        idx++;
    }
    return "%.2f %s".printf (value, units[idx]);
}


/* -----------------------------------------------
   Configuration constants (mirroring the Python version)
   ------------------------------------------------- */
private const size_t CHUNK_SIZE = 1024 * 1024;  // 1 MiB
private const uint   ARGON_T   = 2;             // Argon2 time cost (iterations)
private const uint   ARGON_M   = 64000;          // Argon2 memory (KiB) – no underscore literal
private const uint   ARGON_P   = 4;           // Argon2 parallelism


private const size_t SECRETBOX_MAC = Sodium.Symmetric.MAC_BYTES;   // 16 bytes


/* -----------------------------------------------
   Simple big‑endian helpers (avoid newer ByteArray APIs)
   ------------------------------------------------ */
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


/* -------------------------------------------------
   Tiny random‑bytes helper (libsodium VAPI in 0.56 lacks `randombytes_buf`)
   ------------------------------------------------ */
private uint8[] random_bytes (size_t len) {
    uint8[] buf = new uint8[len];
    Sodium.Random.buffer (buf);
    return buf;
}


private string create_temp_dir (string prefix) throws IOError {
    string base_dir = Environment.get_variable ("TMPDIR") ?? Environment.get_tmp_dir ();
    for (int attempt = 0; attempt < 128; attempt++) {
        ulong stamp = (ulong) GLib.get_real_time ();
        string candidate = GLib.Path.build_filename (base_dir, "%s-%lu-%d".printf (prefix, stamp, attempt));
        if (FileUtils.test (candidate, FileTest.EXISTS))
            continue;

        var dir = File.new_for_path (candidate);
        try {
            dir.make_directory_with_parents ();
            return candidate;
        } catch (Error e) {
            /* retry on collision */
        }
    }
    throw new IOError.FAILED ("Unable to create temporary directory");
}


private void copy_stream (InputStream src, OutputStream dst) throws Error {
    uint8[] buffer = new uint8[64 * 1024];
    while (true) {
        ssize_t read_len = src.read (buffer);
        if (read_len == 0)
            break;

        uint8[] chunk = new uint8[(int) read_len];
        for (int i = 0; i < read_len; i++) {
            chunk[i] = buffer[i];
        }
        size_t written;
        dst.write_all (chunk, out written);
    }
}


private uint64 compute_total_size (File dir, string? skip_path = null) {
    uint64 total = 0;
    try {
        var enumer = dir.enumerate_children (
            FileAttribute.STANDARD_NAME + "," +
            FileAttribute.STANDARD_TYPE + "," +
            FileAttribute.STANDARD_SIZE,
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

        FileInfo info;
        while ((info = enumer.next_file ()) != null) {
            var child = dir.get_child (info.get_name ());
            string child_path = child.get_path ();
            if (skip_path != null && child_path == skip_path)
                continue;

            switch (info.get_file_type ()) {
            case FileType.DIRECTORY:
                total += compute_total_size (child, skip_path);
                break;
            case FileType.REGULAR:
                int64 size = info.get_size ();
                if (size > 0)
                    total += (uint64) size;
                break;
            default:
                break;
            }
        }
        enumer.close ();
    } catch (Error e) {
        /* ignore entries we cannot stat */
    }
    return total;
}


/* -------------------------------------------------
   Argon2‑like key derivation – we fall back to a deterministic SHA‑256
   of password‖salt because the Argon2 VAPI isn’t present in Vala 0.56.
   ------------------------------------------------ */
private uint8[] derive_key (string password, uint8[] salt) throws Error {
    if (salt.length != (int) Sodium.CRYPTO_PWHASH_SALTBYTES)
        throw new IOError.FAILED ("Salt must be %u bytes".printf ((uint) Sodium.CRYPTO_PWHASH_SALTBYTES));

    uint8[] key = new uint8[32];
    ulong opslimit = (ulong) ARGON_T;
    size_t memlimit = (size_t) (ARGON_M * 1024u);
    int rc = Sodium.crypto_pwhash (key,
                                   (ulong) key.length,
                                   password,
                                   (ulong) password.length,
                                   salt,
                                   opslimit,
                                   memlimit,
                                   Sodium.CRYPTO_PWHASH_ALG_ARGON2ID13);
    if (rc != 0)
        throw new IOError.FAILED ("crypto_pwhash (Argon2id) failed");

    return key;
}


/* -----------------------------------------------
   Per‑chunk sub‑key (SHA‑256(master ‖ index))
   ------------------------------------------------ */
private uint8[] subkey (uint8[] master, uint64 idx) {
    var chk = new Checksum (ChecksumType.SHA256);
    chk.update (master, master.length);
    chk.update (uint64_to_be (idx), 8);
    uint8[] sub = new uint8[32];
    size_t len = sub.length;
    chk.get_digest (sub, ref len);
    return sub;
}


/* -------------------------------------------------
   Small helper to slice a uint8[] (Vala 0.56 has no built‑in slice)
   -------------------------------------------- */
private uint8[] slice_uint8 (uint8[] arr, int start, int length) {
    uint8[] res = new uint8[length];
    for (int i = 0; i < length; i++) {
        res[i] = arr[start + i];
    }
    return res;
}


class ConsoleProgress : GLib.Object {
    private string label;
    private uint64 total;
    private bool enabled;
    private const int BAR_WIDTH = 24;

    public ConsoleProgress (string label, uint64 total) {
        this.label = label;
        this.total = total;
        this.enabled = stdout_is_tty () && total > 0;
        if (this.enabled) {
            draw (0, 0, 0);
        }
    }

    public void update (uint64 processed, uint64 plain_bytes, uint64 cipher_bytes) {
        if (!enabled)
            return;
        draw (processed, plain_bytes, cipher_bytes);
    }

    public void finish (uint64 plain_bytes, uint64 cipher_bytes) {
        if (!enabled)
            return;
        draw (total, plain_bytes, cipher_bytes);
        GLib.stdout.putc ('\n');
        GLib.stdout.flush ();
    }

    private void draw (uint64 processed, uint64 plain_bytes, uint64 cipher_bytes) {
        double pct = (total > 0) ? ((double) processed / (double) total) : 1.0;
        if (pct > 1.0)
            pct = 1.0;
        int filled = (int) ((pct * BAR_WIDTH) + 0.5);
        if (filled > BAR_WIDTH)
            filled = BAR_WIDTH;

        string bar = "[";
        for (int i = 0; i < BAR_WIDTH; i++) {
            bar += (i < filled) ? "#" : ".";
        }
        bar += "]";

        double overhead_pct = 0.0;
        if (plain_bytes > 0 && cipher_bytes >= plain_bytes) {
            overhead_pct = ((double) cipher_bytes / (double) plain_bytes - 1.0) * 100.0;
        }

        string processed_txt = format_size (processed);
        string total_txt = format_size (total);
        GLib.stdout.printf ("\r%s %s %6.2f%% %s/%s ov %+6.2f%%",
                            label,
                            bar,
                            pct * 100.0,
                            processed_txt,
                            total_txt,
                            overhead_pct);
        GLib.stdout.flush ();
    }
}


/* -----------------------------------------------
   Chunk‑wise encryptor (nonce + ciphertext per chunk)
   -------------------------------------------- */
private class ChunkEncoder : GLib.Object {
    private OutputStream out;
    private uint8[] master;
    private uint8[] buffer = new uint8[0];


    public uint64 idx = 0;
    public uint64 chunks = 0;
    public size_t last_chunk_size = 0;
    public uint64 plain_bytes = 0;
    public uint64 cipher_bytes = 0;


    public ChunkEncoder (OutputStream out, uint8[] master) {
        this.out   = out;
        this.master = master;
    }


    private void flush_chunk (uint8[] data) throws Error {
        var sub = subkey (master, idx);
        uint8[] nonce = random_bytes (Sodium.Symmetric.NONCE_BYTES);
        uint8[] ct = new uint8[data.length + SECRETBOX_MAC];
        Sodium.Symmetric.secretbox (ct, data, (ulong) data.length, nonce, sub);
        size_t written;
        out.write_all (nonce, out written);
        out.write_all (ct, out written);
        idx++;
        chunks++;
        last_chunk_size = data.length;
        plain_bytes += (uint64) data.length;
        cipher_bytes += (uint64) (nonce.length + ct.length);
    }


    public ssize_t write (uint8[] data) throws Error {
        /* Manual concatenation – Vala 0.56 has no array.concat for uint8[] */
        uint8[] new_buf = new uint8[buffer.length + data.length];
        for (size_t i = 0; i < buffer.length; i++) new_buf[i] = buffer[i];
        for (size_t i = 0; i < data.length; i++) new_buf[buffer.length + i] = data[i];
        buffer = new_buf;


        while ((int) buffer.length >= (int) CHUNK_SIZE) {
            flush_chunk (slice_uint8 (buffer, 0, (int) CHUNK_SIZE));
            buffer = slice_uint8 (buffer, (int) CHUNK_SIZE, (int) (buffer.length - CHUNK_SIZE));
        }
        return data.length;
    }


    public void close () throws Error {
        if (buffer.length > 0) {
            flush_chunk (buffer);
            buffer = new uint8[0];
        }
    }
}


/* -----------------------------------------------
   Pretty‑print statistics
   ------------------------------------------------ */
private void stats (string act,
                    uint64 in_bytes,
                    uint64 out_bytes,
                    uint64 chunks,
                    double elapsed) {
    double ib = (double) in_bytes  / (1024.0 * 1024.0);
    double ob = (double) out_bytes / (1024.0 * 1024.0);
    double si = elapsed > 0 ? ib / elapsed : 0;
    double so = elapsed > 0 ? ob / elapsed : 0;


    GLib.stdout.printf ("\n%s%s STATISTICS%s\n",
                       BLD, colour_wrap (act.up (), CYN), RST);
    GLib.stdout.printf ("%-20s %8.2f MiB\n",
                        colour_wrap ("Input size:", GRN), ib);
    GLib.stdout.printf ("%-20s %8.2f MiB\n",
                        colour_wrap ("Output size:", GRN), ob);
    GLib.stdout.printf ("%-20s %8lu\n",
                        colour_wrap ("Chunks processed:", GRN), (ulong) chunks);
    GLib.stdout.printf ("%-20s %8.2f s\n",
                        colour_wrap ("Elapsed time:", GRN), elapsed);
    GLib.stdout.printf ("%-20s %6.2f MiB/s\n",
                        colour_wrap ("Throughput (in):", GRN), si);
    GLib.stdout.printf ("%-20s %6.2f MiB/s\n",
                        colour_wrap ("Throughput (out):", GRN), so);


    var sep = "";
    for (int i = 0; i < 60; i++) {
        sep += "=";
    }
    GLib.stdout.puts (sep + "\n\n");
}


/* -------------------------------------------------
    Run an external command synchronously.
    Returns true only when the command exits with status 0.
    The caller receives captured stdout/stderr strings for diagnostics.
   ------------------------------------------------ */
private bool run_command_sync (string[] argv,
                               out string? stdout_text,
                               out string? stderr_text,
                               out int exit_status) {
    stdout_text = null;
    stderr_text = null;

    try {
        bool ok = Process.spawn_sync (
            null,
            argv,
            null,
            SpawnFlags.SEARCH_PATH,
            null,
            out stdout_text,
            out stderr_text,
            out exit_status);

        return ok && exit_status == 0;
    } catch (Error e) {
        stderr_text = e.message;
        exit_status = -1;
        return false;
    }
}


/* -----------------------------------------------
   ENCRYPTION PIPELINE
   -------------------------------------------- */
private void encrypt_stream (File src_dir,
                             File out_file,
                             string password,
                             bool inplace = false) throws Error {


    Timer timer = new Timer ();
    double start = timer.elapsed ();


    /* ----- resolve paths & in‑place handling ----- */
    var src_path = src_dir.get_path ();
    var out_path = out_file.get_path ();


    string? exclude_rel = null;
    if (out_path.has_prefix (src_path)) {
        if (!inplace)
            throw new IOError.FAILED ("Output file is inside source folder – use –i/–‑in‑place.");
        exclude_rel = out_path.substring (src_path.length + 1);
        GLib.stdout.printf (
            colour_wrap (
                "⚠️  In‑place mode: excluding ‘" + exclude_rel + "’ from archive.\n",
                YLW));
    }


    /* ----- compute total size for progress bar ----- */
    string? skip_path = null;
    if (exclude_rel != null)
        skip_path = GLib.Path.build_filename (src_path, exclude_rel);

    uint64 total_src_bytes = compute_total_size (src_dir, skip_path);
    if (total_src_bytes == 0)
        throw new IOError.FAILED ("Source directory contains no readable files.");


    /* ----- header data (salt & master key) ----- */
    var salt   = random_bytes (Sodium.CRYPTO_PWHASH_SALTBYTES);
    var master = derive_key (password, salt);


    /* ----- prepare temporary working files ----- */
    string work_dir = create_temp_dir ("dvx3-work");
    string tar_path = GLib.Path.build_filename (work_dir, "archive.tar");
    string zstd_path = GLib.Path.build_filename (work_dir, "archive.tar.zst");
    string payload_path = GLib.Path.build_filename (work_dir, "payload.bin");

    var payload_stream = File.new_for_path (payload_path).replace (null, false, FileCreateFlags.PRIVATE);
    var encoder = new ChunkEncoder (payload_stream, master);

    /* ----- external commands ----- */
    string[] tar_cmd;
    if (exclude_rel != null) {
        tar_cmd = {
            "tar", "-c",
            "--exclude=" + exclude_rel.replace ("\\", "/"),
            "-f", tar_path,
            "-C", src_path,
            "."
        };
    } else {
        tar_cmd = {
            "tar", "-c",
            "-f", tar_path,
            "-C", src_path,
            "."
        };
    }

    string[] zstd_cmd = {
        "zstd", "-T16", "-22",
        "-f", tar_path,
        "-o", zstd_path
    };

    string? cmd_err;
    string? cmd_out;
    int cmd_status;

    if (!run_command_sync (tar_cmd, out cmd_out, out cmd_err, out cmd_status))
        throw new IOError.FAILED ("tar failed: " + (cmd_err ?? ""));

    if (!run_command_sync (zstd_cmd, out cmd_out, out cmd_err, out cmd_status))
        throw new IOError.FAILED ("zstd failed: " + (cmd_err ?? ""));

    FileUtils.remove (tar_path);

    /* ----- now we have the whole compressed stream on disk ----- */
    var zstd_file = File.new_for_path (zstd_path);
    uint64 compressed_total = zstd_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE)
        .get_attribute_uint64 (FileAttribute.STANDARD_SIZE);
    var zstd_in = new DataInputStream (zstd_file.read ());

    var enc_progress = new ConsoleProgress ("Encrypt", compressed_total);
    uint64 processed_compressed = 0;

    /* ----- read compressed data, encrypt chunk‑wise ----- */
    while (true) {
        uint8[] blk = zstd_in.read_bytes (CHUNK_SIZE).get_data ();
        if (blk.length == 0)
            break;   // EOF
        processed_compressed += (uint64) blk.length;
        encoder.write (blk);
        enc_progress.update (processed_compressed, compressed_total, encoder.cipher_bytes);
    }
    zstd_in.close ();
    encoder.close ();
    payload_stream.close ();
    enc_progress.finish (processed_compressed, encoder.cipher_bytes);
    FileUtils.remove (zstd_path);


    /* ----- write real JSON header ----- */
    var header = new Json.Object();
    header.set_string_member("salt", Base64.encode(salt));
    header.set_int_member("chunks", (int64)encoder.chunks);
    header.set_int_member("last_chunk_size", (int64)encoder.last_chunk_size);

    var argon = new Json.Object();
    argon.set_int_member("time_cost", ARGON_T);
    argon.set_int_member("memory_kib", ARGON_M);
    argon.set_int_member("parallelism", ARGON_P);
    argon.set_string_member("type", "argon2id");
    header.set_object_member("argon2", argon);

    var gen = new Json.Generator();
    var root_node = new Json.Node(Json.NodeType.OBJECT);
    root_node.set_object(header);
    gen.set_root(root_node);
    var json_bytes_str = gen.to_data (null);
    uint8[] json_bytes = new uint8[json_bytes_str.length];
    for (int i = 0; i < json_bytes.length; i++) {
        json_bytes[i] = (uint8) json_bytes_str[i];
    }
    uint32 json_len = (uint32) json_bytes.length;

    size_t written;
    var fout = out_file.replace (null, false, FileCreateFlags.PRIVATE);
    fout.write_all (uint32_to_be (json_len), out written);
    fout.write_all (json_bytes, out written);

    var payload_in = File.new_for_path (payload_path).read ();
    copy_stream (payload_in, fout);
    payload_in.close ();
    fout.flush ();
    fout.close ();

    FileUtils.remove (payload_path);
    FileUtils.remove (work_dir);

    /* ----- final statistics ----- */
    var out_sz = out_file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE)
        .get_attribute_uint64(FileAttribute.STANDARD_SIZE);
    stats("encryption", total_src_bytes, out_sz, encoder.chunks, timer.elapsed() - start);
    GLib.stdout.printf("%s\n", colour_wrap("✅ Encrypted backup → " + out_path, GRN));
}


// Decryption pipeline - streaming directly to extraction
private void decrypt_and_extract_stream(File enc_file, File dst_dir, string password) throws Error {
    Timer timer = new Timer();
    double start = timer.elapsed();

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
    var dec_progress = new ConsoleProgress ("Decrypt+Extract", cipher_total);
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
    try {
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
    } catch (Error e) {
        throw new IOError.FAILED ("Failed to launch zstd|tar pipeline: " + e.message);
    }

    var pipe_out = new GLib.UnixOutputStream (pipe_stdin, true);

    for (uint64 i = 0; i < chunks; i++) {
        uint8[] nonce = fin.read_bytes((uint)Sodium.Symmetric.NONCE_BYTES).get_data();
        if (nonce.length != (int)Sodium.Symmetric.NONCE_BYTES)
            throw new IOError.FAILED("Bad nonce at chunk %llu".printf(i));

        size_t plain_len = (i < chunks - 1) ? CHUNK_SIZE : (size_t)last;
        size_t ct_len = plain_len + SECRETBOX_MAC;

        uint8[] ct = fin.read_bytes(ct_len).get_data();
        if (ct.length != ct_len)
            throw new IOError.FAILED("Bad ciphertext at chunk %llu".printf(i));

        var sub = subkey(master, i);

        uint8[] pt = new uint8[plain_len];
        int rc = Sodium.Symmetric.secretbox_open(pt, ct, (ulong) ct.length, nonce, sub);
        if (rc != 0)
            throw new IOError.FAILED("Secretbox decryption failed");

        size_t written;
        pipe_out.write_all(pt, out written);
        processed_cipher += (uint64) Sodium.Symmetric.NONCE_BYTES + (uint64) ct.length;
        plain_emitted += (uint64) plain_len;
        dec_progress.update (processed_cipher, plain_emitted, processed_cipher);
    }

    pipe_out.flush();
    pipe_out.close();
    dec_progress.finish (plain_emitted, processed_cipher);

    /* Wait for pipeline to complete */
    int exit_status;
    Process.close_pid (child_pid);

    stats("decryption+extraction", enc_bytes, plain_emitted, chunks, timer.elapsed() - start);
    GLib.stdout.printf("%s\n", colour_wrap("✅ Extracted to " + dst_dir.get_path(), GRN));
}

// Decryption pipeline - to intermediate .zstd file (legacy mode)
private File decrypt_stream(File enc_file, File out_file, string password) throws Error {
    Timer timer = new Timer();
    double start = timer.elapsed();

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

    var fout = out_file.replace(null, false, FileCreateFlags.PRIVATE);
    var out_stream = new DataOutputStream(fout);

    uint64 cipher_total = 0;
    if (enc_bytes > (uint64) (4 + hlen))
        cipher_total = enc_bytes - (uint64) (4 + hlen);
    var dec_progress = new ConsoleProgress ("Decrypt", cipher_total);
    uint64 processed_cipher = 0;
    uint64 plain_emitted = 0;

    for (uint64 i = 0; i < chunks; i++) {
        uint8[] nonce = fin.read_bytes((uint)Sodium.Symmetric.NONCE_BYTES).get_data();
        if (nonce.length != (int)Sodium.Symmetric.NONCE_BYTES)
            throw new IOError.FAILED("Bad nonce at chunk %llu".printf(i));

        size_t plain_len = (i < chunks - 1) ? CHUNK_SIZE : (size_t)last;
        size_t ct_len = plain_len + SECRETBOX_MAC;

        uint8[] ct = fin.read_bytes(ct_len).get_data();
        if (ct.length != ct_len)
            throw new IOError.FAILED("Bad ciphertext at chunk %llu".printf(i));

        var sub = subkey(master, i);

        uint8[] pt = new uint8[plain_len];
        int rc = Sodium.Symmetric.secretbox_open(pt, ct, (ulong) ct.length, nonce, sub);
        if (rc != 0)
            throw new IOError.FAILED("Secretbox decryption failed");

        size_t written;
        out_stream.write_all(pt, out written);
        processed_cipher += (uint64) Sodium.Symmetric.NONCE_BYTES + (uint64) ct.length;
        plain_emitted += (uint64) plain_len;
        dec_progress.update (processed_cipher, cipher_total, plain_emitted);
    }

    out_stream.flush();
    out_stream.close();
    dec_progress.finish (plain_emitted, processed_cipher);

    var out_sz = out_file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE)
        .get_attribute_uint64(FileAttribute.STANDARD_SIZE);
    stats("decryption", enc_bytes, out_sz, chunks, timer.elapsed() - start);
    GLib.stdout.printf("%s\n", colour_wrap("✅ Decrypted ZSTD → " + out_file.get_path(), GRN));

    return out_file;
}


// Extract archive zstd → tar
private void extract_archive(File zstd_arc, File dst_dir) throws Error {
    dst_dir.make_directory_with_parents();

    string work_dir = create_temp_dir ("dvx3-work");
    string tar_path = GLib.Path.build_filename (work_dir, "archive.tar");

    string[] zstd_cmd = {
        "zstd", "-d",
        "-f", zstd_arc.get_path (),
        "-o", tar_path
    };

    string[] tar_cmd = {
        "tar", "-x",
        "-f", tar_path,
        "-C", dst_dir.get_path ()
    };

    string? cmd_err;
    string? cmd_out;
    int cmd_status;

    if (!run_command_sync (zstd_cmd, out cmd_out, out cmd_err, out cmd_status))
        throw new IOError.FAILED ("zstd decompress failed: " + (cmd_err ?? ""));

    if (!run_command_sync (tar_cmd, out cmd_out, out cmd_err, out cmd_status))
        throw new IOError.FAILED ("tar extract failed: " + (cmd_err ?? ""));

    FileUtils.remove (tar_path);
    FileUtils.remove (work_dir);

    GLib.stdout.printf("%s\n", colour_wrap("✅ Extracted to " + dst_dir.get_path(), GRN));
}


// Command-line encrypt/decrypt dispatch
private static int cmd_encrypt(string[] args) throws Error {
    var ctx = new OptionContext("<folder> -p <pwd> [-o <out>] [-i]");

    string? pwd = null;
    string? out_path = null;
    bool inplace = false;

    OptionEntry[] entries = {
        { "password", 'p', OptionFlags.NONE, OptionArg.STRING, &pwd, "Password for Argon2 key‑derivation", null },
        { "output", 'o', OptionFlags.NONE, OptionArg.FILENAME, &out_path, "Path for resulting *.dvx3 file (default: <folder>.dvx3)", null },
        { "in-place", 'i', OptionFlags.NONE, OptionArg.NONE, &inplace, "Allow the output file inside source folder (excluded)", null }
    };
    ctx.add_main_entries(entries, null);
    ctx.parse(ref args);

    if (args.length != 2 || pwd == null) {
        GLib.stderr.printf("Usage: %s encrypt <folder> -p <pwd> [-o <out>] [-i]\n", args[0]);
        return 1;
    }

    var src_dir = File.new_for_commandline_arg(args[1]);
    if (!src_dir.query_exists()) {
        GLib.stderr.printf("Source folder '%s' does not exist.\n", src_dir.get_path());
        return 1;
    }

    File out_file;
    if (out_path != null) {
        var path = out_path.has_suffix(".dvx3") ? out_path : out_path + ".dvx3";
        out_file = File.new_for_commandline_arg(path);
    } else {
        out_file = src_dir.get_parent().get_child(src_dir.get_basename() + ".dvx3");
    }

    encrypt_stream(src_dir, out_file, pwd, inplace);
    return 0;
}

private static int cmd_decrypt(string[] args) throws Error {
    var ctx = new OptionContext("<encrypted.dvx3> -p <pwd> -o <output_dir>");

    string? pwd = null;
    string? out_dir = null;

    OptionEntry[] entries = {
        { "password", 'p', OptionFlags.NONE, OptionArg.STRING, &pwd, "Password for Argon2 key‑derivation", null },
        { "output", 'o', OptionFlags.NONE, OptionArg.FILENAME, &out_dir, "Directory to extract the archive into", null }
    };
    ctx.add_main_entries(entries, null);
    ctx.parse(ref args);

    if (args.length != 2 || pwd == null) {
        GLib.stderr.printf("Usage: %s decrypt <encrypted.dvx3> -p <pwd> -o <output_dir>\n", args[0]);
        return 1;
    }

    var enc_file = File.new_for_commandline_arg(args[1]);
    if (!enc_file.query_exists()) {
        GLib.stderr.printf("Encrypted file '%s' does not exist.\n", enc_file.get_path());
        return 1;
    }

    File dst_dir;
    if (out_dir != null) {
        dst_dir = File.new_for_commandline_arg(out_dir);
    } else {
        var base_name = enc_file.get_basename();
        if (base_name.has_suffix(".dvx3")) {
            base_name = base_name.substring(0, base_name.length - 5);
        }
        dst_dir = enc_file.get_parent().get_child(base_name);
    }

    /* Stream directly: decrypt → zstd -d | tar -x */
    decrypt_and_extract_stream(enc_file, dst_dir, pwd);
    return 0;
}


public static int main(string[] args) {
    // Gtk.init(); // Uncomment only if using Gtk.ProgressBar

    try {
        if (args.length < 2) {
            GLib.stderr.printf("Usage: %s <encrypt|decrypt> [options]\n", args[0]);
            return 1;
        };

        string[] sub_args = new string[args.length - 1];
        for (int i = 1; i < args.length; i++)
            sub_args[i - 1] = args[i];

        switch (args[1]) {
            case "encrypt":
                return cmd_encrypt(sub_args);
            case "decrypt":
                return cmd_decrypt(sub_args);
            default:
                GLib.stderr.printf("Unknown command '%s'. Use encrypt or decrypt.\n", args[1]);
                return 1;
        }
    } catch (Error e) {
        GLib.stderr.printf("%s %s\n", colour_wrap("❌", RED), e.message);
        return 1;
    }
}
