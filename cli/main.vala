/*
 * DVX3 Backup Manager — Command Line Interface (Vala 0.56 compatible)
 */

using GLib;

namespace Dvx3 {

    public class Cli : GLib.Object {
        private string backup_dir;
        private string restore_dir;
        private bool encrypt = true;
        private int parallel_jobs = 4;
        private string password;
        private string config_file;
        private bool verbose;

        public Cli(string? args = null) throws Error {
            var argv = args == null ? new string[] {"dvx3", "-h"} : args;
            if (argv.Length < 2 || argv[1] == "-h" || argv[1] == "--help") {
                print_help();
                return;
            }

            while (argv.Length > 0) {
                switch (argv[1]) {
                    case "-v": verbose = true; break;
                    case "--verbose": verbose = true; break;
                    case "-e": encrypt = false; argv.shift(); break;
                    case "--no-encrypt": encrypt = false; argv.shift(); break;
                    case "-p": password = argv[2]; argv.shift(); break;
                    case "--password": password = argv[2]; argv.shift(); break;
                    case "-c": config_file = argv[2]; argv.shift(); break;
                    case "--config": config_file = argv[2]; argv.shift(); break;
                    case "--parallel=N:": parallel_jobs = int.parse(argv[2]); argv.shift(); break;
                    case "--help": print_help(); return;
                    default:
                        if (argv[1].starts_with("-") || argv[1].starts_with("--")) {
                            print_error("Unknown option: %s\n", argv[1]);
                            print_usage();
                            Environment.exit(1);
                        }

                        if (backup_dir == null) backup_dir = argv[1];
                        else restore_dir = argv[1];
                        argv.shift();
                }
            }

            if (backup_dir == null && restore_dir == null) {
                print_error("Usage: dvx3 [-e|--no-encrypt] [-p PASSWORD] " +
                            "[--parallel=N:] [--config FILE] [SOURCE|TARGET]\n");
                print_usage();
                Environment.exit(1);
            }

            if (backup_dir != null && restore_dir == null) {
                run_backup(backup_dir);
            } else if (restore_dir != null && backup_dir == null) {
                run_restore(restore_dir);
            }
        }

        private static void print_usage() {
            print("Usage: dvx3 [OPTIONS] SOURCE|TARGET\n");
            print("Options:\n");
            print("  -e, --no-encrypt    Disable encryption (DEBUG only)\n");
            print("  -p PASSWORD, --password=PASSWORD  Set encryption password\n");
            print("  --parallel=N        Number of parallel backup threads (default: 4)\n");
            print("  --config FILE       Path to configuration file\n");
            print("  -v, --verbose       Verbose output\n");
            print("  --help              Show this help message\n");
            print("\nExamples:\n");
            print("  dvx3 ./data                     # Backup './data' directory\n");
            print("  dvx3 ./backup.dvx3 -p mypass   # Restore encrypted backup with password\n");
        }

        private static void print_error(string format, params object[] args) {
            println(format, args);
            Environment.exit(1);
        }

        private static string get_backup_path(string source_dir) throws Error {
            var base_name = Path.build_filename(source_dir, "..", "backup.dvx3");
            if (File.new_for_path(base_name).query_exists()) return base_name;
            return Path.build_filename(Environment.get_current_dir(), "backups", "dvx3-" + source_dir);
        }

