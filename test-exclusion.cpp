/**
 * test-exclusion.cpp - Quick test for backup_dir exclusion logic
 */

#include "backup-manager.hpp"
#include <iostream>
#include <iomanip>

int main() {
    std::cout << "=== Backup Directory Exclusion Test ===\n\n";
    
    try {
        // Create manager in /tmp/dvx3test directory
        std::filesystem::create_directories("/tmp/dvx3test");
        std::filesystem::current_path("/tmp/dvx3test");
        
        backup::BackupManager manager("test.conf", "test.log");
        
        // Add job with backup_dir inside source_path
        backup::BackupJob job;
        job.name = "testjob";
        job.source_path = "/tmp/dvx3test/src";
        job.backup_dir = "/tmp/dvx3test/src/backups";
        job.password = "testpass123";
        job.enabled = true;
        job.last_backup = 0;
        job.retention_days = 7;
        
        manager.add_job(job);
        
        std::cout << "Running backup with backup_dir inside source...\n\n";
        
        uint64_t last_proc = 0;
        auto record = manager.run_backup("testjob",
            [&last_proc](uint64_t proc, uint64_t tot, uint64_t out) {
                if (proc > last_proc + 10000 || proc == tot) {
                    std::cout << "\rProgress: " << dvx3::format_size(proc) 
                             << " / " << dvx3::format_size(tot) 
                             << " → " << dvx3::format_size(out) << std::flush;
                    last_proc = proc;
                }
            });
        
        std::cout << "\n\n=== Results ===\n";
        std::cout << "Success: " << (record.success ? "YES" : "NO") << "\n";
        if (!record.success) {
            std::cout << "Error: " << record.error_message << "\n";
            return 1;
        }
        
        std::cout << "Archive: " << record.archive_path << "\n";
        std::cout << "Original size: " << dvx3::format_size(record.original_size) << "\n";
        std::cout << "Compressed size: " << dvx3::format_size(record.compressed_size) << "\n";
        std::cout << "Compression ratio: " << std::fixed << std::setprecision(1) 
                 << record.compression_ratio() << "%\n";
        
        // Compare with du measurements
        std::cout << "\n=== Verification ===\n";
        
        FILE* pipe = popen("du -sb /tmp/dvx3test/src 2>/dev/null | cut -f1", "r");
        if (pipe) {
            char buffer[128];
            if (fgets(buffer, sizeof(buffer), pipe)) {
                uint64_t full_size = std::stoull(buffer);
                std::cout << "Full directory (du -sb): " << dvx3::format_size(full_size) << "\n";
            }
            pclose(pipe);
        }
        
        pipe = popen("du -sb /tmp/dvx3test/src --exclude=backups 2>/dev/null | cut -f1", "r");
        if (pipe) {
            char buffer[128];
            if (fgets(buffer, sizeof(buffer), pipe)) {
                uint64_t excl_size = std::stoull(buffer);
                std::cout << "Excluding backups (du --exclude): " << dvx3::format_size(excl_size) << "\n";
                std::cout << "Reported original_size: " << dvx3::format_size(record.original_size) << "\n";
                
                if (record.original_size == excl_size) {
                    std::cout << "\n✓ PASS: original_size matches excluded size!\n";
                } else {
                    int64_t diff = (int64_t)record.original_size - (int64_t)excl_size;
                    std::cout << "\n✗ FAIL: Difference of " << diff << " bytes\n";
                }
            }
            pclose(pipe);
        }
        
        // Check if old backup was excluded from archive
        std::cout << "\n=== Archive Contents Check ===\n";
        std::string cmd = "tar -tzf <(zstd -d -c <(head -c -$(($(stat -c%s '" + record.archive_path + "') - 4)) '" + record.archive_path + "' | tail -c +$(($(head -c4 '" + record.archive_path + "' | od -An -tu4) + 5)))) 2>/dev/null | grep -c 'old_backup' || echo 0";
        pipe = popen(("bash -c \"" + cmd + "\"").c_str(), "r");
        if (pipe) {
            char buffer[16];
            if (fgets(buffer, sizeof(buffer), pipe)) {
                int count = std::stoi(buffer);
                if (count == 0) {
                    std::cout << "✓ PASS: Old backup NOT included in archive\n";
                } else {
                    std::cout << "✗ FAIL: Old backup found in archive (" << count << " matches)\n";
                }
            }
            pclose(pipe);
        }
        
        return 0;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
}
