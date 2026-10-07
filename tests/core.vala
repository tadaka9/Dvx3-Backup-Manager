using GLib;
private File root;
private void delete_tree (File file) throws Error {
    if (file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.DIRECTORY) {
        var enumerator = file.enumerate_children ("standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        FileInfo? info;
        while ((info = enumerator.next_file ()) != null) delete_tree (file.get_child (info.get_name ()));
        enumerator.close ();
    }
    file.delete ();
}
private void roundtrip (string codec) {
    try {
        var src = root.get_child ("source " + codec);
        src.make_directory ();
        src.get_child ("nested").make_directory ();
        FileUtils.set_contents (src.get_child ("nested").get_child ("hello ' ü.txt").get_path (), "Exact bytes\n");
        FileUtils.set_contents (src.get_child (".hidden").get_path (), "hidden data");
        // More than two chunks, with an incomplete final chunk; deterministic byte content.
        var large = new uint8[2200003];
        // Incompressible input exercises simultaneous stdin/stdout beyond pipe
        // capacity, rather than letting a tiny compressed result hide deadlocks.
        uint32 state = 0x12345678;
        for (int i = 0; i < large.length; i++) {
            state ^= state << 13; state ^= state >> 17; state ^= state << 5;
            large[i] = (uint8)state;
        }
        src.get_child ("binary").replace_contents (large, null, false, FileCreateFlags.PRIVATE, null);
        var archive = root.get_child (codec + ".dvx3");
        Dvx3.encrypt_with_codec (src, archive, "test password", codec);
        var dst = root.get_child ("restored " + codec);
        Dvx3.decrypt (archive, dst, "test password");
        uint8[] restored;
        dst.get_child ("binary").load_contents (null, out restored, null);
        assert (restored.length == large.length);
        for (int i = 0; i < large.length; i++) assert (large[i] == restored[i]);
        string text;
        FileUtils.get_contents (dst.get_child ("nested").get_child ("hello ' ü.txt").get_path (), out text);
        assert (text == "Exact bytes\n");
        assert (dst.get_child (".hidden").query_exists ());
    } catch (Error e) { error ("%s: %s", codec, e.message); }
}
private void failures () {
    try {
        var archive = root.get_child ("zstd.dvx3");
        var dst = root.get_child ("failed restore");
        bool rejected = false;
        try { Dvx3.decrypt (archive, dst, "wrong password"); }
        catch (Error e) { rejected = true; }
        assert (rejected && !dst.query_exists ());
        uint8[] header_damage;
        archive.load_contents (null, out header_damage, null);
        // Mutate authenticated metadata without damaging the chunk ciphertext.
        for (int i = 4; i < 516 - 4; i++) {
            if (header_damage[i] == 'z' && header_damage[i+1] == 's' && header_damage[i+2] == 't' && header_damage[i+3] == 'd') {
                header_damage[i] = 'g'; header_damage[i+1] = 'z'; header_damage[i+2] = 'i'; header_damage[i+3] = 'p'; break;
            }
        }
        var modified = root.get_child ("header-tamper.dvx3");
        modified.replace_contents (header_damage, null, false, FileCreateFlags.PRIVATE, null);
        rejected = false;
        try { Dvx3.decrypt (modified, dst, "test password"); }
        catch (Error e) { rejected = true; }
        assert (rejected && !dst.query_exists ());
        uint8[] bytes;
        archive.load_contents (null, out bytes, null);
        bytes[bytes.length - 1] ^= 1;
        var damaged = root.get_child ("damaged.dvx3");
        damaged.replace_contents (bytes, null, false, FileCreateFlags.PRIVATE, null);
        rejected = false;
        try { Dvx3.decrypt (damaged, dst, "test password"); }
        catch (Error e) { rejected = true; }
        assert (rejected && !dst.query_exists ());
        damaged.replace_contents (bytes[0:20], null, false, FileCreateFlags.PRIVATE, null);
        rejected = false;
        try { Dvx3.decrypt (damaged, dst, "test password"); }
        catch (Error e) { rejected = true; }
        assert (rejected);
        var src = root.get_child ("source zstd");
        var existing = root.get_child ("preserve-existing.dvx3");
        FileUtils.set_contents (existing.get_path (), "original");
        var tool_dir = root.get_child ("failing-tools"); tool_dir.make_directory ();
        var old_path = Environment.get_variable ("PATH");
        Environment.set_variable ("PATH", tool_dir.get_path (), true);
        rejected = false;
        try { Dvx3.encrypt (src, existing, "test password"); }
        catch (Error e) { rejected = true; }
        Environment.set_variable ("PATH", old_path, true);
        assert (rejected);
        string value; FileUtils.get_contents (existing.get_path (), out value); assert (value == "original");
        rejected = false;
        try { Dvx3.encrypt_with_codec (src, existing, "test password", "unregistered-codec"); }
        catch (Error e) { rejected = true; }
        assert (rejected);
        var profiles = new KeyFile ();
        var profile_path = Environment.get_variable ("DVX3_CODECS");
        profiles.load_from_file (profile_path, KeyFileFlags.NONE);
        profiles.set_string_list ("failed-backend", "compress", { "false" });
        profiles.set_string_list ("failed-backend", "decompress", { "false" });
        profiles.save_to_file (profile_path);
        rejected = false;
        try { Dvx3.encrypt_with_codec (src, existing, "test password", "failed-backend"); }
        catch (Error e) { rejected = true; }
        assert (rejected);
        FileUtils.get_contents (existing.get_path (), out value); assert (value == "original");
        profiles.remove_group ("failed-backend"); profiles.save_to_file (profile_path);
        var entries = root.enumerate_children ("standard::name", FileQueryInfoFlags.NONE);
        FileInfo? info;
        while ((info = entries.next_file ()) != null) assert (!info.get_name ().has_suffix (".partial"));
        entries.close ();
    } catch (Error e) { error ("failure test: %s", e.message); }
}
private void manager_test () {
    try {
        var src = root.get_child ("manager source"); src.make_directory ();
        FileUtils.set_contents (src.get_child ("data").get_path (), "manager data");
        var dst = src.get_child ("backups");
        var cfg = root.get_child ("config");
        var manager = new Dvx3.BackupManager (cfg.get_path ());
        manager.add_job ("job with spaces", src.get_path (), dst.get_path (), "gzip", 1);
        var archive = File.new_for_path (manager.run_backup ("job with spaces", "test password"));
        var restored = root.get_child ("manager restore");
        Dvx3.decrypt (archive, restored, "test password");
        assert (restored.get_child ("data").query_exists ());
        assert (!restored.get_child ("backups").query_exists ());
        var reload = new Dvx3.BackupManager (cfg.get_path ());
        assert (reload.list_jobs ().length == 1 && reload.list_history ().length == 1);
        // Age the record to exercise retention using the persisted configuration interface.
        var records = new KeyFile ();
        records.load_from_file (cfg.get_child ("history.ini").get_path (), KeyFileFlags.NONE);
        records.set_int64 (records.get_groups ()[0], "timestamp", 1);
        records.save_to_file (cfg.get_child ("history.ini").get_path ());
        var aged = new Dvx3.BackupManager (cfg.get_path ()); aged.cleanup ();
        assert (!archive.query_exists ());
        assert (aged.list_history ().length == 0);
        aged.remove_job ("job with spaces");
        assert (aged.list_jobs ().length == 0);
    } catch (Error e) { error ("manager: %s", e.message); }
}
private void legacy_test () {
    try {
        var src = root.get_child ("source zstd");
        var archive = root.get_child ("legacy.dvx3");
        Dvx3.encrypt (src, archive, "test password", null, null, Dvx3.EncryptionMode.WITHOUT_INTEGRITY);
        // Model an old header without codec/version; framing and encrypted payload stay identical.
        uint8[] bytes; archive.load_contents (null, out bytes, null);
        var parser = new Json.Parser (); parser.load_from_data ((string)bytes[4:516]);
        var hdr = parser.get_root ().get_object (); hdr.remove_member ("codec"); hdr.remove_member ("version"); hdr.remove_member ("header_mac");
        var generator = new Json.Generator (); generator.set_root (parser.get_root ());
        var json = generator.to_data (null);
        for (int i = 0; i < 512; i++) bytes[4+i] = i < json.length ? json[i] : 0;
        archive.replace_contents (bytes, null, false, FileCreateFlags.PRIVATE, null);
        Dvx3.decrypt (archive, root.get_child ("legacy restore"), "test password");
    } catch (Error e) { error ("legacy: %s", e.message); }
}
int main (string[] args) {
    Test.init (ref args);
    try {
        root = File.new_for_path (DirUtils.make_tmp ("dvx3 tests-XXXXXX"));
        var profiles = root.get_child ("codecs.ini");
        FileUtils.set_contents (profiles.get_path (), "[dense-test]\npipeline=xz;zstd;\n[direct-test]\ncompress=cp;{input};{output};\ndecompress=cp;{input};{output};\n[cycle-test]\npipeline=cycle-test;\n");
        Environment.set_variable ("DVX3_CODECS", profiles.get_path (), true);
        assert (!Dvx3.codec_available ("cycle-test"));
        var required = Environment.get_variable ("DVX3_REQUIRE_CODECS");
        if (required != null) foreach (var codec in required.split (","))
            if (!Dvx3.codec_available (codec)) throw new IOError.NOT_FOUND ("Required test codec unavailable: %s", codec);
        foreach (var codec in Dvx3.codec_names ()) {
            if (!Dvx3.codec_available (codec)) { print ("SKIP codec %s: missing executable/adapter\n", codec); continue; }
            var selected = codec;
            Test.add_data_func ("/roundtrip/" + selected, () => roundtrip (selected));
        }
        Test.add_func ("/core/failures", failures);
        Test.add_func ("/core/legacy", legacy_test);
        Test.add_func ("/manager/exclusion-persistence-retention", manager_test);
        int result = Test.run ();
        delete_tree (root);
        return result;
    } catch (Error e) { stderr.printf ("%s\n", e.message); return 1; }
}
