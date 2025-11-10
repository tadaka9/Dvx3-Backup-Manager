#!/usr/bin/env valac
/* -*- coding: utf-8 -*- */

/**
 * dvx3 - Command-line interface for libdvx3
 * 
 * Simple CLI wrapper for the libdvx3 encryption library
 */

using GLib;
using Dvx3;

/* Color helpers */
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

/* Console progress bar */
private class ConsoleProgress {
    private string label;
    private uint64 total_bytes;
    private const int BAR_WIDTH = 24;

    public ConsoleProgress (string label, uint64 total_bytes) {
        this.label = label;
        this.total_bytes = total_bytes;
    }

    public void update (uint64 processed, uint64 total, uint64 output_bytes) {
        double pct = total > 0 ? (double)processed / (double)total : 0.0;
        if (pct > 1.0) pct = 1.0;

        int filled = (int)(pct * BAR_WIDTH);
        var bar = new StringBuilder ();
        for (int i = 0; i < BAR_WIDTH; i++) {
            bar.append (i < filled ? "█" : "░");
        }

        double overhead_pct = processed > 0 
            ? ((double)output_bytes / (double)processed - 1.0) * 100.0 
            : 0.0;

        GLib.stdout.printf (
            "\r%s %s %s %3.0f%% │ %s → %s (%.1f%% overhead)     ",
            colour_wrap (label, CYN),
            colour_wrap (bar.str, GRN),
            colour_wrap ("│", CYN),
            pct * 100.0,
            format_size (processed),
            format_size (output_bytes),
            overhead_pct
        );
        GLib.stdout.flush ();
    }

    public void finish (uint64 processed, uint64 output_bytes) {
        update (processed, processed, output_bytes);
        GLib.stdout.printf ("\n");
    }
}

private uint64 compute_total_size (File dir, string? skip_path) {
    uint64 total = 0;
    try {
        var enumerator = dir.enumerate_children (
            FileAttribute.STANDARD_NAME + "," +
            FileAttribute.STANDARD_TYPE + "," +
            FileAttribute.STANDARD_SIZE,
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS
        );
        
        FileInfo? info;
        while ((info = enumerator.next_file ()) != null) {
            var child = dir.get_child (info.get_name ());
            var child_path = child.get_path ();

            if (skip_path != null && child_path == skip_path)
                continue;

            if (info.get_file_type () == FileType.DIRECTORY) {
                total += compute_total_size (child, skip_path);
            } else if (info.get_file_type () == FileType.REGULAR) {
                total += info.get_size ();
            }
        }
    } catch (Error e) {
        // Ignore errors in size calculation
    }
    return total;
}

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

    var src_path = src_dir.get_path();
    var out_file_path = out_file.get_path();

    string? exclude_path = null;
    if (out_file_path.has_prefix(src_path)) {
        if (!inplace) {
            GLib.stderr.printf("Error: Output file is inside source folder – use -i/--in-place.\n");
            return 1;
        }
        exclude_path = out_file_path;
        GLib.stdout.printf(colour_wrap("⚠️  In-place mode: excluding output file from archive.\n", YLW));
    }

    uint64 total_size = compute_total_size(src_dir, exclude_path);
    var progress = new ConsoleProgress("Encrypt", total_size);
    
    Timer timer = new Timer();
    
    Dvx3.encrypt(
        src_dir,
        out_file,
        pwd,
        exclude_path,
        (processed, total, output) => {
            progress.update(processed, total, output);
        }
    );

    progress.finish(total_size, out_file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE).get_attribute_uint64(FileAttribute.STANDARD_SIZE));
    
    GLib.stdout.printf("%s\n", colour_wrap("✅ Encrypted backup → " + out_file_path, GRN));
    GLib.stdout.printf("Time: %.2fs\n", timer.elapsed());
    
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

    var enc_size = enc_file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE).get_attribute_uint64(FileAttribute.STANDARD_SIZE);
    var progress = new ConsoleProgress("Decrypt+Extract", enc_size);
    
    Timer timer = new Timer();
    
    Dvx3.decrypt(
        enc_file,
        dst_dir,
        pwd,
        (processed, total, output) => {
            progress.update(processed, total, output);
        }
    );

    progress.finish(enc_size, enc_size);
    
    GLib.stdout.printf("%s\n", colour_wrap("✅ Extracted to " + dst_dir.get_path(), GRN));
    GLib.stdout.printf("Time: %.2fs\n", timer.elapsed());
    
    return 0;
}

public static int main(string[] args) {
    try {
        if (args.length < 2) {
            GLib.stderr.printf("Usage: %s <encrypt|decrypt> [options]\n", args[0]);
            return 1;
        }

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
