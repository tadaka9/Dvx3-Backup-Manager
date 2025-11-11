/**
 * backup-manager-gui.cpp - Qt6 GUI Implementation
 */

#include "backup-manager-gui.hpp"
#include <QApplication>
#include <QGridLayout>
#include <QSplitter>
#include <QHeaderView>
#include <QDateTime>
#include <QStandardPaths>
#include <QDir>
#include <QGraphicsDropShadowEffect>
#include <QPropertyAnimation>
#include <QPainter>
#include <QPainterPath>
#include <cmath>
#include <ctime>
#include <vector>
#include <sstream>

namespace backup_gui {

// Animated gradient background implementation with particles
PsychedelicBackground::PsychedelicBackground(QWidget* parent) : QWidget(parent), hue_offset(0), time(0.0) {
    setAttribute(Qt::WA_StyledBackground, false);
    setAttribute(Qt::WA_OpaquePaintEvent, false);
    
    init_particles();
    
    // Smooth animation timer (30 FPS - safe for all users)
    auto* timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, [this]() {
        hue_offset = (hue_offset + 1) % 360;  // Slower color shift
        time += 0.033;  // ~30ms per frame
        update_particles();
        update();
    });
    timer->start(33);  // 30 FPS for smooth, safe animation
}

void PsychedelicBackground::init_particles() {
    particles.clear();
    std::srand(static_cast<unsigned>(std::time(nullptr)));
    
    // Create 50 floating particles
    for (int i = 0; i < 50; i++) {
        Particle p;
        p.x = std::rand() % 1400;
        p.y = std::rand() % 900;
        p.vx = (std::rand() % 40 - 20) / 20.0;  // -1 to +1
        p.vy = (std::rand() % 40 - 20) / 20.0;
        p.hue = std::rand() % 360;
        p.size = 2.0 + (std::rand() % 6);
        p.alpha = 0.3 + (std::rand() % 70) / 100.0;  // 0.3-1.0
        particles.push_back(p);
    }
}

void PsychedelicBackground::update_particles() {
    for (auto& p : particles) {
        p.x += p.vx;
        p.y += p.vy;
        
        // Wrap around screen edges
        if (p.x < 0) p.x = width();
        if (p.x > width()) p.x = 0;
        if (p.y < 0) p.y = height();
        if (p.y > height()) p.y = 0;
    }
}

void PsychedelicBackground::paintEvent(QPaintEvent*) {
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::SmoothPixmapTransform);
    
    // Deep space background - dark purple/blue base
    QLinearGradient base_grad(0, 0, width(), height());
    base_grad.setColorAt(0.0, QColor(10, 0, 25));      // Deep purple
    base_grad.setColorAt(0.5, QColor(0, 10, 30));      // Deep blue
    base_grad.setColorAt(1.0, QColor(15, 0, 20));      // Dark purple
    p.fillRect(rect(), base_grad);
    
    // Orbital radial gradients with time-based motion
    double orbit1_x = width() * (0.5 + 0.3 * std::sin(time * 0.3));
    double orbit1_y = height() * (0.5 + 0.3 * std::cos(time * 0.3));
    QRadialGradient orbit1(orbit1_x, orbit1_y, width() * 0.5);
    orbit1.setColorAt(0.0, QColor::fromHsv((hue_offset + 280) % 360, 220, 60, 50));
    orbit1.setColorAt(0.5, QColor::fromHsv((hue_offset + 280) % 360, 180, 30, 20));
    orbit1.setColorAt(1.0, QColor(0, 0, 0, 0));
    p.fillRect(rect(), orbit1);
    
    double orbit2_x = width() * (0.5 + 0.35 * std::cos(time * 0.4 + 1.5));
    double orbit2_y = height() * (0.5 + 0.35 * std::sin(time * 0.4 + 1.5));
    QRadialGradient orbit2(orbit2_x, orbit2_y, width() * 0.45);
    orbit2.setColorAt(0.0, QColor::fromHsv((hue_offset + 180) % 360, 240, 70, 45));
    orbit2.setColorAt(0.6, QColor::fromHsv((hue_offset + 180) % 360, 200, 25, 15));
    orbit2.setColorAt(1.0, QColor(0, 0, 0, 0));
    p.fillRect(rect(), orbit2);
    
    double orbit3_x = width() * (0.5 + 0.25 * std::sin(time * 0.25 + 3.0));
    double orbit3_y = height() * (0.5 + 0.25 * std::cos(time * 0.25 + 3.0));
    QRadialGradient orbit3(orbit3_x, orbit3_y, width() * 0.4);
    orbit3.setColorAt(0.0, QColor::fromHsv((hue_offset + 60) % 360, 255, 80, 40));
    orbit3.setColorAt(0.7, QColor::fromHsv((hue_offset + 60) % 360, 220, 20, 10));
    orbit3.setColorAt(1.0, QColor(0, 0, 0, 0));
    p.fillRect(rect(), orbit3);
    
    // Render particles with glow
    p.setCompositionMode(QPainter::CompositionMode_Plus);  // Additive blending for glow
    for (const auto& particle : particles) {
        QRadialGradient glow(particle.x, particle.y, particle.size * 3);
        int part_hue = (particle.hue + hue_offset) % 360;
        glow.setColorAt(0.0, QColor::fromHsv(part_hue, 255, 255, particle.alpha * 255 * 0.8));
        glow.setColorAt(0.5, QColor::fromHsv(part_hue, 200, 200, particle.alpha * 255 * 0.3));
        glow.setColorAt(1.0, QColor(0, 0, 0, 0));
        
        p.setBrush(glow);
        p.setPen(Qt::NoPen);
        p.drawEllipse(QPointF(particle.x, particle.y), particle.size * 3, particle.size * 3);
    }
    p.setCompositionMode(QPainter::CompositionMode_SourceOver);
    
    // Holographic grid with shimmer (subtle, non-strobing)
    int shimmer = (int)(20 + 10 * std::sin(time * 2.0));  // 20-30 alpha
    p.setPen(QPen(QColor(0, 255, 255, shimmer), 1));
    int grid_size = 50;
    for (int x = 0; x < width(); x += grid_size) {
        p.drawLine(x, 0, x, height());
    }
    for (int y = 0; y < height(); y += grid_size) {
        p.drawLine(0, y, width(), y);
    }
    
    // Corner accent lines (cyberpunk aesthetic)
    p.setPen(QPen(QColor::fromHsv((hue_offset + 180) % 360, 200, 255, 120), 2));
    p.drawLine(0, 0, 100, 0);
    p.drawLine(0, 0, 0, 100);
    p.drawLine(width() - 100, 0, width(), 0);
    p.drawLine(width(), 0, width(), 100);
    p.drawLine(0, height(), 100, height());
    p.drawLine(0, height() - 100, 0, height());
    p.drawLine(width() - 100, height(), width(), height());
    p.drawLine(width(), height() - 100, width(), height());
}

// CompressionConfig implementation
void CompressionConfig::save(QSettings& settings) const {
    settings.beginGroup("Compression");
    settings.setValue("zstd_level", zstd_level);
    settings.setValue("zstd_threads", zstd_threads);
    settings.setValue("tar_preserve_permissions", tar_preserve_permissions);
    settings.setValue("tar_preserve_owner", tar_preserve_owner);
    settings.setValue("tar_follow_symlinks", tar_follow_symlinks);
    settings.setValue("tar_exclude_hidden", tar_exclude_hidden);
    
    QStringList patterns;
    for (const auto& p : tar_exclude_patterns) {
        patterns << QString::fromStdString(p);
    }
    settings.setValue("tar_exclude_patterns", patterns);
    settings.endGroup();
}

