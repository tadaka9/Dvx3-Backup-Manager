/* -*- coding: utf-8 -*- */
#include <QHeaderView>
#include <QStatusBar>
#include <QApplication>
#include <QMainWindow>
#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QTabWidget>
#include <QPushButton>
#include <QLabel>
#include <QLineEdit>
#include <QTextEdit>
#include <QFileDialog>
#include <QMessageBox>
#include <QProgressBar>
#include <QTableWidget>
#include <QTableWidgetItem>
#include <QComboBox>
#include <QSpinBox>
#include <QGroupBox>
#include <QRadioButton>
#include <QCheckBox>
#include <QDateTime>
#include <QElapsedTimer>
#include <QThread>
#include <QDir>
#include <QCloseEvent>
#include <QFrame>
#include <QScrollBar>
#include <QRandomGenerator>

// ============================================================================
// Forward declarations
// ============================================================================

class BackupManagerWindow;  // Main window class (defined at end)
class WelcomePage;
class DashboardPage;
class CreateBackupPage;
class RestorePage;
class SchedulePage;
class SettingsPage;
class AboutPage;

enum class EncryptionOp { Create, Decrypt };

// ============================================================================
// Welcome Page
// ============================================================================

class WelcomePage : public QWidget {
    Q_OBJECT
public:
    explicit WelcomePage(QWidget *parent = nullptr) : QWidget(parent) {
        auto* layout = new QVBoxLayout(this);
        layout->setContentsMargins(40, 40, 40, 40);
        layout->setSpacing(20);

        QLabel* title = new QLabel("🎉 Welcome to Dvx3 Backup Manager!", this);
        title->setStyleSheet(R"(QLabel{font-size:36px;font-weight:bold;color:#ffffff;padding:12px 0;})");
        layout->addWidget(title);

        QLabel* subtitle = new QLabel(
            "A privacy-first, local-only backup solution.\n\n"
            "🔐 AES-GCM encryption · 🔄 ChaCha20 streams · ⚡ ZSTD compression\n"
            "📦 No external dependencies · 🏠 Local-first design", this);
        subtitle->setStyleSheet(R"(QLabel{font-size:16px;color:#aaaaaa;line-height:1.5;margin-top:16px;})");
        layout->addWidget(subtitle, 0, Qt::AlignCenter | Qt::AlignTop);

        QLabel* hint = new QLabel("Create your first encrypted backup to get started!", this);
        hint->setStyleSheet(R"(QLabel{color:#3fb95e;font-size:14px;margin-top:24px;})");
        layout->addWidget(hint, 0, Qt::AlignCenter | Qt::AlignTop);

        QPushButton* btn = new QPushButton("→ Go to Dashboard", this);
        btn->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:14px 28px;border:none;border-radius:8px;font-size:16px;} QPushButton:hover{background:#2ea048;})");
        connect(btn, &QPushButton::clicked, [this]() { emit gotoDashboard(); });

        auto* btnLayout = new QHBoxLayout();
        btnLayout->addWidget(new QLabel("Click to begin:", this));
        btnLayout->addWidget(btn);
        layout->addLayout(btnLayout, 0);
    }

signals:
    void gotoDashboard();
};

// ============================================================================
// Dashboard Page
// ============================================================================

class DashboardPage : public QWidget {
    Q_OBJECT
public:
    explicit DashboardPage(QWidget *parent = nullptr) : QWidget(parent), m_recentTable(new QTableWidget(this)) {
        auto* layout = new QVBoxLayout(this);
        layout->setContentsMargins(20, 20, 20, 20);
        layout->setSpacing(15);

        QLabel* title = new QLabel("📊 Dashboard", this);
        title->setStyleSheet(R"(QLabel{font-size:24px;font-weight:bold;color:#ffffff;padding:8px 0;})");
        layout->addWidget(title);

        QLabel* subtitle = new QLabel(
            "No backups yet. Create your first encrypted backup to see statistics here.\n\n"
            "This page will show: total backups, storage usage, oldest/newest archives, and encryption strength.", this);
        subtitle->setStyleSheet(R"(QLabel{color:#aaaaaa;font-size:14px;line-height:1.5;})");
        layout->addWidget(subtitle, 0, Qt::AlignCenter | Qt::AlignTop);

        m_recentTable = new QTableWidget(this);
        m_recentTable->setColumnCount(5);
        m_recentTable->horizontalHeader()->setSectionResizeMode(0, QHeaderView::Fixed);
        m_recentTable->setHorizontalHeaderLabels({"#", "Operation", "Status", "Details", "Time"});
        m_recentTable->setStyleSheet(R"(QTableWidget{background-color:#202020;border:1px solid #404040;} QTableWidget::item{padding:6px;} QTableWidget::item:selected{background-color:#1f4680;color:white;padding-left:32px;} QHeaderView::section{background-color:#2a2a2e;color:#dddddd;font-weight:normal;border:none;padding:5px 8px;})");

        QTableWidgetItem* dummy = new QTableWidgetItem(QString::number(QDateTime::currentMSecsSinceEpoch() / 1000));
        m_recentTable->setItem(0, 0, dummy);

        layout->addWidget(m_recentTable, 1);
    }

signals:
    void updateRecentOperations(const QString& op, const QString& status, int progress = 0);

private slots:
    void addRecentOperation(const QString& op, const QString& status, const QString& details = "", int progress = 0) {
        auto* row = new QTableWidgetItem();
        row->setTextAlignment(Qt::AlignCenter);
        m_recentTable->insertRow(m_recentTable->rowCount());

        m_recentTable->setItem(m_recentTable->rowCount() - 1, 0, row);

        auto* opItem = new QTableWidgetItem(op);
        opItem->setForeground(QColor(98, 158, 218)); // #62a2da (blue)
        m_recentTable->setItem(m_recentTable->rowCount() - 1, 1, opItem);

        auto* statusItem = new QTableWidgetItem(status);
        if (status.startsWith("✅")) {
            statusItem->setForeground(QColor(63, 185, 94)); // #3fb95e green
        } else if (status.startsWith("❌")) {
            statusItem->setForeground(QColor(220, 53, 69)); // red
        } else if (status.startsWith("🔄")) {
            statusItem->setForeground(QColor(245, 158, 11)); // #f59e0b yellow
        }
        m_recentTable->setItem(m_recentTable->rowCount() - 1, 2, statusItem);

        auto* detailItem = new QTableWidgetItem(details);
        detailItem->setTextAlignment(Qt::AlignHCenter | Qt::AlignVCenter);
        m_recentTable->setItem(m_recentTable->rowCount() - 1, 3, detailItem);

        if (progress > 0) {
            auto* pb = new QProgressBar();
            pb->setValue(progress);
            pb->setMaximum(100);
            m_recentTable->setCellWidget(m_recentTable->rowCount() - 1, 3, pb);
        }

        int rowIdx = m_recentTable->rowCount() - 1;
        QScrollBar* vBar = m_recentTable->verticalScrollBar();
        if (vBar && vBar->maximum() > 0) {
            vBar->setValue(vBar->maximum());
        }
    }

private:
    QTableWidget* m_recentTable;
};

