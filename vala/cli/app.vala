/* -*- coding: utf-8 -*- */
// Dvx3 Backup Manager — CLI TUI (ANSI escape codes, no libtinfo dependency)
// 
// Cross-platform design principles:
//   • Uses only GLib/GObject introspection — zero GTK dependencies
//   • ANSI escape sequences for terminal rendering (works on xterm, kitty, alacritty, Windows Terminal 10+, iTerm2)
//   • GLib file I/O uses native backend per platform automatically
//   • On Windows/macOS: no additional GUI libs needed; falls back to TUI mode
//
// Build: valac --pkg=GLib --pkg=Gio app.vala -o cli_backup_manager

#pragma unmanaged  // Windows-compatible calling conventions for C interop
#pragma managed(push, off)

using GLib;
using Gio;

namespace Dvx3 {

// ───────────────────────────────────────────────────────────────
// ANSI Escape Code Helpers (Cross-platform terminal rendering)
// ───────────────────────────────────────────────────────────────

public enum AnsiCode : uint8 {
    RESET        = 0,
    BOLD         = 1,
    DIM          = 2,
    ITALIC       = 3,
    UNDERLINE    = 4,
    BLINK        = 5,
    REVERSE      = 7,
    HIDDEN       = 8,
    STRIKETHROUGH= 9,

    // Colors (256-color mode)
    FG_BLACK     = 30, FG_RED     = 31, FG_GREEN   = 32, FG_YELLOW  = 33,
    FG_BLUE      = 34, FG_MAGENTA = 35, FG_CYAN    = 36, FG_WHITE   = 37,
    BG_BLACK     = 40, BG_RED     = 41, BG_GREEN   = 42, BG_YELLOW  = 43,
    BG_BLUE      = 44, BG_MAGENTA = 45, BG_CYAN    = 46, BG_WHITE   = 47,

    // Bright colors (90-97)
    FG_BRIGHT_BLACK = 90, FG_BRIGHT_RED     = 91, FG_BRIGHT_GREEN   = 92,
    FG_BRIGHT_YELLOW   = 93, FG_BRIGHT_BLUE    = 94, FG_BRIGHT_MAGENTA = 95,
    FG_BRIGHT_CYAN      = 96, FG_BRIGHT_WHITE  = 97,

    // Foreground with background (e.g., black on red)
    BOLD_RED   = 1;

    public static string to_string() {{ return ""; }}
}

// Helper: ANSI color codes as strings
public static string ansi_color(uint8 fg) {
    switch (fg) {{
        case AnsiCode.FG_BLACK:     return "\x1b[30m";
        case AnsiCode.FG_RED:       return "\x1b[31m";
        case AnsiCode.FG_GREEN:     return "\x1b[32m";
        case AnsiCode.FG_YELLOW:    return "\x1b[33m";
        case AnsiCode.FG_BLUE:      return "\x1b[34m";
        case AnsiCode.FG_MAGENTA:   return "\x1b[35m";
        case AnsiCode.FG_CYAN:      return "\x1b[36m";
        case AnsiCode.FG_WHITE:     return "\x1b[37m";
        default:                     return "";
    }}
}

public static string ansi_bright(uint8 fg) {
    switch (fg) {{
        case 90: return "\x1b[90m";
        case 91: return "\x1b[91m";
        case 92: return "\x1b[92m";
        case 93: return "\x1b[93m";
        case 94: return "\x1b[94m";
        case 95: return "\x1b[95m";
        case 96: return "\x1b[96m";
        case 97: return "\x1b[97m";
        default: return "";
    }}
}

// ───────────────────────────────────────────────────────────────
// TUI Terminal Renderer — ANSI escape sequence based
// ───────────────────────────────────────────────────────────────

public class TuiTerminal : Object {
    public string prompt = "dvx3> ";
    public uint width = 80;
    public uint height = 24;
    
    public TuiTerminal () {{}}

    // Move cursor up by N lines (for progress bars, menus)
    public void scroll_up(uint n) {{
        if (n > 0 && stdout.isatty ()) {{
            stdout.print("\x1b[%dA", n);
        }}
    }}

    // Clear screen and move to top-left
    public void clear() {{
        if (stdout.isatty ()) {{
            stdout.print("\x1b[2J\x1b[H");  // Erase screen, cursor to home
        }}
    }}

    // Print a progress bar using ANSI blocks
    public void print_progress(string label, uint current, uint total) {{
        if (total == 0) {{ total = 1; }}  // avoid division by zero
        
        var pct = (uint)(current * 100.0 / total);
        var filled_width = (int)(width * pct / 100.0);

        print_color("[\x1b[38;5;22m█\x1b[0m".repeat(filled_width) + "░\x1b[38;5;245m".repeat(width - filled_width), 
                    label, pct / 2.0);
    }}