void CompressionConfig::load(QSettings& settings) {
    settings.beginGroup("Compression");
    zstd_level = settings.value("zstd_level", 3).toInt();
    zstd_threads = settings.value("zstd_threads", 0).toInt();
    tar_preserve_permissions = settings.value("tar_preserve_permissions", true).toBool();
    tar_preserve_owner = settings.value("tar_preserve_owner", true).toBool();
    tar_follow_symlinks = settings.value("tar_follow_symlinks", false).toBool();
    tar_exclude_hidden = settings.value("tar_exclude_hidden", false).toBool();
    
    QStringList patterns = settings.value("tar_exclude_patterns").toStringList();
    tar_exclude_patterns.clear();
    for (const auto& p : patterns) {
        tar_exclude_patterns.push_back(p.toStdString());
    }
    settings.endGroup();
}

// JobConfigDialog implementation
JobConfigDialog::JobConfigDialog(QWidget* parent, const backup::BackupJob* existing)
    : QDialog(parent) {
    setWindowTitle(existing ? "Edit Backup Job" : "Add Backup Job");
    setMinimumWidth(600);
    
    auto* layout = new QVBoxLayout(this);
    
    // Basic settings group
    auto* basic_group = new QGroupBox("Basic Settings");
    auto* basic_layout = new QFormLayout(basic_group);
    
    name_edit = new QLineEdit();
    source_edit = new QLineEdit();
    backup_dir_edit = new QLineEdit();
    password_edit = new QLineEdit();
    password_edit->setEchoMode(QLineEdit::Password);
    retention_spin = new QSpinBox();
    retention_spin->setRange(0, 3650);
    retention_spin->setSuffix(" days");
    retention_spin->setSpecialValueText("Forever");
    enabled_check = new QCheckBox("Enabled");
    enabled_check->setChecked(true);
    
    browse_source_btn = new QPushButton("Browse...");
    browse_backup_btn = new QPushButton("Browse...");
    
    auto* source_layout = new QHBoxLayout();
    source_layout->addWidget(source_edit);
    source_layout->addWidget(browse_source_btn);
    
    auto* backup_layout = new QHBoxLayout();
    backup_layout->addWidget(backup_dir_edit);
    backup_layout->addWidget(browse_backup_btn);
    
    basic_layout->addRow("Job Name:", name_edit);
    basic_layout->addRow("Source Directory:", source_layout);
    basic_layout->addRow("Backup Directory:", backup_layout);
    basic_layout->addRow("Password:", password_edit);
    basic_layout->addRow("Retention:", retention_spin);
    basic_layout->addRow("", enabled_check);
    
    layout->addWidget(basic_group);
    
    // Compression settings group
    auto* comp_group = new QGroupBox("Compression & Archive Settings");
    auto* comp_layout = new QFormLayout(comp_group);
    
    zstd_level_spin = new QSpinBox();
    zstd_level_spin->setRange(1, 22);
    zstd_level_spin->setValue(3);
    zstd_level_spin->setToolTip("Compression level: 1=fast, 22=best (default: 3)");
    
    zstd_threads_spin = new QSpinBox();
    zstd_threads_spin->setRange(0, 64);
    zstd_threads_spin->setValue(0);
    zstd_threads_spin->setSpecialValueText("Auto");
    zstd_threads_spin->setToolTip("Number of threads for compression (0=auto)");
    
    tar_preserve_permissions_check = new QCheckBox("Preserve file permissions");
    tar_preserve_permissions_check->setChecked(true);
    
    tar_preserve_owner_check = new QCheckBox("Preserve owner/group");
    tar_preserve_owner_check->setChecked(true);
    
    tar_follow_symlinks_check = new QCheckBox("Follow symbolic links");
    tar_follow_symlinks_check->setChecked(false);
    
    tar_exclude_hidden_check = new QCheckBox("Exclude hidden files");
    tar_exclude_hidden_check->setChecked(false);
    
    tar_exclude_patterns_edit = new QTextEdit();
    tar_exclude_patterns_edit->setMaximumHeight(80);
    tar_exclude_patterns_edit->setPlaceholderText("One pattern per line, e.g.:\n*.tmp\n*.log\n__pycache__");
    
    comp_layout->addRow("Zstd Level:", zstd_level_spin);
    comp_layout->addRow("Threads:", zstd_threads_spin);
    comp_layout->addRow("Tar Options:", tar_preserve_permissions_check);
    comp_layout->addRow("", tar_preserve_owner_check);
    comp_layout->addRow("", tar_follow_symlinks_check);
    comp_layout->addRow("", tar_exclude_hidden_check);
    comp_layout->addRow("Exclude Patterns:", tar_exclude_patterns_edit);
    
    layout->addWidget(comp_group);
    
    // Buttons
    auto* btn_layout = new QHBoxLayout();
    ok_btn = new QPushButton("OK");
    cancel_btn = new QPushButton("Cancel");
    ok_btn->setDefault(true);
    
    btn_layout->addStretch();
    btn_layout->addWidget(ok_btn);
    btn_layout->addWidget(cancel_btn);
    
    layout->addLayout(btn_layout);
    
    // Load existing job
    if (existing) {
        name_edit->setText(QString::fromStdString(existing->name));
        source_edit->setText(QString::fromStdString(existing->source_path));
        backup_dir_edit->setText(QString::fromStdString(existing->backup_dir));
        password_edit->setText(QString::fromStdString(existing->password));
        retention_spin->setValue(existing->retention_days);
        enabled_check->setChecked(existing->enabled);
    }
    
    // Connections
    connect(browse_source_btn, &QPushButton::clicked, this, &JobConfigDialog::browse_source);
    connect(browse_backup_btn, &QPushButton::clicked, this, &JobConfigDialog::browse_backup_dir);
    connect(ok_btn, &QPushButton::clicked, this, &QDialog::accept);
    connect(cancel_btn, &QPushButton::clicked, this, &QDialog::reject);
}

void JobConfigDialog::browse_source() {
    QString dir = QFileDialog::getExistingDirectory(this, "Select Source Directory",
                                                     source_edit->text());
    if (!dir.isEmpty()) {
        source_edit->setText(dir);
    }
}

void JobConfigDialog::browse_backup_dir() {
    QString dir = QFileDialog::getExistingDirectory(this, "Select Backup Directory",
                                                     backup_dir_edit->text());
    if (!dir.isEmpty()) {
        backup_dir_edit->setText(dir);
    }
}

backup::BackupJob JobConfigDialog::get_job() const {
    backup::BackupJob job;
    job.name = name_edit->text().toStdString();
    job.source_path = source_edit->text().toStdString();
    job.backup_dir = backup_dir_edit->text().toStdString();
    job.password = password_edit->text().toStdString();
    job.retention_days = retention_spin->value();
    job.enabled = enabled_check->isChecked();
    job.last_backup = 0;
    return job;
}

CompressionConfig JobConfigDialog::get_compression_config() const {
    CompressionConfig config;
    config.zstd_level = zstd_level_spin->value();
    config.zstd_threads = zstd_threads_spin->value();
    config.tar_preserve_permissions = tar_preserve_permissions_check->isChecked();
    config.tar_preserve_owner = tar_preserve_owner_check->isChecked();
    config.tar_follow_symlinks = tar_follow_symlinks_check->isChecked();
    config.tar_exclude_hidden = tar_exclude_hidden_check->isChecked();
    
    QString patterns = tar_exclude_patterns_edit->toPlainText();
    QStringList lines = patterns.split('\n', Qt::SkipEmptyParts);
    for (const QString& line : lines) {
        QString trimmed = line.trimmed();
        if (!trimmed.isEmpty()) {
            config.tar_exclude_patterns.push_back(trimmed.toStdString());
        }
    }
    
    return config;
}

