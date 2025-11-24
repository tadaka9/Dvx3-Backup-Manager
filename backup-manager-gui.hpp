/**
 * backup-manager-gui.hpp - Qt6 GUI for Backup Manager
 */

#ifndef BACKUP_MANAGER_GUI_HPP
#define BACKUP_MANAGER_GUI_HPP

// Must include Qt headers before GLib to avoid signals macro conflict
#include <QMainWindow>
#include <QWidget>
#include <QListWidget>
#include <QPushButton>
#include <QLabel>
#include <QProgressBar>
#include <QTextEdit>
#include <QPlainTextEdit>
#include <QGroupBox>
#include <QSpinBox>
#include <QComboBox>
#include <QCheckBox>
#include <QLineEdit>
#include <QTableWidget>
#include <QTimer>
#include <QDialog>
#include <QFormLayout>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QFileDialog>
#include <QMessageBox>
#include <QStatusBar>
#include <QMenuBar>
#include <QMenu>
#include <QAction>
#include <QSettings>

// Undefine Qt's signals/slots before including GLib
#ifdef signals
#undef signals
#endif
#ifdef slots
#undef slots
#endif

#include <memory>
#include <thread>
#include "backup-manager.hpp"

// Redefine Qt macros after GLib
#define signals Q_SIGNALS
#define slots Q_SLOTS

namespace backup_gui {

// Animated gradient background widget
class PlainBackground : public QWidget {
    Q_OBJECT
public:
    explicit PlainBackground(QWidget* parent = nullptr);
protected:
    void paintEvent(QPaintEvent*) override;
};

// Configuration for compression and archiving
struct CompressionConfig {
    int zstd_level = 3;              // 1-22, default 3
    int zstd_threads = 0;            // 0 = auto
    bool tar_preserve_permissions = true;
    bool tar_preserve_owner = true;
    bool tar_follow_symlinks = false;
    bool tar_exclude_hidden = false;
    std::vector<std::string> tar_exclude_patterns;
    
    void save(QSettings& settings) const;
    void load(QSettings& settings);
};

// Job configuration dialog
class JobConfigDialog : public QDialog {
    Q_OBJECT

public:
    explicit JobConfigDialog(QWidget* parent = nullptr, 
                            const backup::BackupJob* existing = nullptr);
    backup::BackupJob get_job() const;
    CompressionConfig get_compression_config() const;

private:
    QLineEdit* name_edit;
    QLineEdit* source_edit;
    QLineEdit* backup_dir_edit;
    QLineEdit* password_edit;
    QSpinBox* retention_spin;
    QCheckBox* enabled_check;
    
    // Compression settings
    QSpinBox* zstd_level_spin;
    QSpinBox* zstd_threads_spin;
    QCheckBox* tar_preserve_permissions_check;
    QCheckBox* tar_preserve_owner_check;
    QCheckBox* tar_follow_symlinks_check;
    QCheckBox* tar_exclude_hidden_check;
    QTextEdit* tar_exclude_patterns_edit;
    
    QPushButton* browse_source_btn;
    QPushButton* browse_backup_btn;
    QPushButton* ok_btn;
    QPushButton* cancel_btn;

private slots:
    void browse_source();
    void browse_backup_dir();
};

// Main window
class BackupManagerWindow : public QMainWindow {
    Q_OBJECT

public:
    explicit BackupManagerWindow(QWidget* parent = nullptr);
    ~BackupManagerWindow();

private:
    void setup_ui();
    void setup_menu();
    void load_settings();
    void save_settings();
    void refresh_job_list();
    void refresh_history();
    void update_status();

    backup::BackupManager manager;
    CompressionConfig compression_config;
    
    // UI Components
    QListWidget* job_list;
    QTableWidget* history_table;
    QPlainTextEdit* log_display;
    QProgressBar* progress_bar;
    QLabel* status_label;
    
    // Buttons
    QPushButton* add_job_btn;
    QPushButton* edit_job_btn;
    QPushButton* remove_job_btn;
    QPushButton* run_backup_btn;
    QPushButton* restore_btn;
    QPushButton* cleanup_btn;
    
    // Menu actions
    QAction* settings_action;
    QAction* exit_action;
    QAction* about_action;
    
    // Background operation
    std::unique_ptr<std::thread> backup_thread;
    QTimer* update_timer;
    bool operation_running = false;

private slots:
    void add_job();
    void edit_job();
    void remove_job();
    void run_backup();
    void restore_backup();
    void cleanup_old();
    void show_settings();
    void show_about();
    void on_job_selected();
    void update_progress();
};

// Settings dialog
class SettingsDialog : public QDialog {
    Q_OBJECT

public:
    explicit SettingsDialog(CompressionConfig* config, QWidget* parent = nullptr);
    void accept() override;

private:
    CompressionConfig* config;
    
    QSpinBox* zstd_level_spin;
    QSpinBox* zstd_threads_spin;
    QCheckBox* tar_preserve_permissions_check;
    QCheckBox* tar_preserve_owner_check;
    QCheckBox* tar_follow_symlinks_check;
    QCheckBox* tar_exclude_hidden_check;
    QTextEdit* tar_exclude_patterns_edit;
};

// About dialog
class AboutDialog : public QDialog {
    Q_OBJECT

public:
    explicit AboutDialog(QWidget* parent = nullptr);
};

} // namespace backup_gui

#endif // BACKUP_MANAGER_GUI_HPP
