# Backup Manager Qt6 GUI

A graphical user interface for the Backup Manager with configurable tar and zstd options.

## Features

- **Visual job management**: Add, edit, and remove backup jobs through dialogs
- **Configurable compression**: Adjust zstd compression level (1-22) and thread count
- **Tar options**: Configure permissions, ownership, symlinks, and exclusion patterns
- **Real-time progress**: Visual progress bar with size and compression ratio display
- **History view**: Table showing all backup operations with timestamps and status
- **Settings persistence**: All compression settings saved between sessions

## Building

```bash
./build_gui.sh
```

Requirements:
- Qt6 (qt6-base)
- All standard backup-manager dependencies

## Running

```bash
./backup-manager-gui
```

Configuration is stored in `~/.config/backup-manager/`

## Usage

### Adding a Backup Job

1. Click "Add" button
2. Fill in the form:
   - **Job Name**: Friendly name for the backup
   - **Source Directory**: Directory to backup (use Browse button)
   - **Backup Directory**: Where to store encrypted archives
   - **Password**: Encryption password (hidden input)
   - **Retention**: Days to keep backups (0 = forever)

3. Configure compression settings:
   - **Zstd Level**: 1 (fast) to 22 (best compression), default 3
   - **Threads**: Number of compression threads (0 = auto-detect)
   
4. Configure tar options:
   - ☑ **Preserve file permissions**: Maintain file mode bits
   - ☑ **Preserve owner/group**: Keep original ownership (requires root)
   - ☐ **Follow symbolic links**: Archive link targets instead of links
   - ☐ **Exclude hidden files**: Skip files starting with `.`
   - **Exclude Patterns**: One pattern per line (e.g., `*.tmp`, `node_modules`)

5. Click OK to save

### Running a Backup

1. Select a job from the list
2. Click "Run Backup"
3. Watch progress bar and log output
4. View results in history table

### Global Settings

**File → Settings** to configure default compression and tar options for all jobs.

Settings include:
- Zstd compression level and threads
- Tar archive options (permissions, ownership, symlinks)
- Global exclusion patterns

## Compression Levels

| Level | Speed | Ratio | Use Case |
|-------|-------|-------|----------|
| 1-3   | Fast  | Good  | Frequent backups, large files |
| 4-9   | Medium| Better| Daily backups |
| 10-15 | Slow  | Great | Weekly/monthly archives |
| 16-22 | Very slow | Best | Long-term storage |

**Recommended**: Level 3 with auto threads

## Exclusion Patterns

Common patterns to add:
```
*.tmp
*.log
*.cache
__pycache__
node_modules
.git
.svn
*.o
*.pyc
```

## Tips

- **Password security**: Passwords are stored in plaintext config. Set proper file permissions:
  ```bash
  chmod 600 ~/.config/backup-manager/backup-manager.conf
  ```

- **Thread count**: Set to 0 for automatic detection (uses all CPU cores)

- **Large backups**: Use lower compression levels (1-3) for faster completion

- **Storage optimization**: Use higher levels (10+) when backup time isn't critical

- **Symlinks**: Enable "Follow symbolic links" if you want to backup link targets

- **Hidden files**: Disable to exclude config directories (`.config`, `.cache`, etc.)

## Keyboard Shortcuts

- **Ctrl+Q**: Quit
- **Ctrl+,**: Settings (on some systems)

## Configuration Files

All settings stored in: `~/.config/backup-manager/`

- `backup-manager.conf`: Job configurations
- `backup-history.log`: Backup history
- Qt settings (QSettings):
  - Compression defaults
  - Window geometry
  - UI state

## Troubleshooting

**GUI doesn't start:**
```bash
# Check Qt6 installation
pkg-config --modversion Qt6Widgets

# Run from terminal to see errors
./backup-manager-gui
```

**Backup fails:**
- Check log panel for error messages
- Verify source directory exists and is readable
- Ensure backup directory is writable
- Test password in CLI mode first

**Performance issues:**
- Lower zstd level (try 1-3)
- Reduce thread count if system becomes unresponsive
- Add more exclusion patterns to skip unnecessary files

## Comparison: CLI vs GUI

| Feature | CLI | GUI |
|---------|-----|-----|
| Job management | Text config | Visual dialogs |
| Progress | Terminal output | Progress bar + log |
| History | Text log | Sortable table |
| Settings | Manual edit | Form with validation |
| Automation | Cron/systemd | Manual operation |
| Resource usage | Minimal | ~50MB RAM |

Use CLI for:
- Automated/scheduled backups
- Server environments
- Scripting
- Minimal resource usage

Use GUI for:
- Interactive management
- Visual feedback
- Testing configurations
- Desktop environments

## Advanced: Custom Tar Options

The GUI configures these tar flags:

- **Preserve permissions**: `--preserve-permissions` (`-p`)
- **Preserve owner**: `--same-owner`
- **Follow symlinks**: `--dereference` (`-h`)
- **Exclude patterns**: Multiple `--exclude=pattern` flags

Future versions may expose more tar options through the settings dialog.

## Development

To modify the GUI:

1. Edit `backup-manager-gui.hpp` (interface) or `backup-manager-gui.cpp` (implementation)
2. Run `./build_gui.sh`
3. If you change Q_OBJECT classes, MOC will regenerate meta-objects automatically

Key files:
- `backup-manager-gui.hpp`: Qt class definitions with Q_OBJECT macros
- `backup-manager-gui.cpp`: Implementation + main()
- `build_gui.sh`: Build script that runs Qt MOC and links everything
