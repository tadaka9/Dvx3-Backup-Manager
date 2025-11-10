/**
 * backup-manager.cpp - Interactive backup management CLI
 * 
 * A comprehensive backup manager using the dvx3 library
 */

#include "backup-manager.hpp"
#include <iostream>
#include <iomanip>
#include <limits>
#include <termios.h>
#include <unistd.h>

using namespace backup;

void clear_input() {
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
}

std::string get_input(const std::string& prompt) {
    std::cout << prompt;
    std::string input;
    std::getline(std::cin, input);
    return input;
}

std::string get_password(const std::string& prompt) {
    std::cout << prompt;
    std::string password;
    
    // Disable terminal echo
    termios oldt;
    tcgetattr(STDIN_FILENO, &oldt);
    termios newt = oldt;
    newt.c_lflag &= ~ECHO;
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    
    // Read password
    std::getline(std::cin, password);
    
    // Restore terminal echo
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    
    std::cout << "\n";
    return password;
}

void print_menu() {
    std::cout << "\n╔════════════════════════════════════╗\n";
    std::cout << "║    Backup Manager - Main Menu      ║\n";
    std::cout << "╚════════════════════════════════════╝\n\n";
    std::cout << "  1. List backup jobs\n";
    std::cout << "  2. Add new backup job\n";
    std::cout << "  3. Remove backup job\n";
    std::cout << "  4. Run backup\n";
    std::cout << "  5. View backup history\n";
    std::cout << "  6. Restore from backup\n";
    std::cout << "  7. Cleanup old backups\n";
    std::cout << "  8. Show status\n";
    std::cout << "  0. Exit\n\n";
}

void show_progress(const std::string& label, uint64_t processed, uint64_t total, uint64_t output) {
    double pct = total > 0 ? (double)processed / total * 100.0 : 0.0;
    if (pct > 100.0) pct = 100.0;

    int bar_width = 40;
    int filled = (int)(pct / 100.0 * bar_width);

    std::cout << "\r" << label << " [";
    for (int i = 0; i < bar_width; i++) {
        std::cout << (i < filled ? "=" : " ");
    }
    std::cout << "] " << std::fixed << std::setprecision(1) << pct << "% | "
             << dvx3::format_size(processed);
    
    if (output > 0) {
        std::cout << " → " << dvx3::format_size(output);
        double ratio = processed > 0 ? (1.0 - (double)output / processed) * 100.0 : 0.0;
        std::cout << " (" << std::fixed << std::setprecision(1) << ratio << "% saved)";
    }
    
    std::cout.flush();
}

void list_jobs(BackupManager& manager) {
    const auto& jobs = manager.get_jobs();
    
    if (jobs.empty()) {
        std::cout << "\nNo backup jobs configured.\n";
        return;
    }

    std::cout << "\n╔════════════════════════════════════════════════════════════════╗\n";
    std::cout << "║                    Configured Backup Jobs                      ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════════╝\n\n";

    for (size_t i = 0; i < jobs.size(); i++) {
        const auto& job = jobs[i];
        std::cout << "[" << (i + 1) << "] " << job.name << "\n";
        std::cout << "    Source: " << job.source_path << "\n";
        std::cout << "    Backup to: " << job.backup_dir << "\n";
        std::cout << "    Status: " << (job.enabled ? "✓ Enabled" : "✗ Disabled") << "\n";
        std::cout << "    Last backup: " << job.format_last_backup() << "\n";
        std::cout << "\n";
    }
}

void add_job(BackupManager& manager) {
    std::cout << "\n=== Add New Backup Job ===\n\n";

    BackupJob job;
    job.name = get_input("Job name: ");
    job.source_path = get_input("Source directory: ");
    job.backup_dir = get_input("Backup directory: ");
    job.password = get_password("Password: ");
    
    std::string retention = get_input("Retention days (0 = forever): ");
    job.retention_days = retention.empty() ? 30 : std::stoi(retention);
    
    job.enabled = true;
    job.last_backup = 0;

    try {
        manager.add_job(job);
        std::cout << "\n✓ Backup job '" << job.name << "' added successfully.\n";
    } catch (const std::exception& e) {
        std::cout << "\n✗ Error: " << e.what() << "\n";
    }
}