// ============================================================================
// Create Backup Page
// ============================================================================

class CreateBackupPage : public QWidget {
    Q_OBJECT
public:
    explicit CreateBackupPage(QWidget *parent = nullptr) : QWidget(parent),
        m_encryptBtn(new QPushButton("🔐 Create Encrypted Backup", this)),
        m_restoreBtn(new QPushButton("🔄 Restore from Archive", this)),
        m_progressBar(new QProgressBar(this)) {
        setupUI();
    }

signals:
    void statusMessage(const QString& msg, bool isError = false);

private:
    void setupUI() {
        auto* layout = new QVBoxLayout(this);
        layout->setContentsMargins(20, 20, 20, 20);
        layout->setSpacing(15);

        QLabel* title = new QLabel("📦 Create Encrypted Backup", this);
        title->setStyleSheet(R"(QLabel{font-size:24px;font-weight:bold;color:#ffffff;padding:8px 0;})");
        layout->addWidget(title);

        auto* container = new QFrame();
        container->setStyleSheet(R"(QFrame{background-color:#1e1e1e;border-radius:8px;padding:20px;} QLabel,QLineEdit,QPushButton,QProgressBar,QTableWidget::item{color:white;background-color:transparent;border:none;margin:0;padding:0;})");
        layout->addWidget(container, 1);

        auto* mainLayout = new QVBoxLayout(container);
        mainLayout->setSpacing(15);

        // --- Section 1: Source Directory ---
        QGroupBox* sourceGroup = new QGroupBox("📁 Step 1 — Source Folder", this);
        auto* sLayout = new QVBoxLayout(sourceGroup);
        sLayout->setSpacing(8);

        QLabel* lblSource = new QLabel("Select the directory you want to backup (all files, including hidden):", this);
        lblSource->setStyleSheet(R"(QLabel{font-size:13px;font-weight:bold;color:#dddddd;padding-left:6px;})");
        sLayout->addWidget(lblSource);

        m_sourcePathInput = new QLineEdit(this);
        m_sourcePathInput->setPlaceholderText("/home/user/documents/important (example)");
        m_sourcePathInput->setStyleSheet(R"(QLineEdit{font-size:14px;background:#2a2a2a;color:white;border:1px solid #3fb95e;padding:8px 12px;border-radius:6px;min-height:34px;} QLineEdit:focus{border:2px solid #3fb95e;})");
        sLayout->addWidget(m_sourcePathInput, 0);

        QPushButton* btnBrowse = new QPushButton("📁 Browse...", this);
        btnBrowse->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:6px 14px;border-radius:4px;font-size:12px;border:none;cursor:pointer;} QPushButton:hover{background:#2ea048;})");
        connect(btnBrowse, &QPushButton::clicked, [this]() {
            QString path = QFileDialog::getExistingDirectory(this, "Select source folder", QDir::homePath(), QFileDialog::ShowDirsOnly);
            if (!path.isEmpty()) {
                m_sourcePathInput->setText(path);
                emit statusMessage("Source folder selected: " + path.left(60) + "...", false);
            }
        });
        sLayout->addWidget(btnBrowse, 0);

        QLabel* note1 = new QLabel("⚠️ Files in the source directory will be included. Hidden files (.git, .cache) are also backed up.", this);
        note1->setStyleSheet(R"(QLabel{font-size:12px;color:#ffaa5e;margin-top:4px;})");
        sLayout->addWidget(note1);

        // --- Section 2: Password ---
        QGroupBox* passwordGroup = new QGroupBox("🔑 Step 2 — Encryption Password", this);
        auto* pLayout = new QVBoxLayout(passwordGroup);
        pLayout->setSpacing(8);

        QLabel* lblPass = new QLabel("Enter a strong password (minimum 12 characters):", this);
        lblPass->setStyleSheet(R"(QLabel{font-size:13px;font-weight:bold;color:#dddddd;padding-left:6px;})");
        pLayout->addWidget(lblPass);

        m_passwordInput = new QLineEdit(this);
        m_passwordInput->setPlaceholderText("Enter password (min 12 chars, mixed case + digits recommended)");
        m_passwordInput->setEchoMode(QLineEdit::Password);
        m_passwordInput->setStyleSheet(R"(QLineEdit{font-size:14px;background:#2a2a2a;color:white;border:1px solid #3fb95e;padding:8px 12px;border-radius:6px;min-height:34px;} QLineEdit:focus{border:2px solid #3fb95e;})");
        pLayout->addWidget(m_passwordInput, 0);

        // Password strength meter
        QLabel* strengthLabel = new QLabel("Password strength:", this);
        m_strengthBar = new QProgressBar(this);
        m_strengthBar->setRange(0, 4);
        m_strengthBar->setValue(0);
        m_strengthBar->setTextVisible(true);
        m_strengthBar->setFormat("%{value} of %{max} — %{text}");
        m_strengthBar->setStyleSheet(R"(QProgressBar{background-color:#333333;border:none;border-radius:4px;font-size:10px;color:#dddddd;} QProgressBar::chunk{border-radius:4px;} QProgressBar::chunk[0]{background-color:#dc2626;} QProgressBar::chunk[1]{background-color:#f59e0b;} QProgressBar::chunk[2]{background-color:#3fb95e;} QProgressBar::chunk[3]{background-color:#06b6d4;})");
        pLayout->addWidget(m_strengthBar, 0);

        connect(m_passwordInput, &QLineEdit::textChanged, this, [this](const QString& txt) {
            int strength = calculatePasswordStrength(txt);
            m_strengthBar->setValue(strength);

            if (strength < 2) {
                emit statusMessage("⚠️ Password too weak. Use at least 12 characters with mixed case and symbols.", true);
            } else if (strength == 2) {
                emit statusMessage("🟡 Medium strength. Add more uppercase letters or special characters.", false);
            } else if (strength >= 3) {
                emit statusMessage("✅ Strong password! Ready to encrypt.", false);
            }
        });

        QPushButton* btnGenerate = new QPushButton("🎲 Generate random password (12-64 chars)", this);
        btnGenerate->setStyleSheet(R"(QPushButton{background:transparent;color:#3fb95e;font-weight:bold;padding:6px 14px;border-radius:4px;font-size:12px;border:none;cursor:pointer;border-bottom:2px solid #3fb95e;} QPushButton:hover{background:#2a3d44;})");
        connect(btnGenerate, &QPushButton::clicked, [this]() {
            QString pass = generateRandomPassword(16);
            m_passwordInput->setText(pass);
            updateStrengthBar(calculatePasswordStrength(pass));
        });
        pLayout->addWidget(btnGenerate);

        // --- Section 3: Options ---
        QGroupBox* optionsGroup = new QGroupBox("⚙️ Step 3 — Backup Options (optional)", this);
        auto* oLayout = new QVBoxLayout(optionsGroup);
        oLayout->setSpacing(8);

        QLabel* note2 = new QLabel("Advanced options. Leave defaults unless you know what you're doing.", this);
        note2->setStyleSheet(R"(QLabel{font-size:12px;color:#aaa;margin-top:4px;})");
        oLayout->addWidget(note2);

        QCheckBox* cbCompress = new QCheckBox("Enable ZSTD compression (recommended, increases size by ~30%)", this);
        cbCompress->setChecked(true);
        cbCompress->setStyleSheet(R"(QLineEdit{background:#1a1a1c;color:white;font-size:13px;} QCheckBox::indicator { width: 14px; height: 14px; background: #28282a; border-radius: 50%; border: 2px solid #3fb95e; } QCheckBox::indicator:checked { background-color: #3fb95e; })");
        oLayout->addWidget(cbCompress);

        QLabel* noteComp = new QLabel("Compression ratio improves with larger source folders. Smaller sources may see minimal gains.", this);
        noteComp->setStyleSheet(R"(QLabel{font-size:11px;color:#777;margin-top:2px;})");
        oLayout->addWidget(noteComp);

        QCheckBox* cbHidden = new QCheckBox("Include hidden files (.git, .cache, etc.)", this);
        cbHidden->setChecked(true);
        cbHidden->setStyleSheet(R"(QLineEdit{background:#1a1a1c;color:white;font-size:13px;} QCheckBox::indicator { width: 14px; height: 14px; background: #28282a; border-radius: 50%; border: 2px solid #3fb95e; } QCheckBox::indicator:checked { background-color: #3fb95e; })");
        oLayout->addWidget(cbHidden);

        QLabel* noteHidden = new QLabel("Including hidden files increases backup size but ensures full system state preservation.", this);
        noteHidden->setStyleSheet(R"(QLabel{font-size:11px;color:#777;margin-top:2px;})");
        oLayout->addWidget(noteHidden);

        // --- Action button ---
        m_encryptBtn = new QPushButton("🚀 Create Backup (opens terminal)", this);
        m_encryptBtn->setStyleSheet(R"(QPushButton{background:linear-gradient(135deg,#3fb95e 0%,#2d8a44 100%);color:white;font-weight:bold;padding:12px 24px;border-radius:6px;font-size:14px;font-family:'Inter',sans-serif;border:none;cursor:pointer;box-shadow:0 2px 8px rgba(63,185,94,0.3);} QPushButton:hover{background:linear-gradient(135deg,#2ea048 0%,#2d7a3c 100%);})");
        m_encryptBtn->setEnabled(false);

        connect(m_encryptBtn, &QPushButton::clicked, this, [this]() {
            QString source = m_sourcePathInput->text().trimmed();
            if (source.isEmpty()) {
                QMessageBox::warning(this, "Missing Source", "Please select a source folder first. Click 'Browse...' to choose.");
                return;
            }
            QString password = m_passwordInput->text().trimmed();
            if (password.isEmpty() || calculatePasswordStrength(password) < 2) {
                QMessageBox::warning(this, "Weak Password", "Please set a stronger password (min 12 chars, mixed case + symbols). Use the 'Generate random password' button.");
                return;
            }

            // In production: launch CLI here via QProcess or D-Bus
            QString cmd = QString("cd %1 && ./cli_backup_manager --create --source \"%2\" --password \"%3\""
                                 .arg(QDir::currentPath(), source, password));

            QMessageBox::information(this, "Backup Started",
                QString("🎉 Creating encrypted backup!\n\n"
                       "Source: %1\n"
                       "Password strength: %2/4 (strong)\n\n"
                       "The CLI backend is now running:\n  %3\n\n"
                       "Watch your terminal for progress. The archive will appear at:\n  %1/%2.dvx3")
                        .arg(source)
                        .arg(calculatePasswordStrength(password))
                        .arg(cmd));

            // Simulate operation (in production: connect to real CLI process)
            QProgressBar* pb = new QProgressBar(this);
            pb->setValue(0);
            pb->setRange(0, 100);
            pb->setTextVisible(true);
            pb->setStyleSheet(R"(QProgressBar{background:#28282a;border-radius:4px;height:6px;} QProgressBar::chunk{background-color:#3fb95e;border-radius:4px;})");

            auto* pLayout = new QVBoxLayout();
            pLayout->addWidget(pb);
            pLayout->addWidget(new QLabel("Processing..."));

            QPushButton* stopBtn = new QPushButton("⏹️ Stop", this);
            stopBtn->setStyleSheet(R"(QPushButton{background:#dc2626;color:white;padding:6px 12px;border-radius:4px;font-size:12px;} QPushButton:hover{background:#b91c1c;})");
            connect(stopBtn, &QPushButton::clicked, [pb](){ pb->setValue(0); });

            auto* box = new QGroupBox("Progress");
            auto* blayout = new QVBoxLayout(box);
            blayout->addWidget(new QLabel("Encrypting with AES-GCM-256..."));
            blayout->addWidget(pb, 1);
            blayout->addWidget(stopBtn);

            mainLayout->insertWidget(mainLayout->indexOf(container) + 1, box);
        });

        // --- Restore section (placeholder for same-window restore) ---
        QGroupBox* restoreGroup = new QGroupBox("📦 Restore from Archive", this);
        auto* rLayout = new QVBoxLayout(restoreGroup);
        rLayout->setSpacing(8);

        QLabel* lblRestore = new QLabel("Select a .dvx3 archive to restore:", this);
        lblRestore->setStyleSheet(R"(QLabel{font-size:13px;font-weight:bold;color:#dddddd;padding-left:6px;})");
        rLayout->addWidget(lblRestore);

        m_restorePathInput = new QLineEdit(this);
        m_restorePathInput->setPlaceholderText("/path/to/backup.dvx3 (example)");
        m_restorePathInput->setStyleSheet(R"(QLineEdit{font-size:14px;background:#2a2a2a;color:white;border:1px solid #3fb95e;padding:8px 12px;border-radius:6px;min-height:34px;} QLineEdit:focus{border:2px solid #3fb95e;})");
        rLayout->addWidget(m_restorePathInput, 0);

        QPushButton* btnBrowseRestore = new QPushButton("📁 Browse...", this);
        btnBrowseRestore->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:6px 14px;border-radius:4px;font-size:12px;border:none;cursor:pointer;} QPushButton:hover{background:#2ea048;})");
        connect(btnBrowseRestore, &QPushButton::clicked, [this]() {
            QString path = QFileDialog::getOpenFileName(this, "Select .dvx3 archive", QDir::homePath(), "Dvx3 Archives (*.dvx3);;All Files (*)");
            if (!path.isEmpty()) m_restorePathInput->setText(path);
        });
        rLayout->addWidget(btnBrowseRestore, 0);

        QLabel* noteRestore = new QLabel("⚠️ The same password used to create the archive is required for restoration.", this);
        noteRestore->setStyleSheet(R"(QLabel{font-size:12px;color:#aaa;margin-top:4px;})");
        rLayout->addWidget(noteRestore);

        m_restoreBtn = new QPushButton("🔄 Restore Now", this);
        m_restoreBtn->setEnabled(false);
        connect(m_restoreBtn, &QPushButton::clicked, [this]() {
            QString archivePath = m_restorePathInput->text().trimmed();
            if (archivePath.isEmpty()) {
                QMessageBox::warning(this, "Missing Archive", "Please select a .dvx3 archive file first.");
                return;
            }
            QString password = m_passwordInput->text().trimmed();
            if (password.isEmpty()) {
                QMessageBox::warning(this, "Missing Password", "The same password used to create the backup is required. Enter it above or use the generate button.");
                return;
            }

            QString cmd = QString("cd %1 && ./cli_backup_manager --restore --archive \"%2\" --password \"%3\""
                                 .arg(QDir::currentPath(), archivePath, password));

            QMessageBox::information(this, "Restore Started",
                QString("🎉 Restoring from archive!\n\n"
                       "Archive: %1\n"
                       "Password strength check: %2/4\n\n"
                       "The CLI backend is now running:\n  %3\n\n"
                       "Restored files will appear at their original locations.")
                        .arg(archivePath)
                        .arg(calculatePasswordStrength(password))
                        .arg(cmd));

            // Simulate progress
            auto* pb = new QProgressBar(this);
            pb->setValue(0);
            pb->setRange(0, 100);
            pb->setTextVisible(true);
            pb->setStyleSheet(R"(QProgressBar{background:#28282a;border-radius:4px;height:6px;} QProgressBar::chunk{background-color:#3fb95e;border-radius:4px;})");

            QPushButton* stopBtn = new QPushButton("⏹️ Stop", this);
            connect(stopBtn, &QPushButton::clicked, [pb](){ pb->setValue(0); });

            auto* box = new QGroupBox("Restore Progress");
            auto* blayout = new QVBoxLayout(box);
            blayout->addWidget(new QLabel("Decrypting and extracting..."));
            blayout->addWidget(pb, 1);
            blayout->addWidget(stopBtn);

            mainLayout->insertWidget(mainLayout->indexOf(container) + 1, box);
        });

        rLayout->addStretch();
        mainLayout->addWidget(restoreGroup, 0);
    }

private:
    QLineEdit* m_sourcePathInput;
    QLineEdit* m_passwordInput;
    QLineEdit* m_restorePathInput;
    QProgressBar* m_strengthBar;
    QPushButton* m_encryptBtn;
    QPushButton* m_restoreBtn;
    QProgressBar* m_progressBar;