// BackupManagerWindow implementation
BackupManagerWindow::BackupManagerWindow(QWidget* parent)
    : QMainWindow(parent) {
    setWindowTitle("◈ DVX3 QUANTUM BACKUP SYSTEM ◈");
    resize(1400, 900);
    
    // Psychedelic background
    auto* bg = new PsychedelicBackground(this);
    bg->setGeometry(0, 0, 1400, 900);
    bg->lower();
    
    setup_menu();
    setup_ui();
    load_settings();
    refresh_job_list();
    refresh_history();
    
    update_timer = new QTimer(this);
    connect(update_timer, &QTimer::timeout, this, &BackupManagerWindow::update_progress);
    update_timer->start(100);
}

BackupManagerWindow::~BackupManagerWindow() {
    save_settings();
    if (backup_thread && backup_thread->joinable()) {
        backup_thread->join();
    }
}

void BackupManagerWindow::setup_menu() {
    auto* menu_bar = menuBar();
    menu_bar->setStyleSheet(
        "QMenuBar {"
        "  background: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(100, 0, 200, 0.7), stop:0.5 rgba(0, 150, 200, 0.7), stop:1 rgba(100, 0, 200, 0.7));"
        "  color: #00ffff;"
        "  font-family: 'Monospace';"
        "  font-weight: bold;"
        "  padding: 5px;"
        "  border-bottom: 2px solid rgba(0, 255, 255, 0.5);"
        "}"
        "QMenuBar::item {"
        "  padding: 5px 15px;"
        "  background: transparent;"
        "}"
        "QMenuBar::item:selected {"
        "  background: rgba(0, 255, 255, 0.3);"
        "  border-radius: 5px;"
        "}"
        "QMenu {"
        "  background: rgba(20, 0, 40, 0.95);"
        "  border: 2px solid rgba(0, 255, 255, 0.6);"
        "  border-radius: 8px;"
        "  color: #00ffff;"
        "  font-family: 'Monospace';"
        "}"
        "QMenu::item {"
        "  padding: 8px 25px;"
        "}"
        "QMenu::item:selected {"
        "  background: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(255, 0, 255, 0.5), stop:1 rgba(0, 255, 255, 0.5));"
        "}"
    );
    auto* file_menu = menu_bar->addMenu("⚡ &SYSTEM");
    auto* help_menu = menu_bar->addMenu("◉ &INFO");
    
    settings_action = new QAction("&Settings", this);
    settings_action->setShortcut(QKeySequence::Preferences);
    connect(settings_action, &QAction::triggered, this, &BackupManagerWindow::show_settings);
    
    exit_action = new QAction("E&xit", this);
    exit_action->setShortcut(QKeySequence::Quit);
    connect(exit_action, &QAction::triggered, this, &QWidget::close);
    
    file_menu->addAction(settings_action);
    file_menu->addSeparator();
    file_menu->addAction(exit_action);
    
    about_action = new QAction("&About", this);
    connect(about_action, &QAction::triggered, this, &BackupManagerWindow::show_about);
    
    help_menu->addAction(about_action);
}