void remove_job(BackupManager& manager) {
    list_jobs(manager);
    
    if (manager.get_jobs().empty()) return;

    std::string name = get_input("\nJob name to remove: ");
    
    try {
        manager.remove_job(name);
        std::cout << "\n✓ Job '" << name << "' removed successfully.\n";
    } catch (const std::exception& e) {
        std::cout << "\n✗ Error: " << e.what() << "\n";
    }
}

void run_backup(BackupManager& manager) {
    list_jobs(manager);
    
    if (manager.get_jobs().empty()) return;

    std::string name = get_input("\nJob name to run: ");

    std::cout << "\nStarting backup of '" << name << "'...\n";

    try {
        auto start = std::chrono::steady_clock::now();

        auto record = manager.run_backup(name, 
            [&name](uint64_t proc, uint64_t tot, uint64_t out) {
                show_progress(name, proc, tot, out);
            });

        auto end = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::seconds>(end - start);

        std::cout << "\n\n";

        if (record.success) {
            std::cout << "✓ Backup completed successfully!\n";
            std::cout << "  Archive: " << record.archive_path << "\n";
            std::cout << "  Original size: " << dvx3::format_size(record.original_size) << "\n";
            std::cout << "  Compressed size: " << dvx3::format_size(record.compressed_size) << "\n";
            std::cout << "  Space saved: " << std::fixed << std::setprecision(1) 
                     << record.compression_ratio() << "%\n";
            std::cout << "  Time: " << duration.count() << "s\n";
        } else {
            std::cout << "✗ Backup failed: " << record.error_message << "\n";
        }
    } catch (const std::exception& e) {
        std::cout << "\n\n✗ Error: " << e.what() << "\n";
    }
}

void view_history(BackupManager& manager) {
    const auto& history = manager.get_history();
    
    if (history.empty()) {
        std::cout << "\nNo backup history available.\n";
        return;
    }

    std::cout << "\n╔════════════════════════════════════════════════════════════════╗\n";
    std::cout << "║                      Backup History                            ║\n";
    std::cout << "╚════════════════════════════════════════════════════════════════╝\n\n";

    // Show last 20 entries
    size_t start = history.size() > 20 ? history.size() - 20 : 0;
    
    for (size_t i = start; i < history.size(); i++) {
        const auto& rec = history[i];
        std::cout << "[" << rec.format_timestamp() << "] ";
        std::cout << (rec.success ? "✓" : "✗") << " ";
        std::cout << rec.job_name;
        
        if (rec.success) {
            std::cout << " - " << dvx3::format_size(rec.original_size) 
                     << " → " << dvx3::format_size(rec.compressed_size);
        } else {
            std::cout << " - FAILED";
        }
        std::cout << "\n";
    }

    if (history.size() > 20) {
        std::cout << "\n(Showing last 20 of " << history.size() << " entries)\n";
    }
}

void restore_backup(BackupManager& manager) {
    const auto& history = manager.get_history();
    
    if (history.empty()) {
        std::cout << "\nNo backups available for restoration.\n";
        return;
    }

    std::cout << "\n=== Recent Backups ===\n\n";
    
    // Show last 10 successful backups
    std::vector<const BackupRecord*> recent;
    for (auto it = history.rbegin(); it != history.rend() && recent.size() < 10; ++it) {
        if (it->success) {
            recent.push_back(&(*it));
        }
    }

    for (size_t i = 0; i < recent.size(); i++) {
        const auto& rec = *recent[i];
        std::cout << "[" << (i + 1) << "] " << rec.job_name 
                 << " - " << rec.format_timestamp() << "\n";
        std::cout << "    " << rec.archive_path << "\n";
        std::cout << "    Size: " << dvx3::format_size(rec.compressed_size) << "\n\n";
    }

    std::string archive = get_input("Archive path to restore: ");
    std::string dest = get_input("Restore to directory: ");
    std::string password = get_password("Password: ");

    std::cout << "\nRestoring backup...\n";

    try {
        auto start = std::chrono::steady_clock::now();

        manager.restore_backup(archive, dest, password,
            [](uint64_t proc, uint64_t tot, uint64_t out) {
                show_progress("Restore", proc, tot, out);
            });

        auto end = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::seconds>(end - start);

        std::cout << "\n\n✓ Restore completed successfully!\n";
        std::cout << "  Restored to: " << dest << "\n";
        std::cout << "  Time: " << duration.count() << "s\n";

    } catch (const std::exception& e) {
        std::cout << "\n\n✗ Error: " << e.what() << "\n";
    }
}

