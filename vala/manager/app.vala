using GLib;
private void help () {
    print ("Usage: backup-manager [--config-dir DIR] COMMAND\n" +
           "  add NAME SOURCE DESTINATION [CODEC] [RETENTION_DAYS]\n" +
           "  list | status | history | remove NAME | run NAME | cleanup\n" +
           "  restore ARCHIVE EMPTY_DIRECTORY\n" +
           "Set DVX3_PASSWORD for run/restore. Passwords are never persisted.\n");
}
private string password () throws Error {
    var value = Environment.get_variable ("DVX3_PASSWORD");
    if (value == null || value == "") throw new IOError.INVALID_ARGUMENT ("Set DVX3_PASSWORD for this operation");
    return value;
}
int main (string[] args) {
    try {
        if (args.length == 2 && args[1] == "--version") { print ("backup-manager %s\n", Dvx3.VERSION); return 0; }
        if (args.length == 2 && args[1] == "--help") { help (); return 0; }
        string? dir = null;
        int offset = 1;
        if (args.length > 1 && args[1] == "--config-dir") {
            if (args.length < 4) { help (); return 1; }
            dir = args[2]; offset = 3;
        }
        var manager = new Dvx3.BackupManager (dir);
        bool interactive = args.length == offset;
        do {
            string[] command = {};
            if (interactive) {
                print ("\nCommands: list, add, remove, run, history, cleanup, restore, exit\nUse quoted paths with spaces.\ndvx3> ");
                var line = stdin.read_line ();
                if (line == null || line.strip () == "exit") return 0;
                Shell.parse_argv (line, out command);
            } else for (int i = offset; i < args.length; i++) command += args[i];
            if (command.length == 0) continue;
            switch (command[0]) {
                case "list": case "status":
                    foreach (var name in manager.list_jobs ()) print ("%s\n", manager.job_details (name)); break;
                case "history":
                    foreach (var id in manager.list_history ()) print ("%s\n", manager.history_details (id)); break;
                case "add":
                    if (command.length < 4 || command.length > 6) { help (); return 1; }
                    int days = 30;
                    if (command.length > 5 && !int.try_parse (command[5], out days)) throw new IOError.INVALID_ARGUMENT ("Invalid retention days");
                    manager.add_job (command[1], command[2], command[3], command.length > 4 ? command[4] : "zstd", days); break;
                case "remove":
                    if (command.length != 2) { help (); return 1; }
                    manager.remove_job (command[1]); break;
                case "run":
                    if (command.length != 2) { help (); return 1; }
                    print ("%s\n", manager.run_backup (command[1], password ())); break;
                case "restore":
                    if (command.length != 3) { help (); return 1; }
                    Dvx3.decrypt (File.new_for_commandline_arg (command[1]), File.new_for_commandline_arg (command[2]), password ()); break;
                case "cleanup": manager.cleanup (); break;
                default: help (); return 1;
            }
        } while (interactive);
        return 0;
    } catch (Error e) { stderr.printf ("%s\n", e.message); return 1; }
}
