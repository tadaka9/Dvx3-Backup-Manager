# Backup Manager - Quick Start Guide

A comprehensive backup management system using the dvx3 encryption library.

## Installation

### Quick Install (System-wide)
```bash
sudo ./install.sh
```

### User Install (No root required)
```bash
PREFIX=~/.local ./install.sh
export PATH="$HOME/.local/bin:$PATH"
```

### Standalone Use
```bash
./build_backup_manager.sh
./backup-manager
```

See [INSTALL.md](INSTALL.md) for detailed installation options.

## Features

- **Multiple backup jobs**: Configure and manage multiple backup jobs
- **Encrypted backups**: All backups are encrypted using Argon2id + XSalsa20-Poly1305
- **Compression**: Automatic compression with zstd before encryption
- **Retention policies**: Automatically cleanup old backups based on age
- **Backup history**: Track all backup operations with timestamps and sizes
- **Progress tracking**: Real-time progress display during backup/restore
- **Interactive & CLI modes**: Menu-driven interface or command-line operation

## Building

```bash
./build_backup_manager.sh
```

This will:
1. Generate C sources from Vala library
2. Compile the C library
3. Compile the C++ backup manager
4. Link the final executable

## Usage

### Interactive Mode

Simply run the program to enter the interactive menu:

```bash
./backup-manager
```

You'll see a menu with these options:
1. List backup jobs
2. Add new backup job
3. Remove backup job
4. Run backup
5. View backup history
6. Restore from backup
7. Cleanup old backups
8. Show status
0. Exit

### Non-Interactive Mode

For automation or scripting:

```bash
# List all configured jobs
./backup-manager list

# Show status of all jobs
./backup-manager status

# View backup history
./backup-manager history

# Run a specific backup job
./backup-manager run "My Backup Job"

# Cleanup old backups
./backup-manager cleanup
```

## Example Workflow

### 1. Add a Backup Job

Run `./backup-manager` and choose option 2:

```
Job name: Documents
Source directory: /home/user/Documents
Backup directory: /backups/documents
Password: your-secure-password
Retention days (0 = forever): 30
```

This creates a backup job that will:
- Archive and encrypt `/home/user/Documents`
- Store encrypted archives in `/backups/documents`
- Keep backups for 30 days before automatic cleanup

### 2. Run the Backup

Choose option 4 and enter the job name:

```
Job name to run: Documents
```

You'll see real-time progress:

```
Documents [====================] 100.0% | 1.2 GB → 456 MB (62.0% saved)

✓ Backup completed successfully!
  Archive: /backups/documents/Documents_20240115_143022.dvx3
  Original size: 1.2 GB
  Compressed size: 456 MB
  Space saved: 62.0%
  Time: 45s
```

### 3. View History

Choose option 5 to see backup history:

```
[2024-01-15 14:30:22] ✓ Documents - 1.2 GB → 456 MB
[2024-01-14 12:15:10] ✓ Documents - 1.1 GB → 423 MB
[2024-01-13 09:45:33] ✓ Documents - 1.1 GB → 418 MB
```

### 4. Restore a Backup

Choose option 6:

```
Archive path to restore: /backups/documents/Documents_20240115_143022.dvx3
Restore to directory: /tmp/restored
Password: your-secure-password
```

The backup will be decrypted and extracted to the specified directory.

### 5. Cleanup Old Backups

Choose option 7 to remove backups older than the retention period for each job.

## Configuration Files

The backup manager creates two files in the current directory:

### `backup-manager.conf`

Plain text configuration file storing all backup jobs:

```
[Documents]
source=/home/user/Documents
backup_dir=/backups/documents
password=your-secure-password
enabled=1
last_backup=1705327822
retention_days=30
```

### `backup-history.log`

CSV-style log of all backup operations:

```
1705327822,Documents,/backups/documents/Documents_20240115_143022.dvx3,1200000000,456000000,1,
1705241710,Documents,/backups/documents/Documents_20240114_121510.dvx3,1100000000,423000000,1,
```

## Backup Archive Format

Archives use the `.dvx3` extension and contain:
- JSON metadata header (salt, chunk count, Argon2id parameters)
- Encrypted chunks (1 MiB each) using XSalsa20-Poly1305
- Original data is: `tar` archive → `zstd` compression → `secretbox` encryption

## Automation

Use cron or systemd timers to automate backups:

```bash
# Run daily backups at 2 AM
0 2 * * * /path/to/backup-manager run "Documents"

# Weekly cleanup on Sunday at 3 AM
0 3 * * 0 /path/to/backup-manager cleanup
```

## Security Notes

- Passwords are stored in plain text in `backup-manager.conf`
- Ensure proper file permissions: `chmod 600 backup-manager.conf`
- Use strong passwords (12+ characters recommended)
- Keep backups on separate physical media for disaster recovery
- Test restore procedures regularly

## Troubleshooting

**Build fails with missing dependencies:**
```bash
# Install required packages (Arch Linux example)
sudo pacman -S vala glib2 json-glib libsodium zstd

# Or on Debian/Ubuntu:
sudo apt-get install valac libglib2.0-dev libjson-glib-dev libsodium-dev zstd
```

**Backup fails with "Permission denied":**
- Ensure you have read access to source directory
- Ensure you have write access to backup directory
- Check disk space availability

**Restore fails with "Wrong password":**
- Verify you're using the correct password
- Check that the archive file is not corrupted

## Advanced Usage

### Custom Retention Policies

Edit `backup-manager.conf` to set different retention periods:

```
retention_days=0   # Keep forever
retention_days=7   # Keep for 1 week
retention_days=30  # Keep for 1 month
retention_days=365 # Keep for 1 year
```

### Backup Multiple Directories

Create separate jobs for each directory:

```
Job 1: Documents (/home/user/Documents)
Job 2: Pictures (/home/user/Pictures)
Job 3: Code (/home/user/Projects)
```

### Scripted Backups

```bash
#!/bin/bash
# backup-all.sh - Run all configured backups

for job in Documents Pictures Code; do
    echo "Backing up $job..."
    ./backup-manager run "$job"
done
```

## Performance

Typical compression ratios:
- Documents (text/PDF): 60-80% size reduction
- Pictures (JPEG/PNG): 5-15% size reduction (already compressed)
- Code/Projects: 70-90% size reduction
- Mixed media: 40-60% size reduction

Backup speed depends on:
- Source directory size
- CPU speed (Argon2id key derivation, zstd compression)
- Disk I/O speed
- Network speed (if backing up to network storage)

## License

This software uses:
- **libsodium** - ISC License
- **GLib** - LGPL
- **json-glib** - LGPL
- **zstd** - BSD/GPLv2
