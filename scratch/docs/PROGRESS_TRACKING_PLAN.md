# Progress Tracking Restoration Plan (BH-002)

## Background

The original Dvx3 Backup Manager was designed with dynamic progress tracking via SIGUSR1 signals to GNU tar. However, this caused issues because:

1. **Tar processes terminate on SIGHUP**: GNU tar ignores SIGTERM but responds to other signals differently
2. **Signal handling in Vala subprocesses is complex**: Proper masking and signal forwarding needed
3. **File-based pipeline (current)**: Simpler but provides only static progress estimates

## Current Implementation Analysis

From `main.vala` lines ~470-560:

```vala
/* External tar command - writes to temporary file */
string[] tar_cmd = {
    "tar", "-c",
    "-f", tar_path,
    "-C", src_path, "."
};

/* zstd compresses tar output to final archive */
string[] zstd_cmd = {
    "zstd", "-T0", "-19",
    "-f", tar_path,
    "-o", zstd_path
};

/* Wait for commands to complete synchronously */
run_command_sync (tar_cmd, ...);  // Blocks until done
run_command_sync (zstd_cmd, ...);  // Blocks until done

/* Then read from file for progress (static estimate) */
var zstd_file = File.new_for_path(zstd_path);
uint64 compressed_total = zstd_file.query_info(...)
    .get_attribute_uint64(FileAttribute.STANDARD_SIZE);

/* Progress during encryption happens while reading from file, not pipe */
while (true) {
    var _blk_gb = zstd_in.read_bytes(CHUNK_SIZE);
    encoder.write(_blk_gb);  // Encryption progress tracked here
}
```

**Key Observation**: Progress tracking currently works for the encryption phase but is static/estimated for tar and zstd phases because they run synchronously and write to files first.

## Implementation Options

### Option A: Restore Original Pipe-Based Design (Recommended)

Re-enable signal-based dynamic progress by using pipes instead of temporary files:

```vala
/* Use pipe instead of temp file */
int pipe_fd;
PipeInfo? pipe_info = null;
Process.spawn_with_pipe("sh", "-c", "tar -c -C '%s' .".printf(src_path), 
    flags: SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
    setup_pipe: out pipe_fd);

/* Now we can track progress as tar writes to pipe */
var pipe = new Posix.Stream(pipe_fd);
uint8[] buffer = new uint8[CHUNK_SIZE];
while (true) {
    ssize_t bytes_read = posix_read(pipe, buffer, CHUNK_SIZE);
    if (bytes_read <= 0) break;
    // Compute progress: track total bytes read
}

/* Wait for process to complete */
Posix.waitpid(child_pid, out status, 0);
```

**Pros**: 
- True dynamic progress tracking
- Restores original design intent
- Compatible with existing progress display code

**Cons**:
- More complex signal handling required
- Need to properly forward signals to subprocess
- May need to use `SIGCHLD` or custom loop for status updates

### Option B: Multi-Phase Progress Tracking (Simpler Alternative)

Track progress in discrete phases:

```vala
/* Phase 1: tar execution */
uint64 tar_total = compute_directory_size(src_dir, exclude_rel);
var progress_bar = new ProgressBar("Scanning source", tar_total);

var tar_cmd = { "tar", "-c", "-f", tar_path, "-C", src_path, "." };
run_command_sync(tar_cmd, ...);  // Still sync but with pre-computed size

/* Phase 2: zstd compression */  
uint64 compressed_size = File.new_for_path(zstd_path).query_info(...)
    .get_attribute_uint64(FileAttribute.STANDARD_SIZE);
var compress_progress = new ProgressBar("Compressing", compressed_size);

/* Phase 3: encryption (already working) */
```

**Pros**:
- Simpler implementation
- No signal handling complexity
- Clear progress phases for user

**Cons**:
- Still not truly dynamic during tar/zstd execution
- Requires file-based approach

### Option C: Background Worker Thread

Use a separate thread to monitor subprocess and update UI:

```vala
public class ProgressMonitor : GLib.Object {
    private Process process;
    private ProcessWatch process_watch;
    
    public void start(string[] cmd) {
        var p = Process.spawn_with_output("sh", "-c", "sh -c '" + string.join(" ", cmd) + "'", ...);
        
        // Monitor stderr/stdout for progress updates if available
    }
}
```

**Pros**:
- Non-blocking UI updates
- Can handle multiple concurrent operations

**Cons**:
- More complex thread management
- May need to parse subprocess output for meaningful progress

## Recommended Implementation (Option A)

Given the original design intent and the existing infrastructure, Option A is recommended. Here's a high-level implementation:

### Step 1: Add Signal Handler Setup

```vala
private const int SIGUSR1 = 10;  // Or use Posix.SIGUSR1 if available

void signal_handler(int sig) {
    // Update progress display when SIGUSR1 received
}

[Code (cname="signal.h")]
extern int posix_signal(int sig, handler);

/* Set up signal handlers before spawning tar */
posix_signal(SIGUSR1, signal_handler);
```

### Step 2: Modify Tar Command to Support Dynamic Progress

Instead of writing directly to file, have tar write to pipe with progress indication. However, GNU tar doesn't naturally emit progress to stdout. We can use external tools or patch tar.

**Alternative**: Use `tar --progress` (GNU tar 3.6+) or parse stderr for progress messages.

### Step 3: Implement Progress Tracking Loop

```vala
int pipe_stdin;
Pid child_pid;
Process.spawn_async_with_pipes(
    null,
    { "sh", "-c", "tar -c -C '%s' ." }.printf(src_path),
    null,
    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
    null,
    out child_pid,
    out pipe_stdin,
    null,
    null
);

uint64 bytes_read = 0;
uint8[] buffer = new uint8[CHUNK_SIZE];

while (true) {
    ssize_t nread = posix_read(pipe_stdin, buffer, CHUNK_SIZE);
    if (nread <= 0) break;
    
    // Update progress: bytes_read / total_size_estimate
    
    // Feed to zstd pipe or encryption
}

posix_close(pipe_stdin);
Process.close_pid(child_pid);
```

### Step 4: Handle Cleanup and Errors

Ensure proper cleanup when subprocess fails:

```vala
try {
    // Progress tracking code
} catch (Error e) {
    // Clean up temp files
    if (FileUtils.test(tar_path, FileTest.EXISTS))
        FileUtils.remove(tar_path);
    if (FileUtils.test(zstd_path, FileTest.EXISTS))
        FileUtils.remove(zstd_path);
    throw;
}
```

## Implementation Tasks Checklist

- [ ] Add signal handler setup for SIGUSR1/SIGHUP
- [ ] Modify tar command to use pipe instead of direct file output  
- [ ] Implement progress tracking loop with dynamic updates
- [ ] Handle subprocess cleanup on error/interrupt
- [ ] Test with GNU tar and BSD tar variants
- [ ] Ensure proper signal masking in spawned process
- [ ] Update documentation with new behavior

## Acceptance Criteria

1. **Dynamic Progress**: Progress bar updates in real-time during tar execution (not just static estimate)
2. **Graceful Degradation**: Falls back to file-based approach if pipe fails on certain tar versions
3. **No Deadlocks**: Subprocess termination doesn't hang or leak resources  
4. **Signal Safety**: No signal handler deadlocks or race conditions

## Next Steps

1. Implement Option A (pipe-based design)
2. Test with various tar versions and signal configurations
3. Add error handling for subprocess failures
4. Document the new behavior
5. Update CHANGELOG/README if behavior changes significantly