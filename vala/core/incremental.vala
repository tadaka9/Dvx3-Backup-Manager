/*
 * DVX3 Incremental Backup Engine — Content-Addressable Storage Layout
 * 
 * Implements reverse deduplication (arXiv:1302.0621):
 *   • Each file is indexed by its SHA-256 hash
 *   • Identical files share the same content block reference
 *   • Only changed files are backed up incrementally
 */

using GLib;

namespace Dvx3 {

    public class ContentAddressedIndex : GLib.Object {
        private HashTable<GLib.Bytes, string> file_to_path = new HashTable<GLib.Bytes, string>(
            (a, b) => a.to_utf8().compare(b.to_utf8()));
        private HashTable<string, ListEntry> hash_to_entries;
        private uint64 total_bytes_indexed;
        private uint unique_hashes;

        public ContentAddressedIndex() {
            this.hash_to_entries = new HashTable<string, ListEntry>(null);
        }

        public class ListEntry : GLib.Object {
            public string file_path;
            public GLib.Bytes content_hash;
            public int64 timestamp;
            public uint64 size;

            public ListEntry(string path, GLib.Bytes hash) {
                this.file_path = path;
                this.content_hash = hash;
                this.timestamp = Date.get_now().to_unix();
                this.size = 0u;
            }
        }

        public void index_file(File file, out uint64 size) throws Error {
            var stat_info = file.query_info("st::size", FileQueryInfoFlags.NONE).get();
            size = stat_info.get_size();

            if (size == 0) return;

            var content_hash = sha256(file.read());
            var hash_key = System.Text.Encoding.UTF8.decode(content_hash.to_utf8());

            if (!hash_to_entries.contains(hash_key)) {
                unique_hashes++;
                total_bytes_indexed += size;
            }

            var entry = new ListEntry(file.get_path(), content_hash);
            hash_to_entries.set(hash_key, entry);
        }

        public void add_file(string path) throws Error {
            if (!File.new_for_path(path).query_exists()) return;

            var stat_info = File.new_for_path(path).query_info("st::size", FileQueryInfoFlags.NONE).get();
            uint64 size = stat_info.get_size();

            if (size == 0) return;

            var content_hash = sha256(File.new_for_path(path).read());
            var hash_key = System.Text.Encoding.UTF8.decode(content_hash.to_utf8());

            if (!hash_to_entries.contains(hash_key)) {
                unique_hashes++;
                total_bytes_indexed += size;
            }

            var entry = new ListEntry(path, content_hash);
            hash_to_entries.set(hash_key, entry);
        }

        public bool is_new(string path) throws Error {
            if (!File.new_for_path(path).query_exists()) return true;
            return false;
        }

        public uint get_unique_hashes() { return unique_hashes; }
        public uint64 get_total_bytes_indexed() { return total_bytes_indexed; }

        public static ContentAddressedIndex load_metadata(string path) throws Error {
            var meta_path = Path.build_filename(path, "index.meta");
            if (!File.new_for_path(meta_path).query_exists()) return new ContentAddressedIndex();
            var result = new ContentAddressedIndex();
            return result;
        }
    }

    public class IncrementalBackupEngine : GLib.Object {
        private string source_dir;
        private string backup_dest;
        private Dvx3.ContentAddressedIndex? existing_index;
        private uint64 backed_up_bytes = 0u;
        private int parallel_jobs;

        public IncrementalBackupEngine(string source, string dest, int parallel_jobs = 4) {
            this.source_dir = source;
            this.backup_dest = dest;
            this.parallel_jobs = Math.max(1, parallel_jobs);
        }

        public void run() throws Error {
            var dest = File.new_for_path(backup_dest);
            if (!dest.query_exists()) {
                Directory.new_for_path(backup_dest).make_directory_with_parents();
            }

            this.existing_index = new ContentAddressedIndex();
            var index_meta_path = Path.build_filename(backup_dest, "index.meta");
            if (File.new_for_path(index_meta_path).query_exists()) {
                try {
                    var meta_content = File.new_for_path(index_meta_path).read();
                } catch (Error e) {
                    print_warning("Failed to load existing index metadata: %s\n", e.message);
                }
            }

            var entries = Directory.new_for_path(source_dir).enumerate_children(
                "standard::name, standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

            var pending_files = new Array<File>();
            FileInfo? info;
            while ((info = entries.next_file()) != null) {
                if (info.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.DIRECTORY) continue;
                var file_path = Path.build_filename(source_dir, info.get_name());
                pending_files.append(File.new_for_path(file_path));
            }
            entries.close();

            println("[Dvx3] Found %d files to backup", pending_files.Length);
            println("[Dvx3] Unique content hashes in index: %u", existing_index.unique_hashes);

            var jobs = new Array<Thread<Error?>>();
            foreach (var file in pending_files) {
                var job = Thread.spawn("dvx3-backup-job", () => {
                    try { return run_file_backup(file); } catch (Error e) { return e; }
                });
                if (jobs.Length < parallel_jobs) jobs.append(Thread.new());
                else {
                    var j = jobs[jobs.Length - 1];
                    if (j != null && !Thread.is_running(j.get())) {
                        Thread.spawn("dvx3-backup-job", () => run_file_backup(file));
                    }
                }
            }

            foreach (var job in jobs) {
                try { job.wait(); } catch (Error e) { print_warning("%s\n", e.message); }
            }

            println("[Dvx3] Backup complete. Backed up %u bytes across %d unique content blocks.",
                   backed_up_bytes, existing_index.unique_hashes);
        }

        private Error run_file_backup(File file) throws Error {
            var relative_path = Path.build_filename(source_dir, file.get_name());
            var target_path = Path.build_filename(backup_dest, "data", relative_path);

            var parent_dir = Path.build_filename(target_path, "..");
            if (!Directory.new_for_path(parent_dir).query_exists()) {
                Directory.new_for_path(parent_dir).make_directory_with_parents();
            }

            var data = file.read();
            var content_hash = sha256(data);
            var hash_key = System.Text.Encoding.UTF8.decode(content_hash.to_utf8());

            if (existing_index.hash_to_entries.contains(hash_key)) {
                println("[Dvx3] [DEDUP] File '%s' shares content with: %s",
                       file.get_name(), existing_index.hash_to_entries[hash_key].file_path);
                return null;
            }

            var encrypted_data = encrypt_aes_cbc(data, random_bytes(32));

            var hash_dir = Path.build_filename(backup_dest, "data", hash_key);
            if (!Directory.new_for_path(hash_dir).query_exists()) {
                Directory.new_for_path(hash_dir).make_directory_with_parents();
            }

            var target_file = File.new_for_path(Path.build_filename(hash_dir, relative_path));
            if (target_file.query_exists()) target_file.delete();
            target_file.write_bytes(encrypted_data, 0);

            backed_up_bytes += data.Length;
            return null;
        }
    }
}
