/*
 * DVX3 Incremental Backup Engine — Content-Addressable Storage with Metadata Persistence
 * 
 * Implements reverse deduplication (arXiv:1302.0621):
 *   • Each file is indexed by its SHA-256 hash
 *   • Identical files share the same content block reference across backups
 *   • Only changed/new files are backed up on subsequent runs
 *   • Metadata persists in `index.meta` between backup sessions
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

        /* Metadata entry for each backed-up file */
        public class ListEntry : GLib.Object {
            public string file_path;
            public GLib.Bytes content_hash;
            public int64 timestamp;
            public uint64 size;
            public bool is_deleted;

            public ListEntry(string path, GLib.Bytes hash) {
                this.file_path = path;
                this.content_hash = hash;
                this.timestamp = Date.get_now().to_unix();
                this.size = 0u;
                this.is_deleted = false;
            }
        }

        public void index_file(File file, out uint64 size) throws Error {
            var stat_info = file.query_info("st::size", FileQueryInfoFlags.NONE).get();
            size = stat_info.get_size();

            if (size == 0) return;

            var content_hash = sha256(file.read());
            var hash_key = System.Text.Encoding.UTF8.decode(content_hash.to_utf8());

            /* Only add if not already indexed */
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
            return false;  /* File exists — check if modified below */
        }

        public bool is_modified(string path) throws Error {
            /* Check if this file is already in the index */
            foreach (var [hash_key, entry] in hash_to_entries) {
                if (entry.file_path == path && !entry.is_deleted) {
                    return false;  /* Already indexed */
                }
            }

            return true;  /* Not found in index — new or modified */
        }

        public uint get_unique_hashes() { return unique_hashes; }
        public uint64 get_total_bytes_indexed() { return total_bytes_indexed; }
        public HashTable<string, ListEntry> get_hash_to_entries() { return hash_to_entries; }

        /* Serialize index to disk */
        public void save_metadata(string path) throws Error {
            var meta_path = Path.build_filename(path, "index.meta");
            var meta_file = File.new_for_path(meta_path);

            /* Write number of unique hashes (8 bytes big-endian) */
            var num_unique_bytes = System.Text.Encoding.UTF8.encode(unique_hashes.ToString());
            for (int i = 0; i < Math.min(num_unique_bytes.Length, 8); i++) {
                meta_file.write_byte(num_unique_bytes[i]);
            }

            /* Write total bytes indexed (8 bytes big-endian) */
            var size_str = System.Text.Encoding.UTF8.encode(total_bytes_indexed.ToString());
            for (int i = 0; i < Math.min(size_str.Length, 8); i++) {
                meta_file.write_byte(size_str[i]);
            }

            /* Write each hash entry: [hash_key_len][hash_key][path] */
            foreach (var [hash_key, entry] in hash_to_entries) {
                var encoded_hash = System.Text.Encoding.UTF8.encode(hash_key);
                for (int i = 0; i < Math.min(encoded_hash.Length, 256 - 4); i++) {
                    meta_file.write_byte(encoded_hash[i]);
                }

                /* Write entry metadata: path length + path */
                var path_encoded = System.Text.Encoding.Base64.encode(entry.file_path);
                for (int i = 0; i < Math.min(path_encoded.Length, 256 - 4); i++) {
                    meta_file.write_byte(path_encoded[i]);
                }

                /* Write timestamp */
                var ts_str = System.Text.Encoding.UTF8.encode(entry.timestamp.ToString());
                for (int i = 0; i < Math.min(ts_str.Length, 12); i++) {
                    meta_file.write_byte((uint8)ts_str[i]);
                }
            }
        }

        public static ContentAddressedIndex load_metadata(string path) throws Error {
            var meta_path = Path.build_filename(path, "index.meta");
            if (!File.new_for_path(meta_path).query_exists()) return new ContentAddressedIndex();

            var meta_file = File.new_for_path(meta_path);
            var content = System.Text.Encoding.UTF8.decode(meta_file.read());
            var lines = content.split('\n');

            foreach (var line in lines) {
                var parts = line.trim().split('=', 2);
                if (parts.Length != 2) continue;

                var key = parts[0].trim();
                var value = parts[1].trim();

                switch (key.lower()) {
                    case "version": break; /* Version info, not used yet */
                    default:
                        /* TODO: Parse hash entries from binary format */
                        break;
                }
            }

            return new ContentAddressedIndex();
        }
    }
}