void BackupManagerWindow::setup_ui() {
    auto* central = new QWidget();
    central->setStyleSheet("background: transparent;");
    setCentralWidget(central);
    
    auto* main_layout = new QVBoxLayout(central);
    main_layout->setSpacing(15);
    main_layout->setContentsMargins(20, 20, 20, 20);
    
    // Top section: Jobs list and controls
    auto* top_splitter = new QSplitter(Qt::Horizontal);
    
    // Left: Job list with glassmorphism
    auto* job_widget = new QWidget();
    job_widget->setStyleSheet(
        "QWidget {"
        "  background: qlineargradient(x1:0, y1:0, x2:1, y2:1, "
        "    stop:0 rgba(80, 0, 180, 0.15), stop:1 rgba(0, 120, 180, 0.15));"
        "  border: 2px solid qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(0, 255, 255, 0.6), stop:0.5 rgba(255, 0, 255, 0.6), stop:1 rgba(255, 255, 0, 0.6));"
        "  border-radius: 15px;"
        "  padding: 10px;"
        "}"
    );
    auto* shadow1 = new QGraphicsDropShadowEffect();
    shadow1->setBlurRadius(30);
    shadow1->setColor(QColor(0, 255, 255, 100));
    shadow1->setOffset(0, 0);
    job_widget->setGraphicsEffect(shadow1);
    auto* job_layout = new QVBoxLayout(job_widget);
    
    auto* job_label = new QLabel("⚡ <b>BACKUP SEQUENCES</b> ⚡");
    job_label->setStyleSheet(
        "color: #00ffff; "
        "font-family: 'Monospace'; "
        "font-size: 14px; "
        ""
        "background: transparent;"
        "border: none;"
        "padding: 5px;"
    );
    job_label->setAlignment(Qt::AlignCenter);
    job_list = new QListWidget();
    job_list->setStyleSheet(
        "QListWidget {"
        "  background: rgba(10, 10, 30, 0.5);"
        "  border: 1px solid rgba(0, 255, 255, 0.3);"
        "  border-radius: 10px;"
        "  color: #00ff88;"
        "  font-family: 'Monospace';"
        "  font-size: 11px;"
        "  padding: 5px;"
        "  selection-background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(255, 0, 255, 0.4), stop:1 rgba(0, 255, 255, 0.4));"
        "}"
        "QListWidget::item {"
        "  padding: 8px;"
        "  border-bottom: 1px solid rgba(0, 255, 255, 0.1);"
        "}"
        "QListWidget::item:hover {"
        "  background: rgba(0, 255, 255, 0.15);"
        "  border-left: 3px solid #ff00ff;"
        "}"
        "QListWidget::item:selected {"
        "  border-left: 3px solid #00ffff;"
        "  "
        "}"
    );
    
    auto* job_btn_layout = new QHBoxLayout();
    
    QString neon_btn_style = 
        "QPushButton {"
        "  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, "
        "    stop:0 rgba(100, 0, 200, 0.6), stop:1 rgba(0, 150, 255, 0.6));"
        "  border: 2px solid rgba(0, 255, 255, 0.6);"
        "  border-radius: 12px;"
        "  color: #00ffff;"
        "  font-family: 'Monospace';"
        "  font-size: 11px;"
        "  font-weight: bold;"
        "  padding: 10px 15px;"
        "  "
        "}"
        "QPushButton:hover {"
        "  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, "
        "    stop:0 rgba(150, 0, 255, 0.8), stop:1 rgba(0, 200, 255, 0.8));"
        "  border: 2px solid rgba(255, 0, 255, 0.8);"
        "}"
        "QPushButton:pressed {"
        "  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, "
        "    stop:0 rgba(200, 0, 255, 0.9), stop:1 rgba(0, 255, 255, 0.9));"
        "}"
        "QPushButton:disabled {"
        "  background: rgba(40, 40, 60, 0.3);"
        "  border: 2px solid rgba(100, 100, 120, 0.3);"
        "  color: rgba(100, 100, 120, 0.5);"
        "  "
        "}";
    
    add_job_btn = new QPushButton("⊕ ADD");
    add_job_btn->setStyleSheet(neon_btn_style);
    edit_job_btn = new QPushButton("✎ EDIT");
    edit_job_btn->setStyleSheet(neon_btn_style);
    remove_job_btn = new QPushButton("⊗ REMOVE");
    remove_job_btn->setStyleSheet(neon_btn_style);
    
    job_btn_layout->addWidget(add_job_btn);
    job_btn_layout->addWidget(edit_job_btn);
    job_btn_layout->addWidget(remove_job_btn);
    
    job_layout->addWidget(job_label);
    job_layout->addWidget(job_list);
    job_layout->addLayout(job_btn_layout);
    
    top_splitter->addWidget(job_widget);
    
    // Right: History table
    auto* history_widget = new QWidget();
    history_widget->setStyleSheet(
        "QWidget {"
        "  background: qlineargradient(x1:0, y1:0, x2:1, y2:1, "
        "    stop:0 rgba(0, 120, 180, 0.15), stop:1 rgba(180, 0, 120, 0.15));"
        "  border: 2px solid qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(255, 255, 0, 0.6), stop:0.5 rgba(0, 255, 255, 0.6), stop:1 rgba(255, 0, 255, 0.6));"
        "  border-radius: 15px;"
        "  padding: 10px;"
        "}"
    );
    auto* shadow2 = new QGraphicsDropShadowEffect();
    shadow2->setBlurRadius(30);
    shadow2->setColor(QColor(255, 255, 0, 100));
    shadow2->setOffset(0, 0);
    history_widget->setGraphicsEffect(shadow2);
    auto* history_layout = new QVBoxLayout(history_widget);
    
    auto* history_label = new QLabel("⌘ <b>QUANTUM HISTORY LOG</b> ⌘");
    history_label->setStyleSheet(
        "color: #ffff00; "
        "font-family: 'Monospace'; "
        "font-size: 14px; "
        ""
        "background: transparent;"
        "border: none;"
        "padding: 5px;"
    );
    history_label->setAlignment(Qt::AlignCenter);
    history_table = new QTableWidget();
    history_table->setColumnCount(5);
    history_table->setHorizontalHeaderLabels({"⟐ DATE/TIME", "⚙ JOB", "⊡ SIZE", "◎ RATIO", "◉ STATUS"});
    history_table->setStyleSheet(
        "QTableWidget {"
        "  background: rgba(10, 10, 30, 0.5);"
        "  border: 1px solid rgba(255, 255, 0, 0.3);"
        "  border-radius: 10px;"
        "  color: #ffff00;"
        "  font-family: 'Monospace';"
        "  font-size: 10px;"
        "  gridline-color: rgba(0, 255, 255, 0.2);"
        "  selection-background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(255, 255, 0, 0.4), stop:1 rgba(255, 0, 255, 0.4));"
        "}"
        "QHeaderView::section {"
        "  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, "
        "    stop:0 rgba(100, 0, 200, 0.7), stop:1 rgba(0, 100, 200, 0.7));"
        "  color: #00ffff;"
        "  border: 1px solid rgba(0, 255, 255, 0.4);"
        "  padding: 6px;"
        "  font-weight: bold;"
        "  "
        "}"
        "QTableWidget::item {"
        "  padding: 5px;"
        "}"
        "QTableWidget::item:hover {"
        "  background: rgba(255, 255, 0, 0.15);"
        "}"
    );
    history_table->horizontalHeader()->setStretchLastSection(true);
    history_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    history_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    
    history_layout->addWidget(history_label);
    history_layout->addWidget(history_table);
    
    top_splitter->addWidget(history_widget);
    top_splitter->setSizes({300, 700});
    
    main_layout->addWidget(top_splitter, 2);
    
    // Middle: Action buttons
    auto* action_layout = new QHBoxLayout();
    
    run_backup_btn = new QPushButton("▶ RUN BACKUP");
    run_backup_btn->setStyleSheet(
        "QPushButton {"
        "  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, "
        "    stop:0 rgba(0, 200, 0, 0.7), stop:1 rgba(0, 150, 0, 0.7));"
        "  border: 2px solid rgba(0, 255, 0, 0.8);"
        "  border-radius: 12px;"
        "  color: #00ff00;"
        "  font-family: 'Monospace';"
        "  font-size: 12px;"
        "  font-weight: bold;"
        "  padding: 12px 25px;"
        "  "
        "}"
        "QPushButton:hover {"
        "  background: qlineargradient(x1:0, y1:0, x2:0, y2:1, "
        "    stop:0 rgba(0, 255, 0, 0.9), stop:1 rgba(0, 200, 0, 0.9));"
        "  border: 2px solid rgba(0, 255, 0, 1);"
        "}"
        "QPushButton:disabled {"
        "  background: rgba(40, 60, 40, 0.3);"
        "  border: 2px solid rgba(100, 120, 100, 0.3);"
        "  color: rgba(100, 120, 100, 0.5);"
        "  "
        "}"
    );
    
    restore_btn = new QPushButton("◀ RESTORE");
    restore_btn->setStyleSheet(neon_btn_style);
    cleanup_btn = new QPushButton("⟲ CLEANUP");
    cleanup_btn->setStyleSheet(neon_btn_style);
    
    action_layout->addWidget(run_backup_btn);
    action_layout->addWidget(restore_btn);
    action_layout->addWidget(cleanup_btn);
    action_layout->addStretch();
    
    main_layout->addLayout(action_layout);
    
    // Bottom: Progress and log
    auto* progress_group = new QGroupBox("◈ QUANTUM STATUS MATRIX ◈");
    progress_group->setStyleSheet(
        "QGroupBox {"
        "  background: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(180, 0, 180, 0.2), stop:0.5 rgba(0, 180, 180, 0.2), stop:1 rgba(180, 0, 180, 0.2));"
        "  border: 2px solid qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(255, 0, 255, 0.7), stop:0.5 rgba(0, 255, 255, 0.7), stop:1 rgba(255, 0, 255, 0.7));"
        "  border-radius: 15px;"
        "  padding: 25px 15px 15px 15px;"
        "  font-family: 'Monospace';"
        "  font-size: 13px;"
        "  font-weight: bold;"
        "  color: #ff00ff;"
        "  "
        "}"
        "QGroupBox::title {"
        "  subcontrol-origin: margin;"
        "  subcontrol-position: top center;"
        "  padding: 5px 20px;"
        "}"
    );
    auto* shadow3 = new QGraphicsDropShadowEffect();
    shadow3->setBlurRadius(40);
    shadow3->setColor(QColor(255, 0, 255, 120));
    shadow3->setOffset(0, 0);
    progress_group->setGraphicsEffect(shadow3);
    auto* progress_layout = new QVBoxLayout(progress_group);
    
    status_label = new QLabel("◈ SYSTEM READY ◈");
    status_label->setStyleSheet(
        "color: #00ff88; "
        "font-family: 'Monospace'; "
        "font-size: 12px; "
        "font-weight: bold; "
        " "
        "padding: 5px;"
        "background: transparent;"
        "border: none;"
    );
    progress_bar = new QProgressBar();
    progress_bar->setRange(0, 10000);  // 0-10000 for decimal precision (0.01% increments)
    progress_bar->setValue(0);
    progress_bar->setStyleSheet(
        "QProgressBar {"
        "  background: rgba(10, 10, 30, 0.6);"
        "  border: 2px solid rgba(0, 255, 255, 0.5);"
        "  border-radius: 12px;"
        "  text-align: center;"
        "  color: #00ffff;"
        "  font-family: 'Monospace';"
        "  font-size: 12px;"
        "  font-weight: bold;"
        "  "
        "  min-height: 30px;"
        "}"
        "QProgressBar::chunk {"
        "  background: qlineargradient(x1:0, y1:0, x2:1, y2:0, "
        "    stop:0 rgba(255, 0, 255, 0.8), "
        "    stop:0.5 rgba(0, 255, 255, 0.8), "
        "    stop:1 rgba(255, 0, 255, 0.8));"
        "  border-radius: 10px;"
        "}"
    );
    
    log_display = new QTextEdit();
    log_display->setReadOnly(true);
    log_display->setMaximumHeight(150);
    log_display->setStyleSheet(
        "QTextEdit {"
        "  background: rgba(0, 0, 0, 0.7);"
        "  border: 1px solid rgba(0, 255, 136, 0.4);"
        "  border-radius: 8px;"
        "  color: #00ff88;"
        "  font-family: 'Monospace';"
        "  font-size: 10px;"
        "  padding: 8px;"
        "  selection-background-color: rgba(0, 255, 136, 0.3);"
        "}"
    );
    
    progress_layout->addWidget(status_label);
    progress_layout->addWidget(progress_bar);
    progress_layout->addWidget(new QLabel("Log:"));
    progress_layout->addWidget(log_display);
    
    main_layout->addWidget(progress_group, 1);
    
    // Status bar
    statusBar()->showMessage("Ready");
    
    // Connections
    connect(add_job_btn, &QPushButton::clicked, this, &BackupManagerWindow::add_job);
    connect(edit_job_btn, &QPushButton::clicked, this, &BackupManagerWindow::edit_job);
    connect(remove_job_btn, &QPushButton::clicked, this, &BackupManagerWindow::remove_job);
    connect(run_backup_btn, &QPushButton::clicked, this, &BackupManagerWindow::run_backup);
    connect(restore_btn, &QPushButton::clicked, this, &BackupManagerWindow::restore_backup);
    connect(cleanup_btn, &QPushButton::clicked, this, &BackupManagerWindow::cleanup_old);
    connect(job_list, &QListWidget::itemSelectionChanged, this, &BackupManagerWindow::on_job_selected);
    
    on_job_selected();
}

