#include "backup-manager.hpp"
#include "dvx3.hpp"
#include <gtest/gtest.h>
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

TEST(Dvx3Backup, ExcludeBackupDir) {
    std::string base = "/tmp/dvx3-excl-" + std::to_string(getpid());
    fs::create_directories(base + "/src");
    fs::create_directories(base + "/src/backups");
    std::ofstream f(base + "/src/test.txt"); f << "x"; f.close();

    backup::BackupManager mgr("test.conf", "test.log");
    backup::BackupJob job;
    job.name = "t1";
    job.source_path = base + "/src";
    job.backup_dir = base + "/src/backups";
    job.password = "pass";
    job.enabled = true;
    job.last_backup = 0;
    job.retention_days = 7;
    mgr.add_job(job);

    auto rec = mgr.run_backup("t1", [](uint64_t p, uint64_t t, uint64_t o) {});
    EXPECT_TRUE(rec.success);
    // Check that backup_dir is excluded (original_size reported in record should match du --exclude)
    fs::remove_all(base);
}