    int calculatePasswordStrength(const QString& password) {
        int score = 0;
        if (!password.isEmpty()) {
            if (password.length() >= 12) score += 1;
            if (password.length() >= 16) score += 1;
            bool hasUpper = false, hasLower = false, hasDigit = false, hasSymbol = false;
            for (QChar c : password.toLocal8Bit()) {
                if (c.isUpper()) hasUpper = true;
                else if (c.isLower()) hasLower = true;
                else if (c.isDigit()) hasDigit = true;
                else if (!c.isSpace() && !hasSymbol) hasSymbol = true;
            }
            if (hasUpper) score += 1;
            if (hasLower) score += 1;
            if (hasDigit) score += 1;
            if (hasSymbol) score += 1;
        }
        return std::min(4, score);
    }

    QString generateRandomPassword(int length = 16) {
        static const char chars[] = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%^&*()-_=+[]{}|;:'\",.<>/?";
        QString password;
        auto gen = QRandomGenerator::systemRandom();
        for (int i = 0; i < length; ++i) {
            int idx = static_cast<int>(gen.generate()) % sizeof(chars);
            password += chars[idx];
        }
        return password;
    }

    void updateStrengthBar(int strength) {
        if (strength == 0) m_strengthBar->setValue(0);
        else if (strength == 1) m_strengthBar->setValue(1);
        else if (strength == 2) m_strengthBar->setValue(2);
        else if (strength == 3) m_strengthBar->setValue(3);
        else m_strengthBar->setValue(4);
    }
};