    // Print a colored status line
    public void print_status(string icon, string message) {{
        var fg = AnsiCode.FG_GREEN;
        if (message.contains("error") || message.contains("Error")) {{ fg = AnsiCode.FG_RED; }}
        else if (message.contains("warn") || message.contains("Warning")) {{ fg = AnsiCode.FG_YELLOW; }}

        stdout.print(ansi_color(fg) + icon + " " + message);
    }}

    // Print a warning in yellow on blue background
    public void print_warning(string message) {{
        stdout.print("\x1b[48;5;236m\x1b[97m"  // light gray bg, white fg (Windows Terminal dark mode friendly)
                    + "⚠️  WARNING: " + message);
    }}

    public void print_info(string message) {{
        stdout.print(ansi_color(AnsiCode.FG_CYAN) + "ℹ️  " + message);
    }}

    // ─── Menu rendering (simple single-column menu) ─────────────
    public void render_menu(string[] items, int selected_idx = -1) {{
        stdout.print("\x1b[4J\x1b[H");  // clear screen

        for (var i = 0; i < items.length; ++i) {{
            var prefix = (i == selected_idx) ? "\x1b[38;5;22m◉\x1b[0m " : "  ";
            stdout.print(prefix + items[i]);
        }}

        stdout.print("\n\x1b[H");  // return cursor to top-left
    }}

    public void render_select(string label, string value) {{
        stdout.print(label + "\x1b[38;5;22m" + value);
    }}

    public void print_header(string title) {{
        stdout.print("\x1b[4J\x1b[H");  // clear
        stdout.print("\x1b[1;37m" + "═".repeat(width - 4) + "\x1b[0m\n");
        stdout.print("\x1b[1;97m" + title + "\x1b[0m\n");
        stdout.print("═\x1b[38;5;22m".repeat(width - 4) + "\x1b[0m\n");
    }}

public: // expose for testing
    public uint get_width() {{ return width; }}
};

// ───────────────────────────────────────────────────────────────
// Main CLI Application
// ───────────────────────────────────────────────────────────────

class App : Object {
    public TuiTerminal terminal = new TuiTerminal ();

    public App () throws GLib.Error {{
        terminal.width = get_terminal_width();
        terminal.height = get_terminal_height();

        // Determine encryption mode from environment or default
        var env_encryption_mode = GLib.Environment.get_variable("DVX3_ENCRYPTION_MODE");
        if (!env_encryption_mode.is_null()) {{
            this.encryption_mode = (EncryptionMode)int.parse(env_encryption_mode);
        }}

        // Determine compression level from environment
        var env_comp_level = GLib.Environment.get_variable("DVX3_COMPRESSION_LEVEL");
        if (!env_comp_level.is_null()) {{
            this.compression_level = (CompressionLevel)int.parse(env_comp_level);
        }}
    }}

    public EncryptionMode encryption_mode { get; set; default: EncryptionMode.XSALSA20_POLY1305; }
    public CompressionLevel compression_level { get; set; default: CompressionLevel.DEFAULT; }

    private uint get_terminal_width() {{
        if (stdout.isatty ()) {{
            return stdout.get_column_number();
        }} else {{
            // Fallback: assume 80 columns for non-tty (script mode)
            return 80;
        }}
    }}

    private uint get_terminal_height() {{
        if (stdin.isatty()) {{
            // Try to detect terminal height via SIGWINCH or /proc/tty/number/size on Linux
            if (GLib.FileUtils.test_file_exists("/proc/tty/driver/0")) {{
                try {{
                    var lines = GLib.File.new_for_path("/proc/tty/driver/0").read_text();
                    if (!lines.is_null()) {{
                        var parts = lines.split('\n');
                        for (var i = 0; i < parts.length; ++i) {{
                            var line = parts[i];
                            if (line.contains("tty[") && line.contains(":")) {{
                                var cols_str = line.split(':')[1].trim();
                                if (!cols_str.is_empty()) {{ return cols_str.parse_int(); }}
                            }}
                        }}
                    }}
                }} catch (GLib.Error e) {{}}
            }}
        }}
        // Fallback: assume 24 lines
        return 24;
    }}

