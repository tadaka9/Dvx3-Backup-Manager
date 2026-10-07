/**
 * backup-manager.hpp - Comprehensive backup management system
 * 
 * Features:
 * - Multiple backup job configurations
 * - Backup history tracking
 * - Scheduled/manual backups
 * - Restore operations
 * - JSON-based configuration
 */

#pragma once

#include "dvx3.hpp"
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <chrono>
#include <ctime>
#include <algorithm>
#include <iostream>

namespace fs = std::filesystem;

namespace backup {

/**
 * Represents a single backup execution record
 */
struct BackupRecord {
    std::string job_name;
    std::time_t timestamp;
    std::string archive_path;
    uint64_t original_size;
    uint64_t compressed_size;
    bool success;
    std::string error_message;

    std::string format_timestamp() const {
        char buf[100];
        std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", std::localtime(&timestamp));
        return buf;
    }

    double compression_ratio() const {
        if (original_size == 0) return 0.0;
        return 100.0 * (1.0 - (double)compressed_size / original_size);
    }
};

/**
 * Configuration for a backup job
 */
struct BackupJob {
    std::string name;
    std::string source_path;
    std::string backup_dir;
    std::string password;
    bool enabled;
    std::time_t last_backup;
    int retention_days;  // 0 = keep forever

    std::string get_archive_path() const {
        char timestamp[100];
        auto now = std::time(nullptr);
        std::strftime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S", std::localtime(&now));
        return backup_dir + "/" + name + "_" + timestamp + ".dvx3";
    }

    std::string format_last_backup() const {
        if (last_backup == 0) return "Never";
        char buf[100];
        std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", std::localtime(&last_backup));
        return buf;
    }
};

/**
 * Main backup manager class
 */
class BackupManager {
private:
    std::string config_file_;
    std::string history_file_;
    std::vector<BackupJob> jobs_;
    std::vector<BackupRecord> history_;

    void load_config() {
        std::ifstream f(config_file_);
        if (!f.is_open()) return;

        jobs_.clear();
        std::string line;
        BackupJob current;
        bool in_job = false;

        while (std::getline(f, line)) {
            if (line.empty() || line[0] == '#') continue;
            
            auto pos = line.find('=');
            if (pos == std::string::npos) continue;

            std::string key = line.substr(0, pos);
            std::string value = line.substr(pos + 1);

            // Trim whitespace
            key.erase(0, key.find_first_not_of(" \t"));
            key.erase(key.find_last_not_of(" \t") + 1);
            value.erase(0, value.find_first_not_of(" \t"));
            value.erase(value.find_last_not_of(" \t") + 1);

            if (key == "[job]") {
                if (in_job && !current.name.empty()) {
                    jobs_.push_back(current);
                }
                current = BackupJob();
                current.enabled = true;
                current.last_backup = 0;
                current.retention_days = 30;
                in_job = true;
            } else if (key == "name") current.name = value;
            else if (key == "source") current.source_path = value;
            else if (key == "backup_dir") current.backup_dir = value;
            else if (key == "password") current.password = value;
            else if (key == "enabled") current.enabled = (value == "true" || value == "1");
            else if (key == "last_backup") current.last_backup = std::stol(value);
            else if (key == "retention_days") current.retention_days = std::stoi(value);
        }

        if (in_job && !current.name.empty()) {
            jobs_.push_back(current);
        }
    }

    void save_config() {
        std::ofstream f(config_file_);
        if (!f.is_open()) {
            throw std::runtime_error("Failed to save config: " + config_file_);
        }

        f << "# Backup Manager Configuration\n";
        f << "# Generated: " << std::time(nullptr) << "\n\n";

        for (const auto& job : jobs_) {
            f << "[job]\n";
            f << "name=" << job.name << "\n";
            f << "source=" << job.source_path << "\n";
            f << "backup_dir=" << job.backup_dir << "\n";
            f << "password=" << job.password << "\n";
            f << "enabled=" << (job.enabled ? "true" : "false") << "\n";
            f << "last_backup=" << job.last_backup << "\n";
            f << "retention_days=" << job.retention_days << "\n";
            f << "\n";
        }
    }

