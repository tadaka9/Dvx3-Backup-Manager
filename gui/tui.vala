/*
 * DVX3 Backup Manager — Terminal User Interface (TUI)
 * 
 * A GTK4-based terminal UI for creating, restoring, and managing
 * encrypted backup archives. Features progress bars, file selection,
 * codec selection, and real-time status updates.
 */

using GLib;
using Gtk;
using Dvx3;

public class DVX3TUI : Application {
    private string? current_dir = null;
    private uint64 total_size = 0;
    private uint64 processed_size = 0;
    private object? lock_obj = new object();

    public static void main(string[] args) {
        DVX3TUI app = new DVX3TUI();
        app.run(args);
    }

    public DVX3TUI() : base(application_id: "com.dvx3.backup") {
    }

    protected override void activate() {
        var window = create_main_window();
        window.present();
    }

    private Window create_main_window() {
        var window = new Window(
            title: "DVX3 Backup Manager",
            default_width: 800,
            default_height: 600
        );

        var scroll = new ScrollWindow();
        var vbox = new Box(Orientation.VERTICAL, 4);

        /* Title and description */
        var title_label = new Label("DVX3 Backup Manager v" + VERSION);
        title_label.get_style_context().add_class("title");
        vbox.pack_start(title_label, false, false, 0);

        var desc_label = new Label(
            "A secure incremental backup tool with encryption and compression.\n\n"
            + "Commands: [1] Backup | [2] Restore | [3] List Archives | [4] Exit"
        );
        vbox.pack_start(desc_label, false, false, 8);

        /* File browser section */
        var frame = new Frame("Source Files");
        var frame_box = (Box)frame.get_child();
        frame_box.set_border_width(12);

        var file_view = create_file_browser(frame_box);
        vbox.pack_start(file_view, false, true, 8);

        /* Progress bar */
        var progress_frame = new Frame("Progress");
        var progress_box = (Box)progress_frame.get_child();
        progress_box.set_border_width(12);

        var progress_bar = new ProgressBar();
        progress_bar.set_show_text(true);
        progress_bar.set_show_percentage(true);
        vbox.pack_start(progress_frame, true, false, 4);

        /* Status text */
        var status_label = new Label("Ready — select a source directory");
        status_label.get_style_context().add_class("status-text");
        vbox.pack_start(status_label, false, false, 4);

        /* Control buttons */
        var button_box = new Box(Orientation.HORIZONTAL, 8);
        var backup_btn = create_button(backup_btn_clicked, "Backup",
            "Select source and click Backup to create an encrypted archive");
        var restore_btn = create_button(restore_btn_clicked, "Restore",
            "Select a .dvx3 archive to decrypt and extract");
        var list_btn = create_button(list_btn_clicked, "List Archives",
            "Show all backup archives in the current directory");
        button_box.pack_start(backup_btn, true, false, 0);
        button_box.pack_start(restore_btn, true, false, 0);
        button_box.pack_start(list_btn, true, false, 0);

        vbox.pack_start(button_box, false, false, 8);

        /* Footer with instructions */
        var footer = new Label("Press Ctrl+C to quit");
        footer.get_style_context().add_class("footer-text");
        vbox.pack_start(footer, false, false, 16);

        window.add(scroll);
        scroll.add(vbox);
        return window;
    }

    private FileBrowser create_file_browser(Box parent) {
        var box = new Box(Orientation.HORIZONTAL, 4);

        /* Directory navigation */
        var dir_label = new Label("Current: ");
        var dir_combo = new ComboBox.new_from_model(
            new StringList() { "Source", "Backup Archives" }
        );

        var file_store = new FileStore();
        var source_entry = new Entry();
        source_entry.set_placeholder_text("Select a directory to backup");
        source_entry.set_size_request(300, -1);

        /* File tree view */
        var file_model = new FileTreeModel(File.new_for_path("."));
        var tree_view = new TreeView.with_model(file_model);
        tree_view.get_style_context().add_class("file-browser");
        tree_view.set_headers_visible(false);

        var renderer_text = (CellRendererText)tree_view.get_children()[0];
        renderer_text.get_property("expand").bind(
            file_tree_column, "expand", BindFlags.SYNC_CREATE | BindFlags.BIDIRECTIONAL);
        renderer_text.get_property("text").bind(
            file_tree_column, "text", BindFlags.SYNC_CREATE | BindFlags.BIDIRECTIONAL);

        tree_view.add_column(file_tree_column);

        box.pack_start(dir_label, false, false, 0);
        box.pack_start(source_entry, true, false, 4);

        /* File browser sidebar */
        var frame = new Frame("Files");
        var frame_box = (Box)frame.get_child();
        frame_box.set_border_width(8);

        var hbox = new Box(Orientation.HORIZONTAL, 0);
        hbox.pack_start(tree_view, true, false, 0);

        frame_box.add(hbox);
        box.pack_start(frame, true, true, 4);

        return box;
    }