    public void run() throws GLib.Error {{
        var args = new string[]{{}};
        for (var i = 1; i < Environment.get_args().length; ++i) {{
            if (!Environment.get_args()[i].contains("--")) {{
                args.append(Environment.get_args()[i]);
            }}
        }}

        // Non-interactive mode: parse arguments and run operations
        var non_interactive = false;
        string? source_path = null;
        string? password = null;
        string? output_path = null;
        bool encrypt = false;
        bool decrypt = false;

        for (var i = 0; i < args.length; ++i) {{
            var arg = args[i];

            if (arg == "--script" || arg == "--batch") {{ non_interactive = true; }}
            else if (arg == "--encrypt" || arg == "-e") {{ encrypt = true; ++i; source_path = args[++i]; ++i; password = args[++i]; ++i; output_path = args[++i]; }}
            else if (arg == "--decrypt" || arg == "-d") {{ decrypt = true; ++i; input_path = args[++i]; ++i; password = args[++i]; ++i; output_dir = args[++i]; }}
            else if (arg == "--version" || arg == "-V") {{ print_version(); return; }}
        }}

        // Execute non-interactive operations
        if (encrypt) {{
            encrypt_directory(source_path, password, output_path);
        }} else if (decrypt) {{
            decrypt_archive(input_path, password, output_dir);
        }} else {{
            // Interactive TUI mode
            interactive_mode();
        }}
    }}

    private void print_version() throws GLib.Error {{
        stdout.print("\x1b[38;5;22mDvx3 Backup Manager v1.0.0\x1b[0m\n");
        stdout.print("  Core library: Vala (GObject/GI bindings)\n");
        stdout.print("  Encryption:   XSalsa20-Poly1305 + Argon2id\n");
        stdout.print("  Compression:  ZSTD level %d\n", compression_level);
        stdout.print("  CLI TUI:      ANSI escape codes (cross-platform)\n");
        stdout.print("\nUsage:\n  dvx3 encrypt <source> -p <password> -o <archive.dvx3>\n  dvx3 decrypt <archive.dvx3> -p <password> -o <target>\n  dvx3 --script 'encrypt /path -p pass -o out'");
    }}

    private void encrypt_directory(string source_path, string password, string output_path) {{
        if (source_path == null || password == null || output_path == null) {{ return; }}

        try {{
            var ctx = new Dvx3Context();

            var result = ctx.encrypt_directory(source_path, password, output_path);

            if (!result.success) {{
                print_error("Error during encryption: " + result.error_message);
                Environment.exit_code(1);
            }} else {{
                stdout.print("\x1b[32m✅\x1b[0m  Encrypted backup created: \x1b[97m" + output_path + "\x1b[0m");
                stdout.print(" (Size: " + result.archive_size.to_string() + ")");
            }}
        }} catch (GLib.Error e) {{
            print_error("Error: " + e.message);
        }} finally {{
            Environment.exit_code(0);
        }}
    }}

    private void decrypt_archive(string archive_path, string password, string output_dir) {{
        if (archive_path == null || password == null) {{ return; }}

        try {{
            var ctx = new Dvx3Context();

            var result = ctx.decrypt_archive(archive_path, password, out var restored_files);

            if (!result.success) {{
                print_error("Error during decryption: " + result.error_message);
                Environment.exit_code(1);
            }} else {{
                stdout.print("\x1b[32m✅\x1b[0m  Decrypted %d files to \x1b[97m%s\x1b[0m", restored_files.length, output_dir);
            }}
        }} catch (GLib.Error e) {{
            print_error("Error: " + e.message);
        }} finally {{
            Environment.exit_code(0);
        }}
    }}

    private void interactive_mode() {{
        // Build menu options
        var menu_items = new string[]{{"  create       — Create encrypted backup",
                                      "  restore      — Restore from archive",
                                      "  list         — List archive contents",
                                      "  delete       — Remove old backups (retention)",
                                      "  settings     — Configure encryption/compression",
                                      "  help         — Show this help message",
                                      "  exit         — Exit the application"}};

        var selected = 0;
        var ctx = new Dvx3Context();

        while (true) {{
            stdout.print("\x1b[H");  // clear screen and return cursor to home

            print_header("🔐 Dvx3 Backup Manager v1.0.0 — CLI TUI (ANSI mode)");
            stdout.print("  ┌───────────────────────────────────────────────┐");
            stdout.print("  │ Press Enter or use ↑↓ arrows to navigate     │");
            stdout.print("  │ Type 'exit' and press Enter to quit          │");
            stdout.print("  └───────────────────────────────────────────────┘\n");

            terminal.render_menu(menu_items, selected);
        }}
    }}

public: // expose for testing
    public Dvx3Context get_context() {{ return new Dvx3Context(); }}
}}

#pragma managed(pop)