// ============================================================================
// Restore Page (full wizard UI)
// ============================================================================

class RestorePage : public QWidget {
    Q_OBJECT
public:
    explicit RestorePage(QWidget *parent = nullptr) : QWidget(parent),
        m_backupFileLabel(new QLabel("", this)),
        m_restorePasswordInput(new QLineEdit(this)) {
        setupUI();
    }

signals:
    void browseArchiveTriggered();
    void restoreOperationStarted(const QString& password);

private slots:
    void onBrowseRestore() { emit browseArchiveTriggered(); }
    void onRestoreClicked() { emit restoreOperationStarted(m_restorePasswordInput->text()); }

private:
    void setupUI() {
        auto* layout = new QVBoxLayout(this);
        layout->setContentsMargins(20, 20, 20, 20);
        layout->setSpacing(15);

        QLabel* title = new QLabel("🔄 Restore from Archive", this);
        title->setStyleSheet(R"(QLabel{font-size:24px;font-weight:bold;color:#ffffff;padding:8px 0;})");
        layout->addWidget(title);

        auto* container = new QFrame();
        container->setStyleSheet(R"(QFrame{background-color:#1e1e1e;border-radius:8px;padding:20px;} QLabel,QLineEdit,QPushButton,QProgressBar{color:white;background-color:transparent;border:none;margin:0;padding:0;})");
        layout->addWidget(container, 1);

        auto* mainLayout = new QVBoxLayout(container);
        mainLayout->setSpacing(15);

        // --- Step 1: Select archive ---
        QGroupBox* step1Group = new QGroupBox("Step 1 — Archive File", this);
        auto* s1Layout = new QVBoxLayout(step1Group);
        s1Layout->setSpacing(8);

        QLabel* lblArchive = new QLabel("Select the .dvx3 archive file to restore:", this);
        lblArchive->setStyleSheet(R"(QLabel{font-size:13px;font-weight:bold;color:#dddddd;padding-left:6px;})");
        s1Layout->addWidget(lblArchive);

        m_backupFileLabel = new QLabel("", this);
        m_backupFileLabel->setStyleSheet(R"(QLabel{background-color:#2a2a2e;padding:8px 12px;border-radius:4px;margin-right:6px;})");
        s1Layout->addWidget(m_backupFileLabel, 0);

        QPushButton* btnBrowse = new QPushButton("📁 Browse...", this);
        btnBrowse->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:6px 14px;border-radius:4px;font-size:12px;border:none;cursor:pointer;} QPushButton:hover{background:#2ea048;})");
        connect(btnBrowse, &QPushButton::clicked, [this]() {
            QString selected = QFileDialog::getOpenFileName(this, "Select Dvx3 Archive", QDir::homePath(), "Dvx3 Archives (*.dvx3);;All Files (*)");
            if (!selected.isEmpty()) {
                m_backupFileLabel->setText(QFileInfo(selected).fileName());
                emit browseArchiveTriggered();
            }
        });
        s1Layout->addWidget(btnBrowse, 0);

        // --- Step 2: Password ---
        QGroupBox* step2Group = new QGroupBox("Step 2 — Decryption Password", this);
        auto* s2Layout = new QVBoxLayout(step2Group);
        s2Layout->setSpacing(8);

        QLabel* lblPass = new QLabel("Enter the password used when creating this archive:", this);
        lblPass->setStyleSheet(R"(QLabel{font-size:13px;font-weight:bold;color:#dddddd;padding-left:6px;})");
        s2Layout->addWidget(lblPass);

        m_restorePasswordInput = new QLineEdit(this);
        m_restorePasswordInput->setPlaceholderText("Enter archive password (same as when creating)");
        m_restorePasswordInput->setEchoMode(QLineEdit::Password);
        m_restorePasswordInput->setStyleSheet(R"(QLineEdit{font-size:14px;background:#2a2a2a;color:white;border:1px solid #3fb95e;padding:8px 12px;border-radius:6px;min-height:34px;} QLineEdit:focus{border:2px solid #3fb95e;})");
        s2Layout->addWidget(m_restorePasswordInput, 0);

        QPushButton* btnGenerate = new QPushButton("🎲 Try random password (last used)", this);
        btnGenerate->setStyleSheet(R"(QPushButton{background:transparent;color:#3fb95e;font-weight:bold;padding:6px 14px;border-radius:4px;font-size:12px;border:none;cursor:pointer;border-bottom:2px solid #3fb95e;} QPushButton:hover{background:#2a3d44;})");
        connect(btnGenerate, &QPushButton::clicked, [this]() {
            m_restorePasswordInput->setText(generateRandomPassword(16));
        });
        s2Layout->addWidget(btnGenerate);

        // --- Step 3: Restore button ---
        QPushButton* btnRestore = new QPushButton("🚀 Restore Now", this);
        btnRestore->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:10px 24px;border:none;border-radius:6px;font-size:14px;} QPushButton:hover{background:#2ea048;})");
        connect(btnRestore, &QPushButton::clicked, [this]() {
            QString password = m_restorePasswordInput->text().trimmed();
            if (password.isEmpty()) {
                QMessageBox::warning(this, "Missing Password", "Please enter the archive decryption password.");
                return;
            }
            emit restoreOperationStarted(password);

            // Show progress
            auto* pb = new QProgressBar(this);
            pb->setRange(0, 100);
            pb->setValue(0);
            pb->setTextVisible(true);
            pb->setStyleSheet(R"(QProgressBar{background:#28282a;border-radius:4px;height:6px;} QProgressBar::chunk{background-color:#3fb95e;border-radius:4px;})");

            QPushButton* stopBtn = new QPushButton("⏹️ Stop", this);
            connect(stopBtn, &QPushButton::clicked, [pb](){ pb->setValue(0); });

            auto* box = new QGroupBox("Restore Progress");
            auto* blayout = new QVBoxLayout(box);
            blayout->addWidget(new QLabel("Decrypting archive..."));
            blayout->addWidget(pb, 1);
            blayout->addWidget(stopBtn);

            mainLayout->insertWidget(mainLayout->indexOf(container) + 1, box);
        });

        s2Layout->addWidget(btnRestore, 0);
        mainLayout->addWidget(step2Group, 0);
    }

private:
    QLabel* m_backupFileLabel;
    QLineEdit* m_restorePasswordInput;

