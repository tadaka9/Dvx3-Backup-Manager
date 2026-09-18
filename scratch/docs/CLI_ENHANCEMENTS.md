# CLI/TUI Enhancements for Dvx3 Backup Manager

## Overview

This document outlines planned enhancements to the command-line interface and terminal user interface (TUI) of Dvx3 Backup Manager. These improvements enhance usability without requiring Qt6/GUI dependencies.

---

## Current State (Baseline)

### Available Commands
```bash
./backup-manager encrypt <folder> -p <password> [-o <output>] [-i]
./backup-manager decrypt <archive.dvx3> <destination> -p <password>
./backup-manager list          # List configured backup jobs
./backup-manager status        # Show current job status  
./backup-manager history       # View backup operation history
./backup-manager run <job>     # Execute configured backup job
./backup-manager cleanup       # Remove old backups based on retention
```

### Limitations
- No interactive prompts (all options must be specified)
- Limited progress feedback during operations
- Generic error messages without specific codes
- No validation of arguments before operation starts
- Minimal output for debugging/monitoring

---

## Planned Enhancements

### 1. Enhanced Error Messages with Exit Codes ✅ PRIORITY HIGH

#### Current Behavior
```bash
$ ./backup-manager encrypt /tmp/test -p "" -o /tmp/test.dvx3
❌ Decryption failed at chunk 0 (wrong password?)
```

#### Targeted Improvements
```bash
$ ./backup-manager encrypt /tmp/test -p "" -o /tmp/test.dvx3
╔═══════════════════════════════════════════╗
║   ❌ Backup Failed                        ║
╚═══════════════════════════════════════════╝

Error Code: E_DEC_WRONG_PASSWORD (101)
Message:   Wrong password for encryption key derivation

Details:   The provided password does not match the encrypted backup.
            This can happen if you changed the password or there's a typo.

Hint:      Double-check your password and try again.
```

**Exit Codes:**
| Code | Description | Error Type |
|------|-------------|------------|
| 0 | Success | - |
| 1 | General error / usage | - |
| 100 | File not found | `ENOENT` |
| 101 | Wrong password | `E_DEC_WRONG_PASSWORD` |
| 102 | Permission denied | `EACCES` |
| 103 | Disk full | `ENOSPC` |
| 104 | Invalid archive format | `E_BAD_ARCHIVE` |
| 105 | Integrity verification failed | `E_INTEGRITY_FAILURE` |
| 106 | Interrupted operation | `EINTR` |
| 255 | Unknown error | `E_UNKNOWN` |

#### Implementation in `main.vala`

```vala
private static int cmd_encrypt(string[] args) throws Error {
    // ... existing code ...
    
    try {
        encrypt_stream(src_dir, out_file, pwd);
        return 0;
    } catch (GLib.Error e) {
        int exit_code = 1;
        string error_type = "Unknown";
        
        switch (e.code) {
            case Error.NO_SUCH_FILE:
                exit_code = 100;
                error_type = "E_FILE_NOT_FOUND";
                break;
            case Error.PERMISSION_DENIED:
                exit_code = 102;
                error_type = "E_PERMISSION_DENIED";
                break;
            case Error.NO_SPACE_LEFT_ON_DEVICE:
                exit_code = 103;
                error_type = "E_DISK_FULL";
                break;
        }
        
        GLib.stdout.printf("\n╔═══════════════════════════════════════════╗\n║   ❌ Backup Failed                        ║\n╚═══════════════════════════════════════════╝\n\n" +
                          "Error Code: %d (%s)\nMessage:   %s\nDetails:\n",
                          exit_code, error_type, e.message);
        
        return exit_code;
    }
}
```

---

### 2. Interactive Mode for CLI ✅ PRIORITY MEDIUM

Allow users to launch backup operations with prompts for missing arguments:

```bash
$ ./backup-manager encrypt --interactive
╔═══════════════════════════════════════════╗
║   Source Directory:                       ║
╚═══════════════════════════════════════════╝

Enter source directory path: /home/user/documents
[Using current directory if empty]

╔═══════════════════════════════════════════╗
║   Password:                               ║
╚═══════════════════════════════════════════╝

Enter encryption password: 
[Password hidden from terminal, use different terminal for copy-paste]

╔═══════════════════════════════════════════╗
║   Output File:                            ║
╚═══════════════════════════════════════════╝

Enter output filename [default: documents.dvx3]: 

╔═══════════════════════════════════════════╗
║   Proceed with backup? (y/n): y           ║
╚═══════════════════════════════════════════╝

[Running backup...]
```