    void load_history() {
        std::ifstream f(history_file_);
        if (!f.is_open()) return;

        history_.clear();
        std::string line;

        while (std::getline(f, line)) {
            if (line.empty() || line[0] == '#') continue;

            std::istringstream iss(line);
            BackupRecord rec;
            std::string success_str;

            if (!(iss >> rec.timestamp >> rec.job_name >> rec.archive_path 
                      >> rec.original_size >> rec.compressed_size >> success_str)) {
                continue;
            }

            rec.success = (success_str == "1");
            std::getline(iss, rec.error_message);
            if (!rec.error_message.empty() && rec.error_message[0] == ' ') {
                rec.error_message = rec.error_message.substr(1);
            }

            history_.push_back(rec);
        }
    }

    void save_history() {
        std::ofstream f(history_file_);
        if (!f.is_open()) return;

        f << "# Backup History\n";
        f << "# timestamp job_name archive_path original_size compressed_size success error\n";

        for (const auto& rec : history_) {
            f << rec.timestamp << " "
              << rec.job_name << " "
              << rec.archive_path << " "
              << rec.original_size << " "
              << rec.compressed_size << " "
              << (rec.success ? "1" : "0");
            
            if (!rec.error_message.empty()) {
                f << " " << rec.error_message;
            }
            f << "\n";
        }
    }

    void add_history_record(const BackupRecord& record) {
        history_.push_back(record);
        save_history();
    }

    static bool is_subpath(const std::filesystem::path& child, const std::filesystem::path& parent) {
        auto pit = parent.begin();
        auto cit = child.begin();
        for (; pit != parent.end() && cit != child.end(); ++pit, ++cit) {
            if (*pit != *cit) return false;
        }
        return pit == parent.end();
    }

    uint64_t calculate_directory_size(const std::string& path, const std::string& exclude = "") {
        uint64_t total = 0;
        try {
            fs::path base = fs::path(path).lexically_normal();
            fs::path excl;
            bool has_excl = false;
            if (!exclude.empty()) {
                excl = fs::path(exclude).lexically_normal();
                has_excl = true;
            }
            for (const auto& entry : fs::recursive_directory_iterator(path)) {
                if (has_excl) {
                    fs::path p = entry.path().lexically_normal();
                    if (is_subpath(p, excl)) {
                        if (entry.is_directory()) {
                            // Skip recursion into excluded directory
                            continue;
                        }
                        // Skip files under excluded path
                        continue;
                    }
                }
                if (entry.is_regular_file()) {
                    total += entry.file_size();
                }
            }
        } catch (...) {
            // Ignore errors
        }
        return total;
    }

public:
    BackupManager(const std::string& config_file = "backup-manager.conf",
                  const std::string& history_file = "backup-history.log")
        : config_file_(config_file), history_file_(history_file) {
        load_config();
        load_history();
    }

    void add_job(const BackupJob& job) {
        // Check for duplicate names
        for (const auto& existing : jobs_) {
            if (existing.name == job.name) {
                throw std::runtime_error("Job with name '" + job.name + "' already exists");
            }
        }

        // Create backup directory if needed
        fs::create_directories(job.backup_dir);

        jobs_.push_back(job);
        save_config();
    }

    void remove_job(const std::string& name) {
        auto it = std::remove_if(jobs_.begin(), jobs_.end(),
            [&name](const BackupJob& j) { return j.name == name; });
        
        if (it == jobs_.end()) {
            throw std::runtime_error("Job not found: " + name);
        }

        jobs_.erase(it, jobs_.end());
        save_config();
    }

    const std::vector<BackupJob>& get_jobs() const {
        return jobs_;
    }

    const std::vector<BackupRecord>& get_history() const {
        return history_;
    }

