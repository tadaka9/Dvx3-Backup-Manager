# Vala backup manager

Build with `./build.sh manager`; run `build/bin/backup-manager --help`.

```sh
build/bin/backup-manager add 'Documents' ./documents ./backups zpaq 30
build/bin/backup-manager list
DVX3_PASSWORD='password' build/bin/backup-manager run 'Documents'
build/bin/backup-manager history
build/bin/backup-manager cleanup
DVX3_PASSWORD='password' build/bin/backup-manager restore ./backup.dvx3 ./empty-restore
build/bin/backup-manager remove 'Documents'
```

`add NAME SOURCE DESTINATION [CODEC] [RETENTION_DAYS]` creates a job, validates the
source, rejects duplicate names and records absolute paths. Defaults: zstd,
30 days. Zero retention means keep forever. Paths/names containing spaces must
be quoted. Destinations below the source are excluded completely from the archive.
Passwords are supplied per operation through `DVX3_PASSWORD`, never persisted.

`list` and `status` show configured jobs. `history` shows successful and failed
operations. `cleanup` removes expired, manager-owned UUID-named backups in their
recorded job directory. Files outside that directory are never a retention target.
Removing a job preserves its existing archives and history.

Run without arguments for the same commands at an interactive prompt; `exit` or
EOF closes it. Scheduling and terminal password input are not implemented.

## Configuration and migration

GLib selects the native user configuration directory (XDG on Linux, native GLib
platform convention on macOS/Windows), under `dvx3/`. Files are `jobs.ini` and
`history.ini`, written privately. `--config-dir DIR` overrides the location:

```sh
build/bin/backup-manager --config-dir ./test-config list
```

Legacy C++ `backup-manager.conf` / `backup-history.log` are left intact and not
silently imported: their repeated `[job]` and whitespace-separated formats lose
information for names/paths containing spaces and may contain plaintext passwords.
Recreate each old job with `add`, retain the old history for reference, and supply
its original password to restore existing valid archives. The new manager does
not persist those passwords or claim compatibility with the old configuration API.
See [ARCHITECTURE.md](ARCHITECTURE.md) for legacy archive compatibility.