#### Implementation Pattern

```vala
private static int cmd_encrypt_interactive() throws Error {
    var pwd = read_password_prompt("Enter encryption password:");
    if (pwd.trim().length == 0) {
        GLib.stderr.printf("Error: Password is required\n");
        return 1;
    }
    
    string? source_path = get_string_prompt(
        "Enter source directory:", 
        null, 
        true  // directory check
    );
    
    if (source_path == null) {
        GLib.stderr.printf("Operation cancelled\n");
        return 0;  // User chose to cancel
    }
    
    // ... proceed with encryption using pwd and source_path
}

private static string read_password_prompt(string prompt) throws Error {
    var password = new SecretAgent.Password();
    GLib.stdout.printf("%s", prompt);
    GLib.stdout.flush();
    return password.read();
}
```

---

### 3. Better Progress Indicators ✅ PRIORITY HIGH

Add animated progress display during long operations:

#### ASCII Animated Progress Bar

```bash
[████████░░░░░░░░░░░] 65% │ ETA: ~1m20s │ Scanning files...
                           ↑
                         Current position
```

**Implementation:**

```vala
class AnsiProgress {
    const string BARS = "█▓▒░";
    static void display(string message, uint64 processed, uint64 total) {
        int percentage = (int)((double)processed / total * 100);
        int bar_width = 40;
        int filled = (bar_width * percentage) / 100;
        
        string bar = "";
        for (int i = 0; i < bar_width; i++) {
            bar += i < filled ? BARS[3] : BARS[0];
        }
        
        var eta = calculate_eta(processed, total, timer.elapsed() / processed);
        
        string msg = "\r[" + bar + "] %d%% │ " + 
                     "%s│ %s".printf(percentage, message, eta.to_string());
        
        GLib.stdout.printf("%s", colour_wrap(msg, COL_CYAN));
        GLib.stdout.flush();
    }
}
```

---

### 4. Verbosity Levels ✅ PRIORITY MEDIUM

Add `-v/--verbose` flag for detailed output:

```bash
# Silent mode (only success/failure)
$ ./backup-manager encrypt /data -p "password" -o backup.dvx3 > /dev/null

# Verbose mode (progress, timestamps, details)
$ ./backup-manager --verbose encrypt /data -p "password" -o backup.dvx3

Output:
╔═══════════════════════════════════════════╗
║   [1] Scanning & Archiving                ║
╚═══════════════════════════════════════════╝
Source: /data (5.23 MiB)
Files found: 42
Directories: 8

[2] Compressing...
Tar output size: 1.45 MiB

[3] Encrypting...
Cipher text size: 892 MiB

╔═══════════════════════════════════════════╗
║   ✅ Backup Complete                      ║
║      Source: 5.01 MiB -> Output: 0.86 MiB ║
║      Compression: 3.6x smaller, Integrity: On ║
║      Chunks: 8 | Time: 4.2s               ║
╚═══════════════════════════════════════════╝

Backup stored at: /tmp/dvx3-work/backup.dvx3
```

#### Implementation

```vala
public enum Verbosity {
    SILENT,   // Default for scripting
    NORMAL,   // Standard output
    VERBOSE   // Detailed output with statistics
}

static bool is_verbose = args.contains("--verbose");
static Verbosity verbosity = Verbosity.NORMAL;

// Parse verbosity from args before other parsing
foreach (arg in args) {
    if (arg == "--verbose" || arg == "-v") {
        verbosity = Verbosity.VERBOSE;
    } else if (arg == "--quiet" || arg == "-q") {
        verbosity = Verbosity.SILENT;
    }
}

private static void log(string message) {
    switch (verbosity) {
        case Verbosity.SILENT:
            break;
        case Verbosity.NORMAL:
            GLib.stdout.printf("%s\n", message);
            break;
        case Verbosity.VERBOSE:
            print_timestamp();
            GLib.stdout.printf("  %s\n", message);
            break;
    }
}

private static void log_verbose(string message) {
    if (verbosity == Verbosity.VERBOSE) {
        GLib.stdout.printf("%s\n", message);
    }
}
```

---

### 5. Dry-Run Mode ✅ PRIORITY MEDIUM

Preview backup without actually creating archive:

```bash
$ ./backup-manager --dry-run encrypt /data -p "password" -o backup.dvx3

╔═══════════════════════════════════════════╗
║   [Dry Run] Backup Preview                ║
╚═══════════════════════════════════════════╝

Would scan:
  /data/                  (5.01 MiB, 42 files)
  /data/documents/        (1.23 MiB, 15 files)
  /data/images/           (2.78 MiB, 89 files)

Would exclude:
  /data/cache/            (0.45 MiB, 12 files)

Estimated output size: ~1.45 MiB compressed
Compression ratio: ~3.4x

Encryption password set: ✓
Output file: backup.dvx3

Proceed with actual backup? (y/n): 
```

**Implementation:**

```vala
bool is_dry_run = args.contains("--dry-run");

if (is_dry_run) {
    // Scan source and print statistics without creating archive
    var src_info = File.new_for_path(src_path).query_info(...);
    uint64 total_size = src_info.get_attribute_uint64(FileAttribute.STANDARD_SIZE);
    
    // Count files and directories
    var children = src_dir.enumerate_children("*", 
        FileQueryInfoFlags.NONE,
        new Cancellable());
    uint64 file_count = 0;
    uint64 dir_count = 0;
    
    foreach (var child in children) {
        if (child.get_file_type() == FileType.FILE) file_count++;
        else dir_count++;
    }
    
    GLib.stdout.printf("╔═══════════════════════════════════════════╗\n║   [Dry Run] Backup Preview                ║\n╚═══════════════════════════════════════════╝\n\n" +
                       "Would scan:\n");
    GLib.stdout.printf("  %s (%.2f MiB, %d files, %d dirs)\n",
                       src_path, (total_size/1048576).round(2), file_count, dir_count);
    
    // Check for excluded paths if -i flag used
    if (inplace) {
        GLib.stdout.printf("Would exclude: %s/*\n", out_dir.get_path());
    }
    
    // Estimate compression based on entropy analysis
    var estimate = estimate_compression_ratio(src_path);
    GLib.stdout.printf("\nEstimated output size: %.2f MiB compressed\n" +
                       "Compression ratio: ~%.1fx\n",
                       estimate.estimated_size/1048576, 1.0/estimate.compression_factor);
    
    return 0;  // Exit successfully for dry-run
}
```

---

### 6. Archive Information Display ✅ PRIORITY LOW

Show archive contents and metadata after backup:

```bash
$ ./backup-manager encrypt /data -p "password" -o backup.dvx3

[Backup complete]

╔═══════════════════════════════════════════╗
║   Archive Information                     ║
╚═══════════════════════════════════════════╝

File:       backup.dvx3
Size:       892 KB (compressed)
Chunks:     8
Compression: zstd level 19
Integrity:  SHA-256 verification enabled
Created:    2024-12-10 15:42:33 UTC

Encryption:
  Algorithm: Argon2id (t=2, m=64000KiB, p=4)
  Mode:      XSalsa20-Poly1305

Recommendation: Store backup in read-only location for integrity safety.

┌─────────────────────────────────────────┐
│         Integrity Check                 │
├─────────────────────────────────────────┤
│ Run 'verify' command after storage      │
│ to ensure archive hasn't been corrupted │
└─────────────────────────────────────────┘
```

**Implementation:**

```vala
private static void display_archive_info(File archive) throws Error {
    var info = archive.query_info(
        FileAttribute.STANDARD_SIZE | FileAttribute.STANDARD_TYPE,
        FileQueryInfoFlags.NONE
    );
    
    GLib.stdout.printf("\n╔═══════════════════════════════════════════╗\n║   Archive Information                     ║\n╚═══════════════════════════════════════════╝\n\n" +
                       "File:       %s\n" +
                       "Size:       %.2f KiB".printf(
                           archive.get_path(), 
                           (info.get_attribute_uint64(FileAttribute.STANDARD_SIZE)/1024).round(2)
                       ) + "\n" +
                       "Chunks:     %d\n".printf(encoder.chunks) +
                       "Compression: zstd level 19\n" +
                       "Integrity:  SHA-256 verification enabled\n" +
                       "Created:    %s UTC\n",
                       archive.get_path(),
                       GLib.DateTime.now_utc().format("%Y-%m-%d %H:%M:%S"));
}
```

---

## GUI Integration (For Future Qt6 Build)

### Planned GUI Enhancements

#### 1. Multi-Tab Interface
- **Jobs Tab:** Manage backup jobs (list, add, edit, remove)
- **History Tab:** View past backups with filters
- **Settings Tab:** Configure compression, retention, exclusions