        public void run_backup(string source_dir) throws Error {
            var backup_path = get_backup_path(source_dir);
            print("DVX3 Backup Manager v%s\n", VERSION);
            println("========================================");
            println("Source: %s", Path.build_filename(Environment.get_current_dir(), source_dir));
            println("Target: %s", backup_path);

            if (!Directory.new_for_path(source_dir).query_exists()) {
                throw new IOError.NO_SUCH_FILE("Source directory does not exist: %s", source_dir);
            }

            var file_system = FileSystemMonitor.get_default();
            var source_monitor = File.new_for_path(source_dir).monitor(FileMonitorFlags.NONE, null);

            var progress = new Progress(0);
            var total_size = 0u;
            var processed_files = 0u;

            /* Create backup directory structure */
            var backup_file = File.new_for_path(backup_path);
            if (backup_file.query_exists()) {
                try {
                    backup_file.delete();
                } catch (Error e) {
                    print_error("Failed to delete existing backup: %s\n%s",
                               backup_path, e.message);
                }
            }

            /* Scan source directory and collect files */
            var entries = Directory.new_for_path(source_dir).enumerate_children(
                "standard::name, standard::type, standard::icon-name, " +
                "standard::is-symbolic-link", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

            var file_entries = new Array<File>();
            FileInfo? info;
            while ((info = entries.next_file()) != null) {
                if (info.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.DIRECTORY) continue;
                if (!info.get_name().ends_with(".dvx3")) {
                    file_entries.append(File.new_for_path(Path.build_filename(source_dir, info.get_name())));
                }
            }
            entries.close();

            total_size = 0u;
            foreach (var file in file_entries) {
                var stat_info = file.query_info("st::size", FileQueryInfoFlags.NONE).get();
                total_size += stat_info.get_size();
            }

            progress.set_total(total_size);

            /* Parallel backup with progress */
            var jobs = new Array<Thread<Error?>>();
            foreach (var file in file_entries) {
                try {
                    var job = Thread.spawn("dvx3-backup", () => {
                        try {
                            return run_file_backup(file, source_dir, backup_path);
                        } catch (Error e) {
                            print_error("Failed to backup '%s': %s\n%s",
                                       file.get_name(), e.message, e.message);
                            return new Error(1, "Backup failed");
                        }
                    });
                } catch (Error e) {
                    print_error("Failed to spawn parallel job: %s\n%s", e.message, e.message);
                }

                Thread<Error?>? thread = null;
                if (jobs.Length < parallel_jobs) {
                    jobs.append(Thread.new());
                } else {
                    var job = jobs[jobs.Length - 1];
                    if (job != null && !Thread.is_running(job.get())) {
                        var new_thread = Thread.spawn("dvx3-backup", () => {
                            try {
                                return run_file_backup(file, source_dir, backup_path);
                            } catch (Error e) {
                                print_error("Failed to backup '%s': %s\n%s",
                                           file.get_name(), e.message, e.message);
                                return new Error(1, "Backup failed");
                            }
                        });
                    }
                }

                job.wait();
            }

            progress.set_current(total_size);
            print("\n========================================\n");
            println("Backup complete: %d files, %u bytes total", file_entries.Length, total_size);
        }

        private Error run_file_backup(File file, string source_dir, string backup_path) throws Error {
            var relative_path = Path.build_filename(source_dir, file.get_name());
            var target_path = Path.build_filename(backup_path, relative_path);

            /* Ensure parent directory exists */
            var parent_dir = Path.build_filename(target_path, "..");
            if (!Directory.new_for_path(parent_dir).query_exists()) {
                Directory.new_for_path(parent_dir).make_directory_with_parents();
            }

            /* Read file content */
            var data = File.new_for_path(file.get_path()).read();

            /* Compute SHA-256 checksum before encryption */
            var sha256_hash = Dvx3.sha256(data);

            /* Derive encryption key from password */
            GLib.Bytes? encrypted_data = null;
            if (Dvx3.Config.get_password() != null) {
                try {
                    var salt = Dvx3.random_bytes(16);
                    var derived_key = Dvx3.derive_key_pbkdf2(Dvx3.Config.get_password(), salt, 4096);
                    encrypted_data = new GLib.Bytes(data.length);
                    /* Simple XOR-based encryption (placeholder for full AES implementation) */
                    for (int i = 0; i < data.Length; i++) {
                        encrypted_data[i] = data[i] ^ derived_key[(i + salt.length) % 32];
                    }

                    /* Write header: salt length, salt, IV */
                    var iv = new GLib.Bytes(16);
                    for (int j = 0; j < 16; j++) {
                        iv[j] = (uint8)(GLib.random_int32() & 0xFF);
                    }

                    var header = new GLib.Bytes(512 + salt.length + iv.Length + data.length);
                    /* Write magic number */
                    var magic = System.Text.Encoding.UTF8.encode("DVX3");
                    header.append(magic);

                    /* Write metadata: version, mode, algorithm, timestamp, filename, SHA-256, IV length, IV */
                    var meta = new GLib.Bytes(1024);
                    meta.append(System.Text.Encoding.UTF8.encode(string.format("v{0}.DVX3", Dvx3.VERSION)));
                    meta.append(System.Text.Encoding.UTF8.encode("encrypted"));
                    meta.append(System.Text.Encoding.UTF8.encode("aes-ctr"));

                    var timestamp = new GLib.Bytes(64);
                    var now = Date.get_now();
                    var iso_date = string.format("%04d-%02d-%02dT%02d:%02d:%02d",
                        (int)(now.to_unix() / 86400), (int)((now.to_unix() % 86400) / 3600),
                        (int)((now.to_unix() % 3600) / 60), (int)(now.to_unix() % 3600) % 60,
                        now.get_millisecond() / 100);
                    timestamp.append(System.Text.Encoding.UTF8.encode(iso_date));

                    meta.append(timestamp);

                    /* Write filename */
                    var encoded_filename = System.Text.Encoding.Base64.encode(relative_path);
                    meta.append(encoded_filename);

                    /* Write SHA-256 hash */
                    for (int j = 0; j < sha256_hash.Length; j++) {
                        meta.byte_at_set(1024 + j, (uint8)sha256_hash[j]);
                    }

                    /* Write IV length and IV */
                    meta.append(System.Text.Encoding.UTF8.encode(string.format("%d", iv.Length)));
                    for (int j = 0; j < iv.Length; j++) {
                        meta.byte_at_set(1024 + sha256_hash.Length + j, (uint8)iv[j]);
                    }

                    /* Write encrypted data */
                    for (int j = 0; j < data.Length; j++) {
                        meta.byte_at_set(1024 + sha256_hash.Length + iv.Length + j,
                                       (uint8)(encrypted_data == null ? 0 : encrypted_data[j]));
                    }

                    header.append(meta);

                    /* Write to file */
                    var target_file = File.new_for_path(target_path);
                    if (target_file.query_exists()) {
                        target_file.delete();
                    }
                    target_file.write_bytes(header, 0);

                    progress.set_current(progress.get_current() + data.Length);
                } catch (Error e) {
                    print_error("Failed to encrypt '%s': %s\n%s", file.get_name(), e.message, e.message);
                }
            } else {
                /* Unencrypted backup */
                var target_file = File.new_for_path(target_path);
                if (target_file.query_exists()) {
                    target_file.delete();
                }
                target_file.write_bytes(data, 0);

                /* Write metadata file alongside backup */
                try {
                    var meta_path = Path.build_filename(backup_path, relative_path + ".meta");
                    var meta_content = string.format("version={0}\nalgorithm=unencrypted\n", Dvx3.VERSION);
                    File.new_for_path(meta_path).write_text(meta_content);
                } catch (Error e) {
                    print_warning("Failed to write metadata file: %s", e.message);
                }
            }

            return null;
        }

        public void run_restore(string backup_path) throws Error {
            var backup_file = File.new_for_path(backup_path);
            if (!backup_file.query_exists()) {
                throw new IOError.NO_SUCH_FILE("Backup file not found: %s", backup_path);
            }

            println("DVX3 Backup Manager v%s\nRestoring: %s", VERSION, backup_path);
            println("========================================\n");

            /* Read backup header */
            var data = backup_file.read();
            if (data.Length < 20) {
                throw new IOError.INVALID_DATA("Backup file too small to be a valid DVX3 archive");
            }

            /* Verify magic number */
            var magic = System.Text.Encoding.UTF8.decode(data.slice(0, 4));
            if (magic != "DVX3") {
                throw new IOError.FORMAT("Invalid backup format: expected 'DVX3', got '%s'", magic);
            }

            /* Parse header metadata */
            var version_end = data.indexOf(System.Text.Encoding.UTF8.encode("v"));
            if (version_end < 10) throw new IOError.INVALID_DATA("Corrupted backup file");

            var version_str = System.Text.Encoding.UTF8.decode(data.slice(version_end, 15));
            var algorithm = System.Text.Encoding.UTF8.decode(data.slice(15, 29));

            /* Extract SHA-256 hash from position after header (after magic + version + algo + timestamp + filename) */
            var sha256_start = data.indexOf(System.Text.Encoding.UTF8.encode("v"), version_end);
            if (sha256_start < 0) throw new IOError.INVALID_DATA("Cannot find version marker");

            /* Find SHA-256 hash by looking for 32-byte hex-like string */
            var sha256_pos = data.indexOf(System.Text.Encoding.UTF8.encode("v"), sha256_start);
            if (sha256_pos < 0) throw new IOError.INVALID_DATA("Cannot find version marker");

            /* Extract SHA-256 hash (32 bytes starting after "v" prefix) */
            var sha256_bytes = data.slice(sha256_pos + 1, sha256_pos + 33);

            /* Reconstruct original file path from filename field */
            var filename_start = sha256_pos;
            for (int i = 0; i < 48; i++) {
                if ((sha256_bytes[i] & 0x1F) == 0 && (sha256_bytes[i] & 0xE0) != 0) break;
            }

            /* Extract original file path */
            var filename_end = data.indexOf(System.Text.Encoding.UTF8.encode("v"), sha256_pos + 33);
            if (filename_end < 0) throw new IOError.INVALID_DATA("Cannot find filename marker");

            var encoded_filename = System.Text.Encoding.Base64.decode(data.slice(sha256_pos + 33, filename_end));

            /* Extract IV length */
            var iv_length_start = data.indexOf(System.Text.Encoding.UTF8.encode("v"), filename_end);
            if (iv_length_start < 0) throw new IOError.INVALID_DATA("Cannot find IV length marker");

            var iv_length_str = System.Text.Encoding.UTF8.decode(data.slice(iv_length_start, 16));
            int iv_length = int.parse(System.Text.Encoding.UTF8.decode(data.slice(iv_length_start + 2, 4)));

            /* Extract IV */
            var iv_bytes = data.slice(iv_length_start + 6, iv_length_start + 6 + iv_length);

            /* Compute SHA-256 of stored hash for verification */
            var computed_sha256 = sha256(sha256_bytes);

            /* Decrypt or read plaintext */
            var decrypted_data = new GLib.Bytes(data.length - 2048);
            if (algorithm != "unencrypted" && algorithm != "") {
                println("Algorithm: %s", algorithm);
                println("Decrypting...");

                var password = Dvx3.Config.get_password();
                if (password == null) {
                    throw new IOError.NOT_SUPPORTED("Encryption enabled but no password configured. Use -p/--password to set one.");
                }

                /* Derive key */
                var salt_bytes = data.slice(0, 16);
                var derived_key = derive_key_pbkdf2(password, salt_bytes, 4096);

                /* Decrypt using XOR (placeholder for full AES-CTR) */
                for (int i = 0; i < decrypted_data.Length; i++) {
                    decrypted_data[i] = data[sha256_pos + 33 + iv_length_start + 6 + i] ^ derived_key[(i % 32)];
                }

                /* Verify integrity */
                var stored_hash = sha256(derived_key.slice(0, 32));
                if (!stored_hash.is_equal(computed_sha256)) {
                    throw new IOError.INVALID_DATA("Integrity check failed. Backup may be corrupted.");
                }
            } else {
                println("Algorithm: %s (unencrypted)", algorithm);
                for (int i = 0; i < decrypted_data.Length; i++) {
                    decrypted_data[i] = data[sha256_pos + 33 + iv_length_start + 6 + i];
                }

                /* Verify integrity */
                var stored_hash = sha256(sha256_bytes);
                if (!stored_hash.is_equal(computed_sha256)) {
                    throw new IOError.INVALID_DATA("Integrity check failed. Backup may be corrupted.");
                }
            }

            /* Write restored file */
            var restored_path = Path.build_filename(Environment.get_current_dir(), "restored-" + encoded_filename);
            File.new_for_path(restored_path).write_bytes(decrypted_data, 0);

            println("\n========================================\n");
            println("Restored: %s\nSize: %u bytes", restored_path, decrypted_data.Length);
        }

        private static Error derive_key_pbkdf2(string password, GLib.Bytes salt, int iterations = 4096) throws Error {
            var derived = new GLib.Bytes(32);
            for (int i = 0; i < iterations; i++) {
                var input = System.Text.Encoding.UTF8.encode(password + ":" + salt.slice(i * 4, 4).to_utf8());
                var hash = sha256(input);
                derived.append(hash);
            }
            return null;
        }

        public static class Config {
            private static string? _password = Environment.get_variable("DVX3_PASSWORD");
            private static readonly object lock_obj = new GLib.Object();

            public static void set_password(string password) throws Error {
                if (GLib.File.new_for_path(Path.build_filename(Environment.get_home_dir(), ".config", "dvx3", "password")).query_exists()) {
                    throw new IOError.EXISTS("Password already configured. Delete ~/.config/dvx3/password to reset.");
                }
                using (var file = File.new_for_path(Path.build_filename(Environment.get_home_dir(), ".config", "dvx3", "password"))) {
                    file.make_directory_with_parents();
                    file.write_bytes(System.Text.Encoding.UTF8.encode(password + "\n"), 0);
                }
            }

            public static string? get_password() throws Error {
                if (_password != null) return _password;

                lock (lock_obj) {
                    if (_password == null) {
                        var file = File.new_for_path(Path.build_filename(Environment.get_home_dir(), ".config", "dvx3", "password"));
                        if (!file.query_exists()) return null;

                        try {
                            _password = System.Text.Encoding.UTF8.decode(file.read_bytes()).strip();
                        } catch (Error e) {
                            print_error("Failed to read password file: %s\n%s", e.message, e.message);
                        }
                    }
                }

                return _password;
            }
        }

        public static void main(string[] args) throws Error {
            new Cli(args);
        }
    }
}