void BackupManagerWindow::load_settings() {
    QSettings settings("BackupManager", "BackupManagerGUI");
    compression_config.load(settings);
    
    restoreGeometry(settings.value("window/geometry").toByteArray());
    restoreState(settings.value("window/state").toByteArray());
}

void BackupManagerWindow::save_settings() {
    QSettings settings("BackupManager", "BackupManagerGUI");
    compression_config.save(settings);
    
    settings.setValue("window/geometry", saveGeometry());
    settings.setValue("window/state", saveState());
}

void BackupManagerWindow::refresh_job_list() {
    job_list->clear();
    
    const auto& jobs = manager.get_jobs();
    for (const auto& job : jobs) {
        QString item_text = QString::fromStdString(job.name);
        if (!job.enabled) {
            item_text += " [Disabled]";
        }
        auto* item = new QListWidgetItem(item_text);
        item->setData(Qt::UserRole, QString::fromStdString(job.name));
        job_list->addItem(item);
    }
}

void BackupManagerWindow::refresh_history() {
    history_table->setRowCount(0);
    
    const auto& history = manager.get_history();
    int row = 0;
    
    // Show last 50 entries
    size_t start = history.size() > 50 ? history.size() - 50 : 0;
    
    for (size_t i = start; i < history.size(); i++) {
        const auto& rec = history[i];
        history_table->insertRow(row);
        
        QDateTime dt = QDateTime::fromSecsSinceEpoch(rec.timestamp);
        history_table->setItem(row, 0, new QTableWidgetItem(dt.toString("yyyy-MM-dd hh:mm:ss")));
        history_table->setItem(row, 1, new QTableWidgetItem(QString::fromStdString(rec.job_name)));
        history_table->setItem(row, 2, new QTableWidgetItem(QString::fromStdString(dvx3::format_size(rec.compressed_size))));
        
        QString ratio = rec.success ? QString::number(rec.compression_ratio(), 'f', 1) + "%" : "-";
        history_table->setItem(row, 3, new QTableWidgetItem(ratio));
        
        QString status = rec.success ? "✓ Success" : "✗ Failed";
        auto* status_item = new QTableWidgetItem(status);
        if (!rec.success) {
            status_item->setForeground(Qt::red);
        } else {
            status_item->setForeground(Qt::darkGreen);
        }
        history_table->setItem(row, 4, status_item);
        
        row++;
    }
    
    history_table->scrollToBottom();
}

void BackupManagerWindow::update_status() {
    statusBar()->showMessage(QString("Jobs: %1 | History entries: %2")
        .arg(manager.get_jobs().size())
        .arg(manager.get_history().size()));
}

void BackupManagerWindow::add_job() {
    JobConfigDialog dialog(this);
    if (dialog.exec() == QDialog::Accepted) {
        try {
            auto job = dialog.get_job();
            compression_config = dialog.get_compression_config();
            manager.add_job(job);
            refresh_job_list();
            update_status();
            log_display->append(QString("Added job: %1").arg(QString::fromStdString(job.name)));
        } catch (const std::exception& e) {
            QMessageBox::critical(this, "Error", QString("Failed to add job: %1").arg(e.what()));
        }
    }
}

void BackupManagerWindow::edit_job() {
    auto* item = job_list->currentItem();
    if (!item) return;
    
    QString job_name = item->data(Qt::UserRole).toString();
    const auto& jobs = manager.get_jobs();
    
    for (const auto& job : jobs) {
        if (job.name == job_name.toStdString()) {
            JobConfigDialog dialog(this, &job);
            if (dialog.exec() == QDialog::Accepted) {
                try {
                    manager.remove_job(job.name);
                    auto new_job = dialog.get_job();
                    compression_config = dialog.get_compression_config();
                    manager.add_job(new_job);
                    refresh_job_list();
                    log_display->append(QString("Updated job: %1").arg(QString::fromStdString(new_job.name)));
                } catch (const std::exception& e) {
                    QMessageBox::critical(this, "Error", QString("Failed to update job: %1").arg(e.what()));
                }
            }
            break;
        }
    }
}

void BackupManagerWindow::remove_job() {
    auto* item = job_list->currentItem();
    if (!item) return;
    
    QString job_name = item->data(Qt::UserRole).toString();
    
    // Check if this job is currently running
    if (operation_running) {
        QMessageBox::warning(this, "Operation in Progress", 
            "Cannot remove job while a backup or restore operation is running.\n"
            "Please wait for the operation to complete.");
        return;
    }
    
    auto reply = QMessageBox::question(this, "Confirm", 
        QString("Remove backup job '%1'?").arg(job_name),
        QMessageBox::Yes | QMessageBox::No);
    
    if (reply == QMessageBox::Yes) {
        try {
            manager.remove_job(job_name.toStdString());
            refresh_job_list();
            update_status();
            log_display->append(QString("Removed job: %1").arg(job_name));
        } catch (const std::exception& e) {
            QMessageBox::critical(this, "Error", QString("Failed to remove job: %1").arg(e.what()));
        }
    }
}

void BackupManagerWindow::run_backup() {
    auto* item = job_list->currentItem();
    if (!item || operation_running) return;
    
    QString job_name = item->data(Qt::UserRole).toString();
    
    operation_running = true;
    run_backup_btn->setEnabled(false);
    edit_job_btn->setEnabled(false);
    remove_job_btn->setEnabled(false);
    progress_bar->setValue(0);
    status_label->setText(QString("Running backup: %1...").arg(job_name));
    log_display->append(QString("\n=== Starting backup: %1 ===").arg(job_name));
    
    // TODO: Use compression_config to build tar/zstd command with custom options
    
    auto start_time = std::chrono::steady_clock::now();
    uint64_t last_proc = 0;
    auto last_update = start_time;
    
    backup_thread = std::make_unique<std::thread>([this, job_name, start_time, last_proc, last_update]() mutable {
        try {
            auto record = manager.run_backup(job_name.toStdString(),
                [this, &start_time, &last_proc, &last_update](uint64_t proc, uint64_t tot, uint64_t out) {
                    // Calculate percentage with 2 decimal precision
                    double pct_double = tot > 0 ? ((double)proc / tot * 100.0) : 0.0;
                    if (pct_double > 100.0) pct_double = 100.0;
                    int pct_scaled = (int)(pct_double * 100.0);  // Scale to 0-10000
                    
                    auto now = std::chrono::steady_clock::now();
                    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start_time).count();
                    
                    // Calculate speed and ETA
                    QString eta_str = "calculating...";
                    QString speed_str = "";
                    
                    if (elapsed > 0 && proc > 0) {
                        double bytes_per_sec = (double)proc / elapsed;
                        speed_str = QString::fromStdString(dvx3::format_size((uint64_t)bytes_per_sec)) + "/s";
                        
                        if (tot > 0 && proc < tot) {
                            uint64_t remaining = tot - proc;
                            int eta_seconds = (int)(remaining / bytes_per_sec);
                            int eta_minutes = eta_seconds / 60;
                            int eta_hours = eta_minutes / 60;
                            
                            if (eta_hours > 0) {
                                eta_str = QString("%1h %2m").arg(eta_hours).arg(eta_minutes % 60);
                            } else if (eta_minutes > 0) {
                                eta_str = QString("%1m %2s").arg(eta_minutes).arg(eta_seconds % 60);
                            } else {
                                eta_str = QString("%1s").arg(eta_seconds);
                            }
                        } else {
                            eta_str = "finishing...";
                        }
                    }
                    
                    // Format elapsed time
                    QString elapsed_str;
                    if (elapsed >= 3600) {
                        elapsed_str = QString("%1h %2m").arg(elapsed / 3600).arg((elapsed % 3600) / 60);
                    } else if (elapsed >= 60) {
                        elapsed_str = QString("%1m %2s").arg(elapsed / 60).arg(elapsed % 60);
                    } else {
                        elapsed_str = QString("%1s").arg(elapsed);
                    }
                    
                    QMetaObject::invokeMethod(this, [this, pct_scaled, pct_double, proc, tot, out, speed_str, eta_str, elapsed_str]() {
                        progress_bar->setValue(pct_scaled);
                        progress_bar->setFormat(QString("%1%").arg(pct_double, 0, 'f', 2));
                        
                        QString status = QString("%1 / %2 → %3 | %4 | Elapsed: %5")
                            .arg(QString::fromStdString(dvx3::format_size(proc)))
                            .arg(QString::fromStdString(dvx3::format_size(tot)))
                            .arg(QString::fromStdString(dvx3::format_size(out)))
                            .arg(speed_str)
                            .arg(elapsed_str);
                        
                        if (pct_double < 100.0) {
                            status += QString(" | ETA: %1").arg(eta_str);
                        }
                        
                        status_label->setText(status);
                    }, Qt::QueuedConnection);
                    
                    last_proc = proc;
                    last_update = now;
                });
            
            QMetaObject::invokeMethod(this, [this, record]() {
                operation_running = false;
                run_backup_btn->setEnabled(true);
                edit_job_btn->setEnabled(true);
                remove_job_btn->setEnabled(true);
                progress_bar->setValue(10000);
                progress_bar->setFormat("100.00%");
                
                if (record.success) {
                    status_label->setText("Backup completed successfully!");
                    log_display->append(QString("✓ Backup completed"));
                    log_display->append(QString("  Archive: %1").arg(QString::fromStdString(record.archive_path)));
                    log_display->append(QString("  Size: %1 → %2 (%3% saved)")
                        .arg(QString::fromStdString(dvx3::format_size(record.original_size)))
                        .arg(QString::fromStdString(dvx3::format_size(record.compressed_size)))
                        .arg(record.compression_ratio(), 0, 'f', 1));
                } else {
                    status_label->setText("Backup failed!");
                    log_display->append(QString("✗ Backup failed: %1").arg(QString::fromStdString(record.error_message)));
                }
                
                refresh_history();
                update_status();
                on_job_selected(); // Re-enable buttons based on selection
            }, Qt::QueuedConnection);
            
        } catch (const std::exception& e) {
            QMetaObject::invokeMethod(this, [this, e]() {
                operation_running = false;
                run_backup_btn->setEnabled(true);
                edit_job_btn->setEnabled(true);
                remove_job_btn->setEnabled(true);
                QMessageBox::critical(this, "Error", QString("Backup failed: %1").arg(e.what()));
                log_display->append(QString("✗ Error: %1").arg(e.what()));
                on_job_selected(); // Re-enable buttons based on selection
            }, Qt::QueuedConnection);
        }
    });
    backup_thread->detach();
}

void BackupManagerWindow::restore_backup() {
    const auto& history = manager.get_history();
    
    if (history.empty()) {
        QMessageBox::information(this, "No Backups", "No backups available for restoration.");
        return;
    }

    // Create restore dialog
    QDialog dialog(this);
    dialog.setWindowTitle("Restore Backup");
    dialog.setMinimumWidth(600);
    
    auto* layout = new QVBoxLayout(&dialog);
    
    // Recent backups list
    auto* label = new QLabel("<b>Select backup to restore:</b>");
    layout->addWidget(label);
    
    auto* backup_table = new QTableWidget();
    backup_table->setColumnCount(4);
    backup_table->setHorizontalHeaderLabels({"Date/Time", "Job", "Size", "Archive Path"});
    backup_table->horizontalHeader()->setStretchLastSection(true);
    backup_table->setSelectionBehavior(QAbstractItemView::SelectRows);
    backup_table->setSelectionMode(QAbstractItemView::SingleSelection);
    backup_table->setEditTriggers(QAbstractItemView::NoEditTriggers);
    
    // Show last 20 successful backups
    std::vector<const backup::BackupRecord*> recent;
    for (auto it = history.rbegin(); it != history.rend() && recent.size() < 20; ++it) {
        if (it->success) {
            recent.push_back(&(*it));
        }
    }
    
    int row = 0;
    for (const auto* rec : recent) {
        backup_table->insertRow(row);
        
        QDateTime dt = QDateTime::fromSecsSinceEpoch(rec->timestamp);
        backup_table->setItem(row, 0, new QTableWidgetItem(dt.toString("yyyy-MM-dd hh:mm:ss")));
        backup_table->setItem(row, 1, new QTableWidgetItem(QString::fromStdString(rec->job_name)));
        backup_table->setItem(row, 2, new QTableWidgetItem(QString::fromStdString(dvx3::format_size(rec->compressed_size))));
        
        auto* path_item = new QTableWidgetItem(QString::fromStdString(rec->archive_path));
        path_item->setData(Qt::UserRole, QString::fromStdString(rec->archive_path));
        backup_table->setItem(row, 3, path_item);
        
        row++;
    }
    
    if (recent.empty()) {
        QMessageBox::information(this, "No Backups", "No successful backups found.");
        return;
    }
    
    backup_table->selectRow(0);
    layout->addWidget(backup_table);
    
    // Or manual path input
    auto* manual_group = new QGroupBox("Or enter archive path manually:");
    auto* manual_layout = new QHBoxLayout(manual_group);
    
    auto* archive_edit = new QLineEdit();
    archive_edit->setPlaceholderText("/path/to/backup.dvx3");
    auto* browse_btn = new QPushButton("Browse...");
    
    manual_layout->addWidget(archive_edit);
    manual_layout->addWidget(browse_btn);
    layout->addWidget(manual_group);
    
    // Restore destination
    auto* dest_group = new QGroupBox("Restore destination:");
    auto* dest_layout = new QHBoxLayout(dest_group);
    
    auto* dest_edit = new QLineEdit();
    dest_edit->setPlaceholderText("/path/to/restore/location");
    auto* browse_dest_btn = new QPushButton("Browse...");
    
    dest_layout->addWidget(dest_edit);
    dest_layout->addWidget(browse_dest_btn);
    layout->addWidget(dest_group);
    
    // Password
    auto* pass_layout = new QFormLayout();
    auto* password_edit = new QLineEdit();
    password_edit->setEchoMode(QLineEdit::Password);
    password_edit->setPlaceholderText("Enter backup password");
    pass_layout->addRow("Password:", password_edit);
    layout->addLayout(pass_layout);
    
    // Buttons
    auto* btn_layout = new QHBoxLayout();
    auto* restore_now_btn = new QPushButton("Restore");
    auto* cancel_btn = new QPushButton("Cancel");
    restore_now_btn->setDefault(true);
    
    btn_layout->addStretch();
    btn_layout->addWidget(restore_now_btn);
    btn_layout->addWidget(cancel_btn);
    layout->addLayout(btn_layout);
    
    // Connect browse buttons
    connect(browse_btn, &QPushButton::clicked, [&]() {
        QString file = QFileDialog::getOpenFileName(&dialog, "Select Backup Archive",
                                                     QString(), "DVX3 Archives (*.dvx3);;All Files (*)");
        if (!file.isEmpty()) {
            archive_edit->setText(file);
        }
    });
    
    connect(browse_dest_btn, &QPushButton::clicked, [&]() {
        QString dir = QFileDialog::getExistingDirectory(&dialog, "Select Restore Destination");
        if (!dir.isEmpty()) {
            dest_edit->setText(dir);
        }
    });
    
    // Select from table populates manual field
    connect(backup_table, &QTableWidget::itemSelectionChanged, [&]() {
        auto selected = backup_table->selectedItems();
        if (!selected.isEmpty()) {
            int row = backup_table->currentRow();
            if (row >= 0) {
                QString path = backup_table->item(row, 3)->data(Qt::UserRole).toString();
                archive_edit->setText(path);
            }
        }
    });
    
    connect(cancel_btn, &QPushButton::clicked, &dialog, &QDialog::reject);
    
    connect(restore_now_btn, &QPushButton::clicked, [&]() {
        QString archive = archive_edit->text().trimmed();
        QString dest = dest_edit->text().trimmed();
        QString password = password_edit->text();
        
        if (archive.isEmpty()) {
            QMessageBox::warning(&dialog, "Missing Information", "Please select or enter an archive path.");
            return;
        }
        
        if (dest.isEmpty()) {
            QMessageBox::warning(&dialog, "Missing Information", "Please enter a restore destination.");
            return;
        }
        
        if (password.isEmpty()) {
            QMessageBox::warning(&dialog, "Missing Information", "Please enter the backup password.");
            return;
        }
        
        dialog.accept();
        
        // Perform restore
        operation_running = true;
        run_backup_btn->setEnabled(false);
        this->restore_btn->setEnabled(false);
        edit_job_btn->setEnabled(false);
        remove_job_btn->setEnabled(false);
        progress_bar->setValue(0);
        status_label->setText("Restoring backup...");
        log_display->append(QString("\n=== Restoring from: %1 ===").arg(archive));
        
        auto start_time = std::chrono::steady_clock::now();
        
        backup_thread = std::make_unique<std::thread>([this, archive, dest, password, start_time]() mutable {
            try {
                manager.restore_backup(archive.toStdString(), dest.toStdString(), password.toStdString(),
                    [this, start_time](uint64_t proc, uint64_t tot, uint64_t out) {
                        double pct_double = tot > 0 ? ((double)proc / tot * 100.0) : 0.0;
                        if (pct_double > 100.0) pct_double = 100.0;
                        int pct_scaled = (int)(pct_double * 100.0);
                        
                        auto now = std::chrono::steady_clock::now();
                        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start_time).count();
                        
                        QString speed_str = "";
                        QString eta_str = "calculating...";
                        
                        if (elapsed > 0 && proc > 0) {
                            double bytes_per_sec = (double)proc / elapsed;
                            speed_str = QString::fromStdString(dvx3::format_size((uint64_t)bytes_per_sec)) + "/s";
                            
                            if (tot > 0 && proc < tot) {
                                uint64_t remaining = tot - proc;
                                int eta_seconds = (int)(remaining / bytes_per_sec);
                                int eta_minutes = eta_seconds / 60;
                                
                                if (eta_minutes > 0) {
                                    eta_str = QString("%1m %2s").arg(eta_minutes).arg(eta_seconds % 60);
                                } else {
                                    eta_str = QString("%1s").arg(eta_seconds);
                                }
                            }
                        }
                        
                        QMetaObject::invokeMethod(this, [this, pct_scaled, pct_double, proc, tot, speed_str, eta_str]() {
                            progress_bar->setValue(pct_scaled);
                            progress_bar->setFormat(QString("%1%").arg(pct_double, 0, 'f', 2));
                            QString status = QString("Decrypting: %1 / %2 | %3")
                                .arg(QString::fromStdString(dvx3::format_size(proc)))
                                .arg(QString::fromStdString(dvx3::format_size(tot)))
                                .arg(speed_str);
                            if (pct_double < 100.0 && eta_str != "calculating...") {
                                status += QString(" | ETA: %1").arg(eta_str);
                            }
                            status_label->setText(status);
                        }, Qt::QueuedConnection);
                    });
                
                auto end = std::chrono::steady_clock::now();
                auto duration = std::chrono::duration_cast<std::chrono::seconds>(end - start_time);
                
                QMetaObject::invokeMethod(this, [this, dest, duration]() {
                    operation_running = false;
                    run_backup_btn->setEnabled(true);
                    this->restore_btn->setEnabled(true);
                    edit_job_btn->setEnabled(true);
                    remove_job_btn->setEnabled(true);
                    progress_bar->setValue(10000);
                    progress_bar->setFormat("100.00%");
                    status_label->setText("Restore completed successfully!");
                    log_display->append("✓ Restore completed successfully!");
                    log_display->append(QString("  Restored to: %1").arg(dest));
                    log_display->append(QString("  Time: %1s").arg(duration.count()));
                    
                    QMessageBox::information(this, "Success", 
                        QString("Backup restored successfully to:\n%1").arg(dest));
                    on_job_selected(); // Re-enable buttons based on selection
                }, Qt::QueuedConnection);
                
                
            } catch (const std::exception& ex) {
                std::string error_msg = ex.what();
                QMetaObject::invokeMethod(this, [this, error_msg]() {
                    operation_running = false;
                    run_backup_btn->setEnabled(true);
                    this->restore_btn->setEnabled(true);
                    edit_job_btn->setEnabled(true);
                    remove_job_btn->setEnabled(true);
                    status_label->setText("Restore failed!");
                    log_display->append(QString("✗ Restore failed: %1").arg(QString::fromStdString(error_msg)));
                    QMessageBox::critical(this, "Restore Failed", 
                        QString("Failed to restore backup:\n%1").arg(QString::fromStdString(error_msg)));
                    on_job_selected(); // Re-enable buttons based on selection
                }, Qt::QueuedConnection);
            }
        });
        backup_thread->detach();
    });
    
    dialog.exec();
}

void BackupManagerWindow::cleanup_old() {
    auto reply = QMessageBox::question(this, "Confirm", 
        "Remove old backups according to retention policies?",
        QMessageBox::Yes | QMessageBox::No);
    
    if (reply == QMessageBox::Yes) {
        try {
            manager.cleanup_old_backups();
            log_display->append("✓ Cleanup completed");
            refresh_history();
        } catch (const std::exception& e) {
            QMessageBox::critical(this, "Error", QString("Cleanup failed: %1").arg(e.what()));
        }
    }
}

void BackupManagerWindow::show_settings() {
    SettingsDialog dialog(&compression_config, this);
    if (dialog.exec() == QDialog::Accepted) {
        save_settings();
    }
}

void BackupManagerWindow::show_about() {
    AboutDialog dialog(this);
    dialog.exec();
}

void BackupManagerWindow::on_job_selected() {
    bool has_selection = job_list->currentItem() != nullptr;
    edit_job_btn->setEnabled(has_selection && !operation_running);
    remove_job_btn->setEnabled(has_selection && !operation_running);
    run_backup_btn->setEnabled(has_selection && !operation_running);
}

void BackupManagerWindow::update_progress() {
    // Periodic update placeholder
}

// SettingsDialog implementation
SettingsDialog::SettingsDialog(CompressionConfig* config, QWidget* parent)
    : QDialog(parent), config(config) {
    setWindowTitle("Compression & Archive Settings");
    setMinimumWidth(500);
    
    auto* layout = new QVBoxLayout(this);
    
    auto* form_layout = new QFormLayout();
    
    zstd_level_spin = new QSpinBox();
    zstd_level_spin->setRange(1, 22);
    zstd_level_spin->setValue(config->zstd_level);
    zstd_level_spin->setToolTip("Compression level: 1=fast/large, 22=slow/small (recommended: 3)");
    
    zstd_threads_spin = new QSpinBox();
    zstd_threads_spin->setRange(0, 64);
    zstd_threads_spin->setValue(config->zstd_threads);
    zstd_threads_spin->setSpecialValueText("Auto");
    zstd_threads_spin->setToolTip("Number of threads for compression (0=auto detect)");
    
    tar_preserve_permissions_check = new QCheckBox("Preserve file permissions");
    tar_preserve_permissions_check->setChecked(config->tar_preserve_permissions);
    
    tar_preserve_owner_check = new QCheckBox("Preserve owner/group");
    tar_preserve_owner_check->setChecked(config->tar_preserve_owner);
    
    tar_follow_symlinks_check = new QCheckBox("Follow symbolic links");
    tar_follow_symlinks_check->setChecked(config->tar_follow_symlinks);
    
    tar_exclude_hidden_check = new QCheckBox("Exclude hidden files (.*) ");
    tar_exclude_hidden_check->setChecked(config->tar_exclude_hidden);
    
    tar_exclude_patterns_edit = new QTextEdit();
    tar_exclude_patterns_edit->setMaximumHeight(100);
    QString patterns;
    for (const auto& p : config->tar_exclude_patterns) {
        patterns += QString::fromStdString(p) + "\n";
    }
    tar_exclude_patterns_edit->setPlainText(patterns);
    tar_exclude_patterns_edit->setPlaceholderText("One pattern per line, e.g.:\n*.tmp\n*.log\n__pycache__\nnode_modules");
    
    form_layout->addRow("Zstd Compression Level:", zstd_level_spin);
    form_layout->addRow("Compression Threads:", zstd_threads_spin);
    form_layout->addRow("", new QLabel("<b>Tar Archive Options:</b>"));
    form_layout->addRow("", tar_preserve_permissions_check);
    form_layout->addRow("", tar_preserve_owner_check);
    form_layout->addRow("", tar_follow_symlinks_check);
    form_layout->addRow("", tar_exclude_hidden_check);
    form_layout->addRow("Exclude Patterns:", tar_exclude_patterns_edit);
    
    layout->addLayout(form_layout);
    
    auto* btn_layout = new QHBoxLayout();
    auto* ok_btn = new QPushButton("OK");
    auto* cancel_btn = new QPushButton("Cancel");
    
    btn_layout->addStretch();
    btn_layout->addWidget(ok_btn);
    btn_layout->addWidget(cancel_btn);
    
    layout->addLayout(btn_layout);
    
    connect(ok_btn, &QPushButton::clicked, this, &QDialog::accept);
    connect(cancel_btn, &QPushButton::clicked, this, &QDialog::reject);
}

void SettingsDialog::accept() {
    config->zstd_level = zstd_level_spin->value();
    config->zstd_threads = zstd_threads_spin->value();
    config->tar_preserve_permissions = tar_preserve_permissions_check->isChecked();
    config->tar_preserve_owner = tar_preserve_owner_check->isChecked();
    config->tar_follow_symlinks = tar_follow_symlinks_check->isChecked();
    config->tar_exclude_hidden = tar_exclude_hidden_check->isChecked();
    
    QString patterns = tar_exclude_patterns_edit->toPlainText();
    QStringList lines = patterns.split('\n', Qt::SkipEmptyParts);
    config->tar_exclude_patterns.clear();
    for (const QString& line : lines) {
        QString trimmed = line.trimmed();
        if (!trimmed.isEmpty()) {
            config->tar_exclude_patterns.push_back(trimmed.toStdString());
        }
    }
    
    QDialog::accept();
}

// AboutDialog implementation
AboutDialog::AboutDialog(QWidget* parent)
    : QDialog(parent) {
    setWindowTitle("About Backup Manager");
    setFixedSize(400, 300);
    
    auto* layout = new QVBoxLayout(this);
    
    auto* title = new QLabel("<h2>Backup Manager</h2>");
    title->setAlignment(Qt::AlignCenter);
    
    auto* version = new QLabel("<b>Version 1.0</b>");
    version->setAlignment(Qt::AlignCenter);
    
    auto* desc = new QLabel(
        "A comprehensive backup management system with "
        "encrypted, compressed backups.\n\n"
        "Features:\n"
        "• Argon2id + XSalsa20-Poly1305 encryption\n"
        "• Zstd compression with configurable levels\n"
        "• Flexible tar archive options\n"
        "• Retention policies\n"
        "• Backup history tracking\n"
        "• Progress monitoring"
    );
    desc->setWordWrap(true);
    desc->setMargin(10);
    
    auto* tech = new QLabel(
        "<small>Built with: Vala, C++17, Qt6, libsodium</small>"
    );
    tech->setAlignment(Qt::AlignCenter);
    
    auto* close_btn = new QPushButton("Close");
    connect(close_btn, &QPushButton::clicked, this, &QDialog::accept);
    
    layout->addWidget(title);
    layout->addWidget(version);
    layout->addWidget(desc);
    layout->addStretch();
    layout->addWidget(tech);
    layout->addWidget(close_btn);
}

} // namespace backup_gui

// Main entry point
int main(int argc, char** argv) {
    QApplication app(argc, argv);
    
    app.setApplicationName("Backup Manager");
    app.setOrganizationName("BackupManager");
    
    // Set config directory
    QString config_dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/backup-manager";
    QDir().mkpath(config_dir);
    QDir::setCurrent(config_dir);
    
    backup_gui::BackupManagerWindow window;
    window.show();
    
    return app.exec();
}