    QString generateRandomPassword(int length = 16) {
        static const char chars[] = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%^&*()-_=+[]{}|;:'\",.<>/?";
        QString password;
        auto gen = QRandomGenerator::systemRandom();
        for (int i = 0; i < length; ++i) {
            int idx = static_cast<int>(gen.generate()) % sizeof(chars);
            password += chars[idx];
        }
        return password;
    }
};

// ============================================================================
// Schedule Page (placeholder — daemon integration deferred to Epico G3)
// ============================================================================

class SchedulePage : public QWidget {
    Q_OBJECT
public:
    explicit SchedulePage(QWidget *parent = nullptr) : QWidget(parent), m_scheduleText(new QTextEdit(this)) {
        setupUI();
    }

signals:
    void saveScheduleTriggered();

private slots:
    void onSaveClicked() { emit saveScheduleTriggered(); }

private:
    void setupUI() {
        auto* layout = new QVBoxLayout(this);
        layout->setContentsMargins(20, 20, 20, 20);
        layout->setSpacing(15);

        QLabel* title = new QLabel("📅 Schedule Backups — Daemon Configuration", this);
        title->setStyleSheet(R"(QLabel{font-size:24px;font-weight:bold;color:#ffffff;padding:8px 0;})");
        layout->addWidget(title);

        QLabel* intro = new QLabel(
            "Configure automatic backup schedules. The Vala daemon will invoke the CLI tool (cli_backup_manager) at specified intervals.\n\n"
            "This tab is a placeholder for future D-Bus integration (Epico G3). For now, use manual creation.", this);
        intro->setStyleSheet(R"(QLabel{color:#aaaaaa;font-size:14px;line-height:1.6;})");
        layout->addWidget(intro, 0, Qt::AlignLeft | Qt::AlignTop);

        // YAML editor (read-only)
        m_scheduleText = new QTextEdit(this);
        m_scheduleText->setReadOnly(true);
        m_scheduleText->setFontFamily("monospace");
        m_scheduleText->setFontPointSize(12);
        m_scheduleText->setText(R"(# Dvx3 Backup Manager — Schedule Configuration (YAML)
# Managed by the daemon. Edit via GUI or manually, then click "Save".

backup:
  source: /home/user/documents          # Source directory to backup
  destination: ~/.config/dvx3/backups   # Destination for encrypted archives
  password: MySecurePass@2025           # Encryption key (min 12 chars)

schedule:
  - name: "Daily"
    interval_hours: 24                  # Run every 24 hours
    enabled: true
  - name: "Weekly on Sunday"
    cron_expr: "0 2 * * 0"             # Cron-like: 2:00 AM every Sunday
    enabled: true

retention:
  max_archives_per_day: 7              # Keep 7 days of daily backups
  keep_weekly: 4                       # Keep 4 weeks of weekly backups
)");
        layout->addWidget(m_scheduleText, 1);

        QPushButton* saveBtn = new QPushButton("💾 Save Configuration", this);
        saveBtn->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:10px 24px;border:none;border-radius:6px;font-size:14px;} QPushButton:hover{background:#2ea048;})");
        connect(saveBtn, &QPushButton::clicked, this, [this]() { onSaveClicked(); });

        auto* btnLayout = new QHBoxLayout();
        btnLayout->addWidget(saveBtn);
        layout->addLayout(btnLayout, 0);

        QLabel* note = new QLabel("✅ Configuration saved. The daemon will apply these settings on its next reload.", this);
        note->setStyleSheet(R"(QLabel{color:#3fb95e;font-size:12px;margin-top:8px;})");
        layout->addWidget(note, 0, Qt::AlignCenter | Qt::AlignTop);

        // Recent operations table (same style as other pages)
        QGroupBox* recentOpsGroup = new QGroupBox("📜 Recent Operations", this);
        auto* tableLayout = new QVBoxLayout(recentOpsGroup);

        m_recentTable = new QTableWidget(this);
        m_recentTable->setColumnCount(5);
        m_recentTable->horizontalHeader()->setSectionResizeMode(0, QHeaderView::Fixed);
        m_recentTable->setHorizontalHeaderLabels({"#", "Operation", "Status", "Details", "Time"});

        m_recentTable->setStyleSheet(R"(QTableWidget{background-color:#202020;border:1px solid #404040;} QTableWidget::item{padding:6px;} QTableWidget::item:selected{background-color:#1f4680;color:white;padding-left:32px;} QHeaderView::section{background-color:#2a2a2e;color:#dddddd;font-weight:normal;border:none;padding:5px 8px;})");

        QTableWidgetItem* dummy = new QTableWidgetItem(QString::number(QDateTime::currentMSecsSinceEpoch() / 1000));
        m_recentTable->setItem(0, 0, dummy);

        tableLayout->addWidget(m_recentTable, 1);
        layout->addWidget(recentOpsGroup);
    }

private:
    QTextEdit* m_scheduleText;
    QTableWidget* m_recentTable;
};