void cleanup_backups(BackupManager& manager) {
    std::cout << "\nCleaning up old backups according to retention policies...\n";
    
    try {
        manager.cleanup_old_backups();
        std::cout << "✓ Cleanup completed.\n";
    } catch (const std::exception& e) {
        std::cout << "✗ Error: " << e.what() << "\n";
    }
}

int main(int argc, char** argv) {
    std::cout << "╔════════════════════════════════════════════╗\n";
    std::cout << "║   Backup Manager v1.0                      ║\n";
    std::cout << "║   Powered by dvx3 encryption library       ║\n";
    std::cout << "╚════════════════════════════════════════════╝\n";

    try {
        // Determine config directory
        std::string config_dir;
        const char* home = getenv("HOME");
        const char* xdg_config = getenv("XDG_CONFIG_HOME");
        
        if (xdg_config && xdg_config[0] != '\0') {
            config_dir = std::string(xdg_config) + "/backup-manager";
        } else if (home && home[0] != '\0') {
            config_dir = std::string(home) + "/.config/backup-manager";
        } else {
            config_dir = "."; // Fallback to current directory
        }
        
        // Create config directory if it doesn't exist
        std::filesystem::create_directories(config_dir);
        
        // Change to config directory for BackupManager
        std::string original_dir = std::filesystem::current_path().string();
        std::filesystem::current_path(config_dir);
        
        BackupManager manager;

        // Non-interactive mode
        if (argc > 1) {
            std::string cmd = argv[1];

            if (cmd == "list") {
                list_jobs(manager);
            } else if (cmd == "status") {
                manager.print_status();
            } else if (cmd == "history") {
                view_history(manager);
            } else if (cmd == "run" && argc > 2) {
                std::string job_name = argv[2];
                auto record = manager.run_backup(job_name,
                    [&job_name](uint64_t proc, uint64_t tot, uint64_t out) {
                        show_progress(job_name, proc, tot, out);
                    });
                std::cout << "\n";
                if (!record.success) {
                    std::cerr << "Backup failed: " << record.error_message << "\n";
                    return 1;
                }
            } else if (cmd == "cleanup") {
                cleanup_backups(manager);
            } else {
                std::cerr << "Usage: " << argv[0] << " [list|status|history|run <job>|cleanup]\n";
                return 1;
            }
            return 0;
        }

        // Interactive mode
        while (true) {
            print_menu();
            std::cout << "Choice: ";
            
            int choice;
            if (!(std::cin >> choice)) {
                clear_input();
                std::cout << "\nInvalid input. Please enter a number.\n";
                continue;
            }
            clear_input();

            switch (choice) {
                case 0:
                    std::cout << "\nGoodbye!\n";
                    return 0;
                
                case 1:
                    list_jobs(manager);
                    break;
                
                case 2:
                    add_job(manager);
                    break;
                
                case 3:
                    remove_job(manager);
                    break;
                
                case 4:
                    run_backup(manager);
                    break;
                
                case 5:
                    view_history(manager);
                    break;
                
                case 6:
                    restore_backup(manager);
                    break;
                
                case 7:
                    cleanup_backups(manager);
                    break;
                
                case 8:
                    manager.print_status();
                    break;
                
                default:
                    std::cout << "\nInvalid choice. Please try again.\n";
            }

            std::cout << "\nPress Enter to continue...";
            std::cin.get();
        }

    } catch (const std::exception& e) {
        std::cerr << "\nFatal error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