    private TreeViewColumn file_tree_column = new TreeViewColumn();

    protected override void state_changed(object source, GAction? changed_action) {
        base.state_changed(source, changed_action);
    }

    /* Progress bar callbacks */
    public static void on_progress(uint64 processed, uint64 total) {
        if (total > 0) {
            var percentage = ((double)processed * 100.0 / total).round(2);
            GLib.idle_add(() => {
                // Update progress bar here
            });
        }
    }

    private void backup_btn_clicked(object? source, Variant? param) {
        var src_dir = File.new_for_path(source_entry.text);
        if (!src_dir.query_exists() || !src_dir.query_file_type(FileQueryInfoFlags.NONE).is_directory()) {
            print("Please select a valid directory.\n");
            return;
        }

        /* Create output path */
        var base_name = src_dir.get_path().get_filename();
        var backup_path = Path.build_filename(
            Environment.get_user_config_dir(), "dvx3", "backups"
        );
        File.new_for_path(Path.build_filename(backup_path, base_name + ".dvx3")).make_directory_recursive();
        var output_file = File.new_for_path(Path.build_filename(backup_path, base_name + "-$(date +%Y%m%d-%H%M%S).dvx3"));

        print("Backing up: %s\n", src_dir.get_path());
        print("Output:    %s\n", output_file.get_path());

        /* Show progress */
        var status_label = (Label)GLib.Object.get_parent(this)["status_label"];
        status_label.set_text("Encrypting and compressing...");

        try {
            ArchiveEngine.encrypt_with_codec(
                src_dir, output_file, "my-secure-password-2026", "zstd"
            );
            print("Backup completed: %s\n", output_file.get_path());
            status_label.set_text("✓ Backup successful!");
        } catch (Error e) {
            print("Backup failed: %s\n", e.message);
            status_label.set_text("✗ Backup failed: " + e.message);
        }
    }

    private void restore_btn_clicked(object? source, Variant? param) {
        /* Implement restore functionality */
        var input_file = File.new_for_path("/path/to/archive.dvx3");
        var output_dir = File.new_for_path(Environment.get_home_directory());

        try {
            ArchiveEngine.decrypt(input_file, output_dir, "my-secure-password-2026");
            print("Restore completed successfully.\n");
        } catch (Error e) {
            print("Restore failed: %s\n", e.message);
        }
    }

    private void list_btn_clicked(object? source, Variant? param) {
        var current_dir = File.new_for_path(source_entry.text);
        if (!current_dir.query_exists()) return;

        var pattern = new Regex(".*\\.dvx3$", RegexOptions.IGNORECASE | RegexOptions.CASE_INSENSITIVE);

        print("Archives in \"%s\":\n", current_dir.get_path());
        print("=============================================================\n");

        var entries = current_dir.enumerate_children(
            "standard::name,standard::type,standard::size,standard::modified"
        );

        foreach (var entry in entries) {
            if (!pattern.match(entry.get_name())) continue;

            var file = current_dir.get_child(entry.get_name());
            uint64 size = 0;
            try {
                var info = file.query_info("standard::size", FileQueryInfoFlags.NONE);
                size = info.get_size();
            } catch (Error e) {}

            string size_str = format_bytes(size);
            DateTime mtime = entry.get_modified_date_time().to_unix_timestamp() * 1000;

            print("%-45s %12s %s\n",
                entry.get_name(), size_str, datetime_to_string(mtime));
        }

        entries.close();
    }

    private Button create_button(Action? action, string label, string tooltip) {
        var button = new Button(label);
        button.set_tooltip_text(tooltip);
        if (action != null) button.clicked.connect(action);
        return button;
    }

    private static string format_bytes(uint64 bytes) {
        const uint[] units = { 1024, 1024*1024, 1024*1024*1024 };
        for (int i = 0; i < units.Length && bytes >= units[i]; i++) {
            bytes /= units[i];
        }
        return "%d%s".printf(bytes, new string[] { "B", "KB", "MB", "GB" }[i]);
    }

    private static string datetime_to_string(DateTime date_time) {
        var local = TimeZone.local;
        return "%tY/%tM/%td %tH:%tM:%tS".printf(
            date_time.year, date_time.month, date_time.day,
            date_time.hour, date_time.minute, date_time.second);
    }
}