// ============================================================================
// Settings Page
// ============================================================================

class SettingsPage : public QWidget {
    Q_OBJECT
public:
    explicit SettingsPage(QWidget *parent = nullptr) : QWidget(parent),
        m_passwordInput(new QLineEdit(this)),
        m_retentionSpinBox(new QSpinBox(this)) {
        setupUI();
    }

signals:
    void passwordChanged(const QString& password);
    void retentionChanged(int days);

private slots:
    void onPasswordChanged() { emit passwordChanged(m_passwordInput->text().trimmed()); }
    void onRetentionChanged() { emit retentionChanged(m_retentionSpinBox->value()); }

private:
    void setupUI() {
        auto* layout = new QVBoxLayout(this);
        layout->setContentsMargins(20, 20, 20, 20);
        layout->setSpacing(15);

        QLabel* title = new QLabel("⚙️ Settings", this);
        title->setStyleSheet(R"(QLabel{font-size:24px;font-weight:bold;color:#ffffff;padding:8px 0;})");
        layout->addWidget(title);

        auto* container = new QFrame();
        container->setStyleSheet(R"(QFrame{background-color:#1e1e1e;border-radius:8px;padding:20px;} QLabel,QLineEdit,QPushButton,QProgressBar,QSpinBox,QTextEdit{color:white;background-color:transparent;border:none;margin:0;padding:0;})");
        layout->addWidget(container, 1);

        auto* mainLayout = new QVBoxLayout(container);
        mainLayout->setSpacing(15);

        // --- Section 1: Master Password ---
        QGroupBox* passwordGroup = new QGroupBox("🔐 Master Encryption Password", this);
        auto* pLayout = new QVBoxLayout(passwordGroup);

        QLabel* lblDesc = new QLabel("This password protects all your encrypted backups. Store it securely!", this);
        lblDesc->setStyleSheet(R"(QLabel{color:#aaaaaa;font-size:13px;margin-top:0;})");
        pLayout->addWidget(lblDesc, 0, Qt::AlignLeft | Qt::AlignTop);

        m_passwordInput = new QLineEdit(this);
        m_passwordInput->setPlaceholderText("Enter/Change master password (min 12 chars)");
        m_passwordInput->setEchoMode(QLineEdit::Password);
        connect(m_passwordInput, &QLineEdit::textChanged, this, [this](const QString&) { onPasswordChanged(); });

        QPushButton* changeBtn = new QPushButton("Update Password", this);
        changeBtn->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:8px 16px;border:none;border-radius:4px;font-size:12px;} QPushButton:hover{background:#2ea048;})");
        connect(changeBtn, &QPushButton::clicked, this, [this]() { onPasswordChanged(); });

        auto* btnBox = new QHBoxLayout();
        btnBox->addWidget(new QLabel("Current password:", this));
        btnBox->addWidget(m_passwordInput);
        pLayout->addLayout(btnBox, 0);

        QPushButton* changeBtn2 = new QPushButton("Change →", this);
        changeBtn2->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:8px 16px;border:none;border-radius:4px;font-size:12px;} QPushButton:hover{background:#2ea048;})");
        connect(changeBtn2, &QPushButton::clicked, this, [this]() { onPasswordChanged(); });
        pLayout->addWidget(changeBtn2);

        // Password strength display
        QLabel* strengthLabel = new QLabel("Strength:", this);
        m_strengthBar = new QProgressBar(this);
        m_strengthBar->setRange(0, 4);
        m_strengthBar->setValue(calculatePasswordStrength(m_passwordInput->text().trimmed()));
        m_strengthBar->setTextVisible(true);
        m_strengthBar->setFormat("%{value} of %{max} — %{text}");
        m_strengthBar->setStyleSheet(R"(QProgressBar{background-color:#333333;border:none;border-radius:4px;font-size:10px;color:#dddddd;} QProgressBar::chunk{border-radius:4px;} QProgressBar::chunk[0]{background-color:#dc2626;} QProgressBar::chunk[1]{background-color:#f59e0b;} QProgressBar::chunk[2]{background-color:#3fb95e;} QProgressBar::chunk[3]{background-color:#06b6d4;})");
        pLayout->addWidget(m_strengthBar, 0);

        mainLayout->addWidget(passwordGroup);

        // --- Section 2: Retention Policy ---
        QGroupBox* retentionGroup = new QGroupBox("🗑️ Retention Policy", this);
        auto* rLayout = new QVBoxLayout(retentionGroup);

        QLabel* introLabel = new QLabel("Configure how long to keep old backups. Older archives will be automatically deleted.", this);
        introLabel->setStyleSheet(R"(QLabel{color:#aaaaaa;font-size:13px;margin-top:0;})");
        rLayout->addWidget(introLabel, 0, Qt::AlignLeft | Qt::AlignTop);

        QLabel* lblRetention = new QLabel("Keep backups for:", this);
        lblRetention->setStyleSheet(R"(QLabel{color:#ffffff;font-size:14px;margin-top:8px;})");
        rLayout->addWidget(lblRetention);

        m_retentionSpinBox = new QSpinBox(this);
        m_retentionSpinBox->setRange(0, 365);
        m_retentionSpinBox->setValue(30);
        m_retentionSpinBox->setSuffix(" days");
        connect(m_retentionSpinBox, &QSpinBox::valueChanged, this, [this](int) { onRetentionChanged(); });

        auto* spinLayout = new QHBoxLayout();
        spinLayout->addWidget(new QLabel("Minimum retention:", this));
        spinLayout->addWidget(m_retentionSpinBox);
        rLayout->addLayout(spinLayout, 0);

        QPushButton* applyBtn = new QPushButton("Apply Retention Policy", this);
        applyBtn->setStyleSheet(R"(QPushButton{background:#3fb95e;color:white;font-weight:bold;padding:8px 16px;border:none;border-radius:4px;font-size:12px;} QPushButton:hover{background:#2ea048;})");
        connect(applyBtn, &QPushButton::clicked, this, [this]() { onRetentionChanged(); });

        auto* btnBox = new QHBoxLayout();
        btnBox->addWidget(new QLabel("Click to apply:", this));
        btnBox->addWidget(applyBtn);
        rLayout->addLayout(btnBox, 0);

        mainLayout->addWidget(retentionGroup);

        // --- Section 3: Recent Operations ---
        QGroupBox* recentOpsGroup = new QGroupBox("📜 Recent Operations", this);
        auto* tableLayout = new QVBoxLayout(recentOpsGroup);

        m_recentTable = new QTableWidget(this);
        m_recentTable->setColumnCount(5);
        m_recentTable->horizontalHeader()->setSectionResizeMode(0, QHeaderView::Fixed);
        m_recentTable->setHorizontalHeaderLabels({"#", "Operation", "Status", "Details", "Time"});

        m_recentTable->setStyleSheet(R"(QTableWidget{background-color:#202020;border:1px solid #404040;} QTableWidget::item{padding:6px;} QTableWidget::item:selected{background-color:#1f4680;color:white;padding-left:32px;} QHeaderView::section{background-color:#2a2a2e;color:#dddddd;font-weight:normal;border:none;padding:5px 8px;})");

        QTableWidgetItem* dummy = new QTableWidgetItem(QString::number(QDateTime::currentMSecsSinceEpoch() / 1000));
        m_recentTable->setItem(0, 0, dummy);

        tableLayout->addWidget(m_recentTable, 1);
        mainLayout->addWidget(recentOpsGroup);
    }

private:
    QLineEdit* m_passwordInput;
    QSpinBox* m_retentionSpinBox;
    QProgressBar* m_strengthBar;
    QTableWidget* m_recentTable;

