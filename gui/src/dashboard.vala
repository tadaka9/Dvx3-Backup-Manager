/* -*- coding: utf-8 -*- */

/**
 * Dvx3 Backup Manager - GTK4 Desktop Application
 * 
 * A beautiful, practical GUI for backup and restore operations
 * with comprehensive management features.
 */

using GLib;
using Gtk;
using Gdk;

namespace Dvx3 {

    /**
     * Main application window with all backup manager functionality
     */
    public class BackupManagerWindow : Window {
        private Box? main_box;
        private Box? sidebar;
        private Box? content_area;
        
        private Notebook? notebook;
        private Stack? stack;
        
        private Label? status_label;
        private Label? progress_label;
        
        /* Dashboard widgets */
        private Box? dashboard_header;
        private Label? dashboard_title;
        
        private ScrollArea? backup_list_view;
        private Gtk.FlowBox? backup_jobs_box;
        
        private StackPage? dashboard_page;
        private StackPage? jobs_page;
        private StackPage? restore_page;
        private StackPage? settings_page;
        
        /* Progress bar */
        private ProgressBar? progress_bar;
        private Box? progress_container;
        
        public BackupManagerWindow() {
            var builder = new Gtk.Builder();
            
            // Add GTK4 bindings for JSON-GLib and libsodium
            builder.add_from_file("src/dashboard.ui");
            builder.connect_object("main-window", "window", this);
            
            /* Create main window */
            setup_window();
            setup_sidebar();
            setup_content_area();
            setup_dashboard();
            setup_jobs_panel();
            setup_restore_panel();
            setup_settings_panel();
            setup_progress_display();
            
            builder.connect_object("stack", "stack", stack);
            
            /* Apply application styling */
            apply_theme();
            
            /* Add connection to main window destruction */
            connect("destroy", () => {
                GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
                    Gtk.Application.quit();
                    return false;
                });
                return true;
            });
        }

        private void setup_window() {
            var application = new Gtk.Application("com.dvx3.BackupManager", Gtk.ApplicationFlags.SOME_FLAGS);
            
            var window = new Window(application) {
                default_width = 1200,
                default_height = 800,
                title = "Dvx3 Backup Manager"
            };

            /* Create main box */
            main_box = new Box(Gtk.Orientation.VERTICAL, 6);
            
            /* Create header bar */
            var header_bar = HeaderBar.new();
            window.set_titlebar(header_bar);
            
            /* Add menu button */
            var menu_button = Button.new_with_label("≡");
            header_bar.pack_start(menu_button);
            
            /* Add application title */
            var title_label = new Label("Dvx3 Backup Manager") {
                halign = Gtk.Align.CENTER,
                use_markup = true
            };
            header_bar.set_title(title_label);
            
            /* Add help button */
            var help_button = Button.new_with_label("?");
            header_bar.pack_end(help_button);
            
            /* Set up main box */
            main_box.add(header_bar);
            
            /* Create sidebar */
            sidebar = new Box(Gtk.Orientation.VERTICAL, 6);
            sidebar.halign = Gtk.Align.START;
            sidebar.vexpand = false;
            sidebar.min_width_chars = 80;
            
            /* Add notebook for navigation */
            notebook = new Notebook();
            
            /* Create pages */
            dashboard_page = create_dashboard_page();
            jobs_page = create_jobs_page();
            restore_page = create_restore_page();
            settings_page = create_settings_page();
            
            /* Add pages to notebook */
            notebook.append_page(dashboard_page, "Dashboard");
            notebook.append_page(jobs_page, "Jobs");
            notebook.append_page(restore_page, "Restore");
            notebook.append_page(settings_page, "Settings");
            
            /* Style notebook tabs */
            notebook.set_tab_fill(false);
            notebook.set_scrollable(true);
            
            /* Add notebook to sidebar */
            sidebar.add(notebook);
            
            /* Create bottom box with status and progress */
            var bottom_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            bottom_box.halign = Gtk.Align.START;
            bottom_box.vexpand = false;
            
            /* Create progress container */
            progress_container = new Box(Gtk.Orientation.VERTICAL, 0);
            progress_container.valign = Gtk.Align.START;
            progress_container.margin_start = 10;
            progress_container.margin_end = 10;
            
            /* Add progress bar */
            progress_bar = ProgressBar.new();
            progress_bar.show_fraction = false;
            progress_bar.vexpand = true;
            progress_bar.halign = Gtk.Align.CENTER;
            
            progress_container.add(progress_bar);
            
            /* Add status label */
            status_label = new Label("Ready") {
                halign = Gtk.Align.CENTER,
                use_markup = true
            };
            
            progress_container.add(status_label);
            
            /* Add progress text label */
            progress_label = new Label("") {
                halign = Gtk.Align.CENTER,
                use_markup = true,
                wrap = true
            };
            progress_label.set_line_wrap(true);
            progress_label.max_width_chars = 40;
            
            progress_container.add(progress_label);
            
            /* Add to bottom box */
            bottom_box.add(progress_container);
            
            main_box.add(sidebar);
            main_box.add(bottom_box);
            
            window.set_child(main_box);
            application.run(window);
        }

        private StackPage create_dashboard_page() {
            var page = new StackPage();
            page.child = new Box(Gtk.Orientation.VERTICAL, 6);
            
            /* Create dashboard header */
            var header_frame = Frame.new_with_label("Dashboard");
            header_frame.set_margin_top(10);
            header_frame.set_margin_bottom(10);
            
            var header_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            header_frame.child = header_box;
            
            /* Add dashboard title */
            dashboard_title = new Label("Backup Dashboard") {
                halign = Gtk.Align.START
            };
            
            /* Create stats box */
            var stats_box = new Box(Gtk.Orientation.VERTICAL, 8);
            
            /* Last backup info */
            var last_backup_frame = Frame.new_with_label("Last Backup");
            last_backup_frame.set_margin_start(0);
            
            var last_backup_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            last_backup_frame.child = last_backup_box;
            
            var last_icon = Image.new_from_icon_name("folder-open-symbolic", Gtk.IconSize.MENU);
            var last_label = new Label("No backup yet") {
                halign = Gtk.Align.START,
                wrap = true
            };
            last_label.set_lines(2);
            
            last_backup_box.add(last_icon);
            last_backup_box.add(new LabelSeparator(Gtk.Orientation.VERTICAL));
            last_backup_box.add(last_label);
            
            stats_box.add(last_backup_frame);
            
            /* Backup size */
            var size_frame = Frame.new_with_label("Backup Size");
            var size_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            
            var size_icon = Image.new_from_icon_name("file-symbolic", Gtk.IconSize.MENU);
            var size_label = new Label("0 MB") {
                halign = Gtk.Align.START,
                wrap = true
            };
            size_box.add(size_icon);
            size_box.add(new LabelSeparator(Gtk.Orientation.VERTICAL));
            size_box.add(size_label);
            
            stats_box.add(size_frame);
            
            /* Encryption status */
            var enc_frame = Frame.new_with_label("Encryption");
            var enc_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            
            var enc_icon = Image.new_from_icon_name("lock-symbolic", Gtk.IconSize.MENU);
            var enc_label = new Label("Disabled") {
                halign = Gtk.Align.START,
                use_markup = true
            };
            enc_label.set_markup("<span color='red' foreground='normal'>Not enabled</span>");
            
            enc_box.add(enc_icon);
            enc_box.add(new LabelSeparator(Gtk.Orientation.VERTICAL));
            enc_box.add(enc_label);
            
            stats_box.add(enc_frame);
            
            /* Create list view for recent backups */
            var list_view = new FlowBox();
            list_view.set_min_children_per_line(1);
            list_view.set_max_children_per_line(2);
            list_view.set_margin_start(10);
            list_view.set_margin_end(10);
            
            page.child.add(header_frame);
            page.child.add(stats_box);
            page.child.add(list_view);
            
            return page;
        }

        private StackPage create_jobs_page() {
            var page = new StackPage();
            page.child = new Box(Gtk.Orientation.VERTICAL, 6);
            
            /* Create jobs header */
            var jobs_header = Frame.new_with_label("Backup Jobs");
            jobs_header.set_margin_top(10);
            jobs_header.set_margin_bottom(10);
            
            var jobs_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            jobs_header.child = jobs_box;
            
            /* Add search entry */
            var search_entry = Entry.new();
            search_entry.set_placeholder_text("Search jobs...");
            search_entry.set_hexpand(true);
            
            var add_button = Button.new_from_icon_name("list-add-symbolic", Gtk.IconSize.BUTTON);
            add_button.clicked.connect(() => {
                // Show new backup dialog
            });
            
            /* Create job list */
            var job_list_box = new Box(Gtk.Orientation.VERTICAL, 4);
            job_list_box.set_margin_start(10);
            job_list_box.set_margin_end(10);
            
            page.child.add(jobs_header);
            page.child.add(job_list_box);
            
            return page;
        }

        private StackPage create_restore_page() {
            var page = new StackPage();
            page.child = new Box(Gtk.Orientation.VERTICAL, 6);
            
            /* Create restore header */
            var restore_header = Frame.new_with_label("Restore");
            restore_header.set_margin_top(10);
            restore_header.set_margin_bottom(10);
            
            var restore_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            restore_header.child = restore_box;
            
            /* Add restore info label */
            var restore_info = Label.new("Select a backup file to restore from");
            restore_info.set_halign(Gtk.Align.START);
            
            restore_box.add(new IconView()); // Placeholder
            
            page.child.add(restore_header);
            
            return page;
        }

        private StackPage create_settings_page() {
            var page = new StackPage();
            page.child = new Box(Gtk.Orientation.VERTICAL, 6);
            
            /* Create settings header */
            var settings_header = Frame.new_with_label("Settings");
            settings_header.set_margin_top(10);
            settings_header.set_margin_bottom(10);
            
            var settings_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            settings_header.child = settings_box;
            
            /* Add settings entries */
            var password_entry = Entry.new();
            password_entry.set_placeholder_text("Encryption Password");
            password_entry.set_hexpand(true);
            
            var retention_combo = ComboBoxText.new();
            var options = new ListStore(typeof(string));
            options.add("1 week");
            options.add("1 month");
            options.add("3 months");
            options.add("6 months");
            options.add("1 year");
            retention_combo.set_model(options);
            
            settings_box.add(new Label("Password:"));
            settings_box.add(password_entry);
            settings_box.add(new LabelSeparator(Gtk.Orientation.VERTICAL));
            settings_box.add(new Label("Retention:"));
            settings_box.add(retention_combo);
            
            var encrypt_check = CheckButton.new("Enable encryption");
            encrypt_check.active = false;
            settings_box.add(encrypt_check);
            
            page.child.add(settings_header);
            
            return page;
        }

        private void setup_sidebar() {
            /* Sidebar already created in setup_window */
        }

        private void setup_content_area() {
            /* Content area is the notebook */
        }

        private void setup_dashboard() {
            /* Dashboard widgets created in create_dashboard_page */
        }

        private void setup_jobs_panel() {
            /* Jobs panel created in create_jobs_page */
        }

        private void setup_restore_panel() {
            /* Restore panel created in create_restore_page */
        }

        private void setup_settings_panel() {
            /* Settings panel created in create_settings_page */
        }

        private void setup_progress_display() {
            /* Progress display components already created */
        }

        private void apply_theme() {
            var screen = Gdk.Display.get_default().get_default_screen();
            if (screen != null && screen.n_color_schemes > 0) {
                var color_scheme = screen.get_color_scheme(2); // System default
                color_scheme.apply_to_widget(main_box);
            }
        }

        public string get_status() {
            return status_label.label_text;
        }

        public void set_status(string message) {
            status_label.label_text = message;
            status_label.set_markup($"<span foreground='normal'>{message}</span>");
        }

        public void set_progress(double fraction, string description) {
            progress_bar.fraction = fraction;
            progress_bar.pulse = false;
            
            if (!string.IsNullOrEmpty(description)) {
                progress_label.label_text = description;
            }
        }

        public void complete() {
            progress_bar.fraction = 1.0;
            progress_bar.pulse = true;
            progress_label.label_text = "Operation completed successfully";
            set_status("Ready");
        }
    }

    /**
     * Backup creation dialog with modern GTK4 styling
     */
    public class BackupDialog : Gtk.Dialog {
        private Label? size_label;
        
        public BackupDialog(Gtk.Window parent) : base(
            new DialogFlags(
                DialogFlags.MODAL |
                DialogFlags.DESTROY_WITH_PARENT |
                DialogFlags.APPLICATION_MODAL
            ),
            "Create Backup",
            400,
            500
        ) {
            this.set_transient_for(parent);
            setup_ui();
        }

        private void setup_ui() {
            var content = new Box(Gtk.Orientation.VERTICAL, 12);
            set_child(content);
            
            /* Title */
            var title_label = new Label("Create New Backup") {
                use_markup = true
            };
            title_label.set_markup("<h1>Create Backup</h1>");
            content.add(title_label);
            
            /* Source directory selection */
            var source_frame = Frame.new_with_label("Source Directory:");
            var source_box = new Box(Gtk.Orientation.HORIZONTAL, 6);
            source_frame.child = source_box;
            
            var source_entry = Entry.new();
            source_entry.set_placeholder_text("/path/to/source");
            source_entry.set_hexpand(true);
            
            var browse_button = Button.new_from_icon_name("document-open-symbolic", Gtk.IconSize.BUTTON);
            
            source_box.add(source_entry);
            source_box.add(new LabelSeparator(Gtk.Orientation.VERTICAL));
            source_box.add(browse_button);
            
            content.add(source_frame);
            
            /* Size label */
            size_label = new Label("");
            content.add(size_label);
            
            /* Exclusion options */
            var exclude_check = CheckButton.new("Exclude files:");
            content.add(exclude_check);
            
            var exclude_entry = Entry.new();
            exclude_entry.set_placeholder_text("/path/to/exclude");
            exclude_entry.set_sensitive(false);
            content.add(exclude_entry);
            
            /* Encryption option */
            var encrypt_check = CheckButton.new("Encrypt backup:");
            content.add(encrypt_check);
            
            var password_label = Label.new("");
            password_label.set_margin_top(4);
            content.add(password_label);
            
            var password_entry = Entry.new();
            password_entry.set_placeholder_text("Enter password (min 8 characters)");
            password_entry.set_hexpand(true);
            content.add(password_entry);
            
            /* Progress bar */
            var progress_box = new Box(Gtk.Orientation.HORIZONTAL, 0);
            progress_box.halign = Gtk.Align.CENTER;
            
            var progress_bar = ProgressBar.new();
            progress_bar.show_fraction = false;
            
            var cancel_button = Button.new_with_label("Cancel");
            
            progress_box.add(progress_bar);
            progress_box.add(cancel_button);
            content.add(progress_box);
            
            /* Completion message */
            var completion_label = Label.new("Backup created successfully!") {
                halign = Gtk.Align.CENTER,
                wrap = true
            };
            content.add(completion_label);
        }
    }

} // namespace Dvx3
<EOF>