    BackupRecord run_backup(const std::string& job_name, 
                           std::function<void(uint64_t, uint64_t, uint64_t)> progress = nullptr) {
        // Find job
        auto it = std::find_if(jobs_.begin(), jobs_.end(),
            [&job_name](const BackupJob& j) { return j.name == job_name; });

        if (it == jobs_.end()) {
            throw std::runtime_error("Job not found: " + job_name);
        }

        if (!it->enabled) {
            throw std::runtime_error("Job is disabled: " + job_name);
        }

        BackupRecord record;
        record.job_name = job_name;
        record.timestamp = std::time(nullptr);
        record.archive_path = it->get_archive_path();
        record.success = false;

        try {
            // Determine exclusion: if backup_dir is inside source_path, exclude it
            std::string exclude_under;
            try {
                fs::path srcp = fs::path(it->source_path).lexically_normal();
                fs::path backp = fs::path(it->backup_dir).lexically_normal();
                if (is_subpath(backp, srcp)) {
                    exclude_under = backp.string();
                }
            } catch (...) {
                // If path normalization fails, ignore exclusion
            }

            // Calculate original size excluding backup_dir if applicable
            record.original_size = calculate_directory_size(it->source_path, exclude_under);

            // Perform backup
            dvx3::encrypt(it->source_path, record.archive_path, it->password, exclude_under, progress);

            // Get compressed size
            record.compressed_size = fs::file_size(record.archive_path);
            record.success = true;

            // Update job last backup time
            it->last_backup = record.timestamp;
            save_config();

        } catch (const std::exception& e) {
            record.error_message = e.what();
            record.success = false;
        }

        add_history_record(record);
        return record;
    }

    void restore_backup(const std::string& archive_path, 
                       const std::string& dest_path,
                       const std::string& password,
                       std::function<void(uint64_t, uint64_t, uint64_t)> progress = nullptr) {
        dvx3::decrypt(archive_path, dest_path, password, progress);
    }

    std::vector<BackupRecord> get_job_history(const std::string& job_name) const {
        std::vector<BackupRecord> result;
        for (const auto& rec : history_) {
            if (rec.job_name == job_name) {
                result.push_back(rec);
            }
        }
        return result;
    }

    void cleanup_old_backups() {
        auto now = std::time(nullptr);

        for (const auto& job : jobs_) {
            if (job.retention_days <= 0) continue;

            auto cutoff = now - (job.retention_days * 24 * 60 * 60);
            
            for (const auto& rec : history_) {
                if (rec.job_name == job.name && rec.timestamp < cutoff) {
                    try {
                        if (fs::exists(rec.archive_path)) {
                            fs::remove(rec.archive_path);
                        }
                    } catch (...) {
                        // Ignore cleanup errors
                    }
                }
            }
        }
    }

    void print_status() const {
        std::cout << "\n=== Backup Manager Status ===\n\n";
        
        if (jobs_.empty()) {
            std::cout << "No backup jobs configured.\n";
            return;
        }

        for (const auto& job : jobs_) {
            std::cout << "Job: " << job.name << "\n";
            std::cout << "  Source: " << job.source_path << "\n";
            std::cout << "  Backup Dir: " << job.backup_dir << "\n";
            std::cout << "  Status: " << (job.enabled ? "Enabled" : "Disabled") << "\n";
            std::cout << "  Last Backup: " << job.format_last_backup() << "\n";
            std::cout << "  Retention: " << (job.retention_days > 0 
                ? std::to_string(job.retention_days) + " days" : "Forever") << "\n";

            auto job_history = get_job_history(job.name);
            std::cout << "  Total Backups: " << job_history.size() << "\n";

            if (!job_history.empty()) {
                auto& last = job_history.back();
                std::cout << "  Last Status: " << (last.success ? "✓ Success" : "✗ Failed") << "\n";
                if (last.success) {
                    std::cout << "  Last Size: " << dvx3::format_size(last.original_size) 
                             << " → " << dvx3::format_size(last.compressed_size)
                             << " (" << std::fixed << std::setprecision(1) 
                             << last.compression_ratio() << "% saved)\n";
                }
            }
            std::cout << "\n";
        }
    }
};

} // namespace backup