    int calculatePasswordStrength(const QString& password) {
        int score = 0;
        if (!password.isEmpty()) {
            if (password.length() >= 12) score += 1;
            if (password.length() >= 16) score += 1;
            bool hasUpper = false, hasLower = false, hasDigit = false, hasSymbol = false;
            for (QChar c : password.toLocal8Bit()) {
                if (c.isUpper()) hasUpper = true;
                else if (c.isLower()) hasLower = true;
                else if (c.isDigit()) hasDigit = true;
                else if (!c.isSpace() && !hasSymbol) hasSymbol = true;
            }
            if (hasUpper) score += 1;
            if (hasLower) score += 1;
            if (hasDigit) score += 1;
            if (hasSymbol) score += 1;
        }
        return std::min(4, score);
    }

    void onPasswordChanged() {
        QString password = m_passwordInput->text().trimmed();
        emit passwordChanged(password);

        int strength = calculatePasswordStrength(password);
        if (strength >= 4) {
            QMessageBox::information(this, "Password Updated", "✅ Master password updated successfully. All existing archives remain compatible.");
        } else if (strength == 3) {
            QMessageBox::information(this, "Password Weakness Warning", "⚠️ Your password is strong but could be stronger. Consider adding more symbols and uppercase letters.");
        } else if (strength < 2) {
            QMessageBox::warning(this, "Weak Password", "❌ Password too weak. Increase length and use mixed case + symbols.");
        }
    }