#### 2. Visual Progress Indicators
```
┌─────────────────────────────────────────────┐
│  Backup Jobs          History      Settings │
├─────────────────────────────────────────────┤
│  ┌───────────────────────────────────────┐  │
│  │ Job: Documents → backup-documents.dvx3│  │
│  │ Status: [████████░░░░░░░░] 65%       │  │
│  │ ETA: ~1m20s                           │  │
│  │                                        │  │
│  │ Source: /home/user/documents (5.0 MB) │  │
│  │ Output: backup-documents.dvx3         │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  [✓] Scheduled daily at 2 AM               │
│  [✓] Retain last 7 backups                 │
│  [ ] Email notification on failure         │
└─────────────────────────────────────────────┘
```

#### 3. Interactive Job Creation Wizard
```
┌─────────────────────────────────────────────┐
│           NEW BACKUP JOB                    │
├─────────────────────────────────────────────┤
│                                             │
│  Source Directory:                         │
│  ┌─────────────────────────────────────┐   │
│  │ /home/user/documents                │   │
│  └─────────────────────────────────────┘   │
│  [Browse]                                   │
│                                             │
│  Backup Destination:                       │
│  ┌─────────────────────────────────────┐   │
│  │ /backup/data                        │   │
│  └─────────────────────────────────────┘   │
│  [Browse]                                   │
│                                             │
│  Encryption Password:                      │
│  ┌─────────────────────────────────────┐   │
│  │ ••••••••                            │   │
│  └─────────────────────────────────────┘   │
│  [Show] [Change]                           │
│                                             │
│  Advanced Options:                         │
│  [✓] Compress with zstd                    │
│  [✓] Preserve permissions                  │
│  [ ] Follow symbolic links                 │
│  Exclude hidden files:                     │
│  [✓] .git, .cache, .local                  │
│                                             │
│                                             │
│                [Cancel]    [Create Job]    │
└─────────────────────────────────────────────┘
```

#### 4. Archive Browser (Restore Tab)
```
┌─────────────────────────────────────────────┐
│           RESTORE ARCHIVE                  │
├─────────────────────────────────────────────┤
│                                             │
│  Select Archive:                           │
│  ┌─────────────────────────────────────┐   │
│  │ backup-documents.dvx3               │   │
│  │ 5.0 MB | Created: 2024-12-10       │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Extract To:                               │
│  ┌─────────────────────────────────────┐   │
│  │ /home/user/restore                  │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Password:                                  │
│  ┌─────────────────────────────────────┐   │
│  │ ••••••••                            │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Preview Contents (42 files, 8 dirs)       │
│  ┌─────────────────────────────────────┐   │
│  │ documents/                          │   │
│  │ ├─ notes.txt                       │   │
│  │ ├─ projects/                      │   │
│  │ │   └─ thesis.pdf                 │   │
│  │ └─ photos/                        │   │
│  │     ├─ vacation.jpg                │   │
│  │     └─ family.png                  │   │
│  └─────────────────────────────────────┘   │
│                                             │
│                [Cancel]    [Restore]        │
└─────────────────────────────────────────────┘
```

---

## Testing Checklist

### CLI Enhancements
- [ ] Test error messages with wrong password
- [ ] Verify exit codes match error types
- [ ] Test verbose mode output formatting
- [ ] Validate dry-run produces accurate estimates
- [ ] Check interactive prompts in different terminals
- [ ] Ensure progress bars work with `script` and terminal multiplexers

### Integration Points
- [ ] Verify all enhancements work with existing job config
- [ ] Test encryption/decryption round-trip with new output
- [ ] Confirm integrity verification still works correctly
- [ ] Check that build scripts integrate new features

---

## Implementation Notes

1. **Backward Compatibility:** All changes are additive; no breaking changes to existing CLI commands or archives
2. **Exit Codes:** Documented in `SECURITY.md` and user-facing documentation
3. **Color Output:** Uses ANSI escape codes; automatically disabled when output not terminal
4. **Performance:** Progress bars use minimal I/O; won't slow down backup operations

---

## Future Enhancements (Beyond This Session)

1. **GUI Support:** Qt6 integration for desktop users
2. **Web Dashboard:** REST API with web-based management interface  
3. **Cloud Storage:** S3/Backblaze B2/GCS upload support
4. **Incremental Backups:** Content-aware change detection beyond timestamps
5. **Deduplication:** Block-level deduplication for storage efficiency

---

**Status:** All CLI enhancements planned and documented for implementation in next session or future milestone. GUI enhancements ready for Qt6 environment.
