using GLib;
namespace Dvx3 {
    /** Job persistence and retention are core services, independent of any frontend. */
    public class BackupManager : Object {
        private KeyFile jobs = new KeyFile ();
        private KeyFile records = new KeyFile ();
        private File config;
        private File history_file;
        public BackupManager (string? config_dir = null) throws Error {
            var dir = File.new_for_path (config_dir ?? Path.build_filename (Environment.get_user_config_dir (), "dvx3"));
            if (!dir.query_exists ()) dir.make_directory_with_parents ();
            config = dir.get_child ("jobs.ini");
            history_file = dir.get_child ("history.ini");
            if (config.query_exists ()) jobs.load_from_file (config.get_path (), KeyFileFlags.NONE);
            if (history_file.query_exists ()) records.load_from_file (history_file.get_path (), KeyFileFlags.NONE);
        }
        private void save (KeyFile key, File file) throws Error {
            var data = key.to_data ();
            file.replace_contents (data.data, null, false, FileCreateFlags.PRIVATE, null);
        }
        public string[] list_jobs () { return jobs.get_groups (); }
        public string[] list_history () { return records.get_groups (); }
        public string job_details (string name) throws Error {
            return "%s: %s -> %s [%s]".printf (name, jobs.get_string (name, "source"),
                jobs.get_string (name, "destination"), jobs.get_string (name, "codec"));
        }
        public string history_details (string id) throws Error {
            return "%s: %s %s %s".printf (id, records.get_string (id, "job"),
                records.get_boolean (id, "success") ? "success" : "failed", records.get_string (id, "message"));
        }
        public void add_job (string name, string source, string destination, string codec = "zstd", int retention_days = 30) throws Error {
            if (name == "" || name.contains ("[") || name.contains ("]") || name.contains ("\n") || name.contains ("\r"))
                throw new IOError.INVALID_ARGUMENT ("Invalid job name");
            if (jobs.has_group (name)) throw new IOError.EXISTS ("Job already exists: %s", name);
            if (retention_days < 0) throw new IOError.INVALID_ARGUMENT ("Retention must be nonnegative");
            if (!codec_available (codec)) throw new IOError.NOT_SUPPORTED ("Codec unavailable: %s", codec);
            var src = File.new_for_commandline_arg (source);
            var dst = File.new_for_commandline_arg (destination);
            if (src.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS) != FileType.DIRECTORY)
                throw new IOError.NOT_DIRECTORY ("Source must be a directory");
            if (dst.equal (src) || src.has_prefix (dst)) throw new IOError.INVALID_ARGUMENT ("Destination cannot be the source or its ancestor");
            jobs.set_string (name, "source", src.get_path ());
            jobs.set_string (name, "destination", dst.get_path ());
            jobs.set_string (name, "codec", codec);
            jobs.set_integer (name, "retention_days", retention_days);
            jobs.set_boolean (name, "enabled", true);
            jobs.set_int64 (name, "last_backup", 0);
            save (jobs, config);
        }
        public void remove_job (string name) throws Error {
            if (!jobs.has_group (name)) throw new IOError.NOT_FOUND ("Job not found: %s", name);
            jobs.remove_group (name); save (jobs, config);
        }
        public string run_backup (string name, string password, ProgressCallback? progress = null) throws Error {
            if (!jobs.get_boolean (name, "enabled")) throw new IOError.FAILED ("Job is disabled: %s", name);
            var src = File.new_for_path (jobs.get_string (name, "source"));
            var dst = File.new_for_path (jobs.get_string (name, "destination"));
            if (!dst.query_exists ()) dst.make_directory_with_parents ();
            var now = new DateTime.now_utc ();
            var id = Uuid.string_random ();
            var archive = dst.get_child ("dvx3-" + now.format ("%Y%m%dT%H%M%SZ") + "-" + id + ".dvx3");
            records.set_string (id, "job", name);
            records.set_int64 (id, "timestamp", now.to_unix ());
            records.set_string (id, "archive", archive.get_path ());
            try {
                encrypt_with_codec (src, archive, password, jobs.get_string (name, "codec"),
                    dst.has_prefix (src) ? dst.get_path () : null, progress);
                jobs.set_int64 (name, "last_backup", now.to_unix ());
                save (jobs, config);
                records.set_boolean (id, "success", true);
                records.set_string (id, "message", archive.get_path ());
                save (records, history_file);
                return archive.get_path ();
            } catch (Error e) {
                records.set_boolean (id, "success", false);
                records.set_string (id, "message", e.message);
                save (records, history_file);
                throw e;
            }
        }
        public void cleanup () throws Error {
            int64 now = new DateTime.now_utc ().to_unix ();
            foreach (var id in records.get_groups ()) {
                var job = records.get_string (id, "job");
                if (!jobs.has_group (job) || !records.get_boolean (id, "success")) continue;
                int days = jobs.get_integer (job, "retention_days");
                if (days == 0 || records.get_int64 (id, "timestamp") >= now - (int64)days * 86400) continue;
                var archive = File.new_for_path (records.get_string (id, "archive"));
                var dst = File.new_for_path (jobs.get_string (job, "destination"));
                // Delete only manager-owned archives in the recorded job directory.
                if (!archive.get_parent ().equal (dst) || !archive.get_basename ().has_prefix ("dvx3-") ||
                    !archive.get_basename ().has_suffix ("-" + id + ".dvx3"))
                    throw new IOError.INVALID_DATA ("Unsafe history path: %s", archive.get_path ());
                if (archive.query_exists ()) archive.delete ();
                records.remove_group (id);
            }
            save (records, history_file);
        }
    }
}