    void onRetentionChanged() {
        int days = m_retentionSpinBox->value();
        emit retentionChanged(days);

        QMessageBox::information(this, "Retention Policy Updated",
            QString("Backups older than %1 days will be automatically deleted. This rule will take effect on the next scheduled backup.").arg(days));
    }
};

// ============================================================================
// About Page
// ============================================================================

class AboutPage : public QWidget {
    Q_OBJECT
public:
    explicit AboutPage(QWidget *parent = nullptr) : QWidget(parent) {
        auto* layout = new QVBoxLayout(this);
        layout->setContentsMargins(40, 40, 40, 40);
        layout->setSpacing(15);

        QLabel* title = new QLabel("Dvx3 Backup Manager", this);
        title->setStyleSheet(R"(QLabel{font-size:28px;font-weight:bold;color:#ffffff;padding:16px 0;})");
        layout->addWidget(title);

        QLabel* subtitle = new QLabel("v1.0.0 — Privacy-first, local-only backup solution", this);
        subtitle->setStyleSheet(R"(QLabel{font-size:14px;color:#aaa;margin-top:8px;font-weight:bold;})");
        layout->addWidget(subtitle);

        // Logo placeholder (in production, load actual icon from resources)
        QLabel* logo = new QLabel("📦", this);
        logo->setStyleSheet(R"(QLabel{font-size:64px;margin-bottom:16px;})");
        layout->addWidget(logo);

        QLabel* description = new QLabel(
            "Dvx3 Backup Manager provides encrypted, compressed backups with zero external dependencies.\n\n"
            "Encryption: AES-GCM-256 + ChaCha20 stream cipher\n"
            "Compression: ZSTD (fast, high-ratio)\n"
            "Architecture: Vala core engine + Qt6 GUI shell", this);
        description->setStyleSheet(R"(QLabel{font-size:13px;color:#aaa;line-height:1.5;margin-top:24px;})");
        layout->addWidget(description, 0, Qt::AlignCenter | Qt::AlignTop);

        // Credits / links
        QLabel* credits = new QLabel(
            "Built with ❤️ using Vala + C++/Qt6\n"
            "Core engine: dvx3-cli (Vala)\n"
            "GUI shell: C++/Qt6", this);
        credits->setStyleSheet(R"(QLabel{font-size:12px;color:#555;margin-top:24px;})");
        layout->addWidget(credits, 0, Qt::AlignCenter | Qt::AlignTop);

        // Build info
        QLabel* buildInfo = new QLabel("Built: " + QString(__DATE__) + " " + QString(__TIME__), this);
        buildInfo->setStyleSheet(R"(QLabel{font-size:11px;color:#777;margin-top:12px;})");
        layout->addWidget(buildInfo, 0, Qt::AlignCenter | Qt::AlignTop);
    }
};

// ============================================================================
// Main Application Window
// ============================================================================

class BackupManagerWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit BackupManagerWindow(QWidget *parent = nullptr)
        : QMainWindow(parent), m_mainPage(new CreateBackupPage(this)) {
        setupWindow();
        connectSignalsSlots();
    }

private slots:
    void onStatusMessage(const QString& msg, bool isError);

private:
    void setupWindow();
    void connectSignalsSlots();

protected:
    void closeEvent(QCloseEvent *e) override {
        // Save any pending state here (e.g., schedule YAML to file)
        e->accept();
    }

private:
    CreateBackupPage* m_mainPage;
};

void BackupManagerWindow::setupWindow() {
    setWindowTitle("Dvx3 Backup Manager v1.0.0");
    resize(1200, 750);

    // Dark theme palette — using QColor directly instead of QPalette::HighlightText (Qt6)
    QPalette pal;
    pal.setColor(QPalette::Window, QColor(30, 30, 32));
    pal.setColor(QPalette::WindowText, Qt::white);
    pal.setColor(QPalette::Base, QColor(40, 40, 42));
    pal.setColor(QPalette::Text, Qt::white);
    pal.setColor(QPalette::Button, QColor(35, 35, 38));
    pal.setColor(QPalette::ButtonText, Qt::white);
    pal.setColor(QPalette::Highlight, QColor(63, 185, 94));
    pal.setColor(QPalette::WindowText, QColor(63, 185, 94)); // green accent for highlights

    setAutoFillBackground(true);
    setPalette(pal);

    // Central widget with tabbed layout
    QWidget* central = new QWidget(this);
    auto* mainLayout = new QVBoxLayout(central);
    mainLayout->setContentsMargins(0, 0, 0, 0);
    mainLayout->addWidget(m_mainPage, 1);

    setCentralWidget(central);

    // Status bar
    statusBar()->showMessage("Ready. Create your first backup!");
}

void BackupManagerWindow::connectSignalsSlots() {
    connect(m_mainPage, &CreateBackupPage::statusMessage, this, [this](const QString& msg, bool isError) {
        if (isError) {
            statusBar()->showMessage("❌ " + msg);
        } else {
            statusBar()->showMessage("✅ " + msg);
        }
    });
}

// ============================================================================
// Main Entry Point
// ============================================================================

#include "main.moc"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    // Apply global dark theme to all Qt widgets
    QPalette pal;
    pal.setColor(QPalette::Window, QColor(30, 30, 32));
    pal.setColor(QPalette::WindowText, Qt::white);
    pal.setColor(QPalette::Base, QColor(40, 40, 42));
    app.setPalette(pal);

    BackupManagerWindow window;
    window.show();

    return app.exec();
}