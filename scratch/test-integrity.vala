#!/usr/bin/env valac
/* -*- coding: utf-8 -*- */

using GLib;
using Dvx3;

int main(string[] args) {
    try {
        var src_dir = File.new_for_path("/tmp/test-source-big");
        if (!src_dir.query_exists()) {
            GLib.stderr.printf("Source directory not found: %s\n", src_dir.get_path());
            return 1;
        }

        var out_file = File.new_for_path("/tmp/test-backup-with-integrity.dvx3");
        var password = "testpassword123";
        
        GLib.stdout.printf("Creating encrypted archive with integrity verification...\n");
        Dvx3.encrypt(src_dir, out_file, password, null, null, EncryptionMode.WITH_INTEGRITY);
        
        var file_info = out_file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
        uint64 size = file_info.get_attribute_uint64(FileAttribute.STANDARD_SIZE);
        
        GLib.stdout.printf("✅ Backup created successfully!\n");
        GLib.stdout.printf("   Path: %s\n", out_file.get_path());
        GLib.stdout.printf("   Size: %s\n", Dvx3.format_size(size));
        
    } catch (Error e) {
        GLib.stderr.printf("❌ Error: %s\n", e.message);
        return 1;
    }
    
    return 0;
}
