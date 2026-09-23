/**
 * Dvx3 Backup Manager - Qt6 Desktop Application
 * 
 * Modern, cross-platform GUI for backup creation and restoration.
 * Integrates with the CLI backend for reliable operations across all platforms.
 */

#include <QApplication>
#include <QMainWindow>
#include <QVBoxLayout>
#include <QPushButton>
#include <QLabel>
#include <QLineEdit>
#include <QFileDialog>
#include <QMessageBox>
#include <QProgressBar>
#include <QProcess>
#include <QSplitter>
#include <QTabWidget>
#include <QGroupBox>
#include <QScrollArea>
#include <QFrame>
#include <QHBoxLayout>
#include <QCheckBox>
#include <QSpinBox>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QAction>
#include <QFont>

// Modern, dark-themed Qt6 application with tabbed interface
// Follows Apple HIG principles for macOS/Windows and provides native Linux experience

class Dvx3BackupApp : public QMainWindow {
    Q_OBJECT

public:
    explicit Dvx3BackupApp(QWidget *parent = nullptr)
        : QMainWindow(parent), backupPath("/backup.dvx3")
    {
        setupUI();
        setupTrayIcon();
        
        statusBar()->showMessage("Dvx3 Backup Manager - Ready");
    }

private:
    void setupUI() {
        setWindowTitle("Dvx3 Backup Manager");
        resize(1200, 800);
        
        // Create tab widget for different sections
        TabWidget = new QTabWidget(this);
        TabWidget->setDocumentMode(true);
        TabWidget->setMovable(false);
        TabWidget->setExpanding(true);
        
        // Welcome Tab
        WelcomeTab = new WelcomePage(TabWidget);
        TabWidget->addTab(WelcomeTab, "🎉 Welcome");
        
        // Backup Tab
        BackupTab = new BackupPage(TabWidget);
        TabWidget->addTab(BackupTab, "📦 Create Backup");
        
        // Restore Tab
        RestoreTab = new RestorePage(TabWidget);
        TabWidget->addTab(RestoreTab, "🔄 Restore");
        
        // Dashboard Tab
        DashboardTab = new DashboardPage(TabWidget);
        TabWidget->addTab(DashboardTab, "📊 Dashboard");
        
        // Settings Tab
        SettingsTab = new SettingsPage();
        TabWidget->addTab(SettingsTab, "⚙️ Settings");
        
        centralWidget()->setLayout(new QVBoxLayout());
        centralWidget()->layout()->addWidget(TabWidget);
    }

private:
    void setupTrayIcon() {
        TrayIcon = new QSystemTrayIcon(this);
        QIcon Icon;
        
        TrayIcon->setContextMenu(TrayMenu);
        
        // Add tray menu items
        ActionBackup = new QAction("📦 Create Backup", this);
        ActionRestore = new QAction("🔄 Restore", this);
        ActionQuit = new QAction("❌ Quit", this);
        
        TrayMenu->addAction(ActionBackup);
        TrayMenu->addSeparator();
        TrayMenu->addAction(ActionRestore);
        TrayMenu->addSeparator();
        TrayMenu->addAction(ActionQuit);
        
        connect(TrayIcon, &QSystemTrayIcon::activated, this, [](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::DoubleClick) {
                showWindow();
                raise();
                activateWindow();
            }
        });
        
        connect(ActionBackup, &QAction::triggered, [this]() {
            if (BackupTab && BackupTab->isVisible() == false) {
                TabWidget->widget(1)->show();
            } else if (BackupTab && BackupTab->isVisible()) {
                BackupTab->setFocus();
            }
        });
        
        connect(ActionRestore, &QAction::triggered, [this]() {
            if (RestoreTab && RestoreTab->isVisible() == false) {
                TabWidget->widget(2)->show();
            } else if (RestoreTab && RestoreTab->isVisible()) {
                RestoreTab->setFocus();
            }
        });
        
        connect(ActionQuit, &QAction::triggered, this, &QWidget::close);
        
        TrayIcon->show();
    }

private slots:
    void onEncrypt() {
        // Validate inputs
        QString sourceDir = backupSourceLabel->text().trimmed();
        if (sourceDir.isEmpty()) {
            QMessageBox::warning(this, "Missing Source", 
                "Please select a source directory first.\nClick 'Browse...' to choose.");
            return;
        }
        
        QString password = backupPasswordLabel->text();
        if (password.isEmpty() || password == "") {
            QMessageBox::warning(this, "Missing Password",
                "Please set an encryption password.\nClick 'Set Password' to continue.");
            return;
        }
        
        // Start encryption process
        QProcess* process = new QProcess(this);
        
        QString exe = qApp->applicationDirPath() + "/cli_backup_manager";
        
        QStringList args;
        args << "encrypt" << sourceDir
              << "-p" << password
              << "-o" << backupPath + ".dvx3";
        
        connect(process, &QProcess::started, [this]() {
            statusBar()->showMessage("Encrypting...", 0);
            progressBar->setMaximum(100);
            progressBar->setValue(0);
        });
        
        connect(process, &QProcess::errorOccurred, this, [process](QProcess::Error error) {
            QMessageBox::critical(this, "Encryption Error",
                process->errorString() + "\n\nError code: " + QString::number(process->exitCode()));
        });
        
        connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
                [process]() {
            if (process->exitCode() == 0) {
                statusBar()->showMessage("✅ Backup completed successfully!", 0);
                
                // Add to dashboard
                if (DashboardTab) {
                    DashboardTab->addRecentOperation("Encrypt", "Success", sourceDir + " -> " + backupPath);
                }
            } else {
                QString error = process->readAllStandardError();
                QMessageBox::critical(this, "Backup Failed", error);
                
                statusBar()->showMessage("❌ Backup failed: " + process->errorString(), 5000);
                if (DashboardTab) {
                    DashboardTab->addRecentOperation("Encrypt", "Error", sourceDir, QString::number(process->exitCode()));
                }
            }
            
            delete process;
        });
        
        process->start(exe, args);
    }

private slots:
    void onRestore() {
        // Validate inputs
        QString backupPath = restoreBackupLabel->text();
        if (backupPath.isEmpty()) {
            QMessageBox::warning(this, "No Backup Selected",
                "Please select a backup archive first.");
            return;
        }
        
        QString password = restorePasswordLabel->text();
        if (password.isEmpty() || password == "") {
            QMessageBox::warning(this, "Missing Password",
                "Please enter the decryption password.");
            return;
        }
        
        // Start restore process
        QProcess* process = new QProcess(this);
        
        QString exe = qApp->applicationDirPath() + "/cli_backup_manager";
        
        QStringList args;
        args << "decrypt" << backupPath
              << "-p" << password
              << "-o" << "/restore"; // Default restore destination
        
        connect(process, &QProcess::started, [this]() {
            statusBar()->showMessage("Restoring...", 0);
            progressBar->setMaximum(100);
            progressBar->setValue(0);
        });
        
        connect(process, &QProcess::errorOccurred, this, [process](QProcess::Error error) {
            QMessageBox::critical(this, "Restore Error",
                process->errorString() + "\n\nError code: " + QString::number(process->exitCode()));
        });
        
        connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
                [process]() {
            if (process->exitCode() == 0) {
                statusBar()->showMessage("✅ Restore completed successfully!", 0);
                
                // Add to dashboard
                if (DashboardTab) {
                    DashboardTab->addRecentOperation("Decrypt", "Success", backupPath);
                }
            } else {
                QString error = process->readAllStandardError();
                QMessageBox::critical(this, "Restore Failed", error);
                
                statusBar()->showMessage("❌ Restore failed: " + process->errorString(), 5000);
                if (DashboardTab) {
                    DashboardTab->addRecentOperation("Decrypt", "Error", backupPath, QString::number(process->exitCode()));
                }
            }
            
            delete process;
        });
        
        process->start(exe, args);
    }

private:
    // UI components for Welcome tab
    class WelcomePage : public QWidget {
        Q_OBJECT
    public:
        explicit WelcomePage(QWidget *parent = nullptr) : QWidget(parent) {
            auto* layout = new QVBoxLayout(this);
            
            // Title card
            auto* card = new QFrame();
            card->setStyleSheet("background-color: #1e1e1e; border-radius: 8px; padding: 20px;");
            
            QLabel* title = new QLabel("🎉 Welcome to Dvx3 Backup Manager", this);
            title->setStyleSheet("font-size: 24px; font-weight: bold; color: #ffffff; padding: 15px;");
            
            QLabel* desc = new QLabel(
                "A secure, fast, and reliable backup manager<br>"
                "<br>Features:<br>"
                "✓ AES-256 encryption with libsodium SecretBox<br>"
                "✓ Zstandard compression (zstd)<br>"
                "✓ Argon2id key derivation<br>"
                "✓ SHA-256 integrity verification", this);
            desc->setWordWrap(true);
            desc->setTextFormat(Qt::RichText);
            desc->setStyleSheet("color: #98a7ca; font-size: 12px; padding: 15px;");
            
            // Features list
            QLabel* featuresTitle = new QLabel("✨ Key Features", this);
            featuresTitle->setStyleSheet("font-size: 16px; font-weight: bold; color: #ffffff; padding: 10px;");
            
            QListWidget* featuresList = new QListWidget();
            featuresList->addItem("🔐 AES-256 Encryption with libsodium SecretBox");
            featuresList->addItem("📦 Zstandard Compression (zstd) for fast archiving");
            featuresList->addItem("🔑 Argon2id Key Derivation for strong passwords");
            featuresList->addItem("✅ SHA-256 Integrity Verification");
            featuresList->addItem("💾 Cross-Platform Support (Linux/macOS/Windows)");
            featuresList->addItem("🎨 Beautiful Qt6 Native Interface");
            
            featuresList->setStyleSheet(
                "QListWidget {"
                "    background-color: #202020;"
                "    border: 1px solid #404040;"
                "    padding: 5px;"
                "}"
                "QListWidget::item {"
                "    padding: 8px;"
                "    border-radius: 3px;"
                "}"
                "QListWidget::item:hover {"
                "    background-color: #2d2d30;"
                "}"
                "QListWidget::item:selected {"
                "    background-color: #1f4680;"
                "}"
            );
            
            // CTA button
            QPushButton* getStartedBtn = new QPushButton("🚀 Get Started", this);
            getStartedBtn->setStyleSheet(
                "background-color: #3fb95e; color: white; font-size: 14px; "
                "font-weight: bold; padding: 12px 30px; border: none; "
                "border-radius: 6px;"
            );
            
            // Add widgets to card
            card->layout()->addWidget(title);
            card->layout()->addWidget(desc);
            card->layout()->addSpacing(20);
            card->layout()->addWidget(featuresTitle);
            card->layout()->addWidget(featuresList);
            card->layout()->addSpacing(15);
            card->layout()->addWidget(getStartedBtn);
            
            layout->addWidget(card);
        }
    };

private:
    // UI components for Backup tab
    class BackupPage : public QWidget {
        Q_OBJECT
    public:
        explicit BackupPage(QWidget *parent = nullptr) : QWidget(parent) {
            auto* layout = new QVBoxLayout(this);
            
            // Title
            titleLabel = new QLabel("📦 Create New Backup", this);
            titleLabel->setStyleSheet("font-size: 20px; font-weight: bold; color: #ffffff; padding: 5px;");
            layout->addWidget(titleLabel);
            
            // Main container
            auto* container = new QFrame();
            container->setStyleSheet("background-color: #1e1e1e; border-radius: 8px; padding: 15px;");
            
            auto* stepLayout = new QVBoxLayout(container);
            
            // Step 1: Select source directory
            QLabel* step1Title = new QLabel("Step 1: Select Source Directory", this);
            step1Title->setStyleSheet("color: #ffffff; font-weight: bold; padding: 5px;");
            
            backupSourceLabel = new QLabel("", this);
            browseSourceBtn = new QPushButton("Browse...", this);
            browseSourceBtn->setMinimumWidth(80);
            
            connect(browseSourceBtn, &QPushButton::clicked, [this]() {
                QString selected = QFileDialog::getExistingDirectory(
                    this, "Select Source Directory", QDir::homePath()
                );
                if (!selected.isEmpty()) {
                    backupSourceLabel->setText(selected);
                    step1Title->setText("✅ Step 1: Source selected");
                    
                    // Enable next step
                    step2Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
                    browseBackupBtn->setEnabled(true);
                }
            });
            
            auto* step1Layout = new QHBoxLayout();
            step1Layout->addWidget(backupSourceLabel, 1);
            step1Layout->addWidget(browseSourceBtn);
            stepLayout->addLayout(step1Layout);
            
            // Step 2: Select backup location
            QLabel* step2Title = new QLabel("Step 2: Choose Backup Location", this);
            step2Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
            
            backupPathLabel = new QLabel("backup.dvx3", this);
            browseBackupBtn = new QPushButton("Browse...", this);
            browseBackupBtn->setMinimumWidth(80);
            
            connect(browseBackupBtn, &QPushButton::clicked, [this]() {
                QString selected = QFileDialog::getSaveFileName(
                    this, "Select Backup Location", 
                    QDir::homePath() + "/backup.dvx3",
                    "Dvx3 Archives (*.dvx3) All Files (**)"
                );
                if (!selected.isEmpty()) {
                    backupPathLabel->setText(QFileInfo(selected).fileName());
                    step2Title->setText("✅ Step 2: Location selected");
                    
                    // Enable next step
                    backupPasswordBtn->setEnabled(true);
                }
            });
            
            auto* step2Layout = new QHBoxLayout();
            step2Layout->addWidget(backupPathLabel, 1);
            step2Layout->addWidget(browseBackupBtn);
            stepLayout->addLayout(step2Layout);
            
            // Step 3: Set password
            QLabel* step3Title = new QLabel("Step 3: Set Encryption Password", this);
            step3Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
            
            backupPasswordLabel = new QLabel("", this);
            backupPasswordBtn = new QPushButton("Set Password", this);
            backupPasswordBtn->setMinimumWidth(100);
            
            connect(backupPasswordBtn, &QPushButton::clicked, [this]() {
                QString pass = QInputDialog::getText(this, "Encryption Password",
                    "Enter a strong password for your backups:\n\n"
                    "• Use a mix of letters, numbers, and symbols\n"
                    "• At least 12 characters recommended\n"
                    "• Store securely - you'll need it to restore!", 
                    QLineEdit::Password, "", QInputDialog::NoButtons);
                
                if (!pass.isEmpty()) {
                    backupPasswordLabel->setText(pass.length() > 0 ? "*" : "");
                    backupPasswordBtn->setEnabled(false); // Disable after setting
                    
                    // Enable encrypt button
                    encryptBtn->setEnabled(true);
                } else {
                    step3Title->setText("❌ Step 3: Password not set");
                }
            });
            
            auto* step3Layout = new QHBoxLayout();
            step3Layout->addWidget(backupPasswordLabel, 1);
            step3Layout->addWidget(backupPasswordBtn);
            stepLayout->addLayout(step3Layout);
            
            // Encrypt button - main action
            encryptBtn = new QPushButton("🔐 Create Encrypted Backup", this);
            encryptBtn->setMinimumHeight(50);
            encryptBtn->setStyleSheet(
                "background-color: #3fb95e; color: white; font-size: 16px; "
                "font-weight: bold; padding: 15px; border: none; "
                "border-radius: 6px;"
            );
            encryptBtn->setEnabled(false);
            
            connect(encryptBtn, &QPushButton::clicked, this, [this]() {
                onEncrypt();
            });
            stepLayout->addWidget(encryptBtn);
            
            // Progress section
            QGroupBox* progressGroup = new QGroupBox("📊 Progress");
            auto* progressLayout = new QVBoxLayout(progressGroup);
            
            progressBar = new QProgressBar();
            progressBar->setMinimumWidth(300);
            progressBar->setValue(0);
            progressBar->setTextVisible(true);
            progressBar->setMaximumWidth(600);
            progressLayout->addWidget(progressBar);
            
            progressBarStatus = new QLabel("Ready", this);
            progressBarStatus->setStyleSheet("color: #ffffff; padding: 5px;");
            progressLayout->addWidget(progressBarStatus);
            
            stepLayout->addWidget(progressGroup);
            
            layout->addWidget(container);
        }

    private:
        QLabel* titleLabel;
        QLabel* step1Title;
        QLabel* backupSourceLabel;
        QPushButton* browseSourceBtn;
        QLabel* step2Title;
        QLabel* backupPathLabel;
        QPushButton* browseBackupBtn;
        QLabel* step3Title;
        QLabel* backupPasswordLabel;
        QPushButton* backupPasswordBtn;
        QProgressBar* progressBar;
        QLabel* progressBarStatus;
        QPushButton* encryptBtn;
    };

private:
    // UI components for Restore tab
    class RestorePage : public QWidget {
        Q_OBJECT
    public:
        explicit RestorePage(QWidget *parent = nullptr) : QWidget(parent) {
            auto* layout = new QVBoxLayout(this);
            
            // Title
            titleLabel = new QLabel("🔄 Restore from Backup", this);
            titleLabel->setStyleSheet("font-size: 20px; font-weight: bold; color: #ffffff; padding: 5px;");
            layout->addWidget(titleLabel);
            
            // Main container
            auto* container = new QFrame();
            container->setStyleSheet("background-color: #1e1e1e; border-radius: 8px; padding: 15px;");
            
            auto* stepLayout = new QVBoxLayout(container);
            
            // Step 1: Select backup file
            QLabel* step1Title = new QLabel("Step 1: Select Backup Archive", this);
            step1Title->setStyleSheet("color: #ffffff; font-weight: bold; padding: 5px;");
            
            restoreBackupLabel = new QLabel("", this);
            browseRestoreBtn = new QPushButton("Browse...", this);
            browseRestoreBtn->setMinimumWidth(80);
            
            connect(browseRestoreBtn, &QPushButton::clicked, [this]() {
                QString selected = QFileDialog::getOpenFileName(
                    this, "Select Backup Archive", 
                    QDir::homePath(),
                    "Dvx3 Archives (*.dvx3) All Files (**)"
                );
                
                if (!selected.isEmpty()) {
                    restoreBackupLabel->setText(QFileInfo(selected).fileName());
                    step1Title->setText("✅ Step 1: Backup selected");
                    
                    // Enable password field
                    step2Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
                    restorePasswordBtn->setEnabled(true);
                }
            });
            
            auto* step1Layout = new QHBoxLayout();
            step1Layout->addWidget(restoreBackupLabel, 1);
            step1Layout->addWidget(browseRestoreBtn);
            stepLayout->addLayout(step1Layout);
            
            // Step 2: Enter password
            QLabel* step2Title = new QLabel("Step 2: Enter Decryption Password", this);
            step2Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
            
            restorePasswordLabel = new QLabel("", this);
            restorePasswordBtn = new QPushButton("Set Password", this);
            restorePasswordBtn->setMinimumWidth(100);
            
            connect(restorePasswordBtn, &QPushButton::clicked, [this]() {
                QString pass = QInputDialog::getText(this, "Decryption Password",
                    "Enter the password used to encrypt this backup:\n\n"
                    "• Must match the original encryption password\n"
                    "• Without it, files cannot be recovered!", 
                    QLineEdit::Password, "", QInputDialog::NoButtons);
                
                if (!pass.isEmpty()) {
                    restorePasswordLabel->setText(pass.length() > 0 ? "*" : "");
                    restorePasswordBtn->setEnabled(false);
                    
                    // Enable restore button
                    restoreBtn->setEnabled(true);
                } else {
                    step2Title->setText("❌ Step 2: Password not set");
                }
            });
            
            auto* step2Layout = new QHBoxLayout();
            step2Layout->addWidget(restorePasswordLabel, 1);
            step2Layout->addWidget(restorePasswordBtn);
            stepLayout->addLayout(step2Layout);
            
            // Restore button
            restoreBtn = new QPushButton("🔄 Restore Backup", this);
            restoreBtn->setMinimumHeight(50);
            restoreBtn->setStyleSheet(
                "background-color: #3fb95e; color: white; font-size: 16px; "
                "font-weight: bold; padding: 15px; border: none; "
                "border-radius: 6px;"
            );
            restoreBtn->setEnabled(false);
            
            connect(restoreBtn, &QPushButton::clicked, this, [this]() {
                onRestore();
            });
            stepLayout->addWidget(restoreBtn);
            
            // Progress section
            QGroupBox* progressGroup = new QGroupBox("📊 Progress");
            auto* progressLayout = new QVBoxLayout(progressGroup);
            
            progressBar = new QProgressBar();
            progressBar->setMinimumWidth(300);
            progressBar->setValue(0);
            progressBar->setTextVisible(true);
            progressBar->setMaximumWidth(600);
            progressLayout->addWidget(progressBar);
            
            progressBarStatus = new QLabel("Ready", this);
            progressBarStatus->setStyleSheet("color: #ffffff; padding: 5px;");
            progressLayout->addWidget(progressBarStatus);
            
            stepLayout->addWidget(progressGroup);
            
            layout->addWidget(container);
        }

    private:
        QLabel* titleLabel;
        QLabel* step1Title;
        QLabel* restoreBackupLabel;
        QPushButton* browseRestoreBtn;
        QLabel* step2Title;
        QLabel* restorePasswordLabel;
        QPushButton* restorePasswordBtn;
        QProgressBar* progressBar;
        QLabel* progressBarStatus;
        QPushButton* restoreBtn;
    };

private:
    // UI components for Dashboard tab
    class DashboardPage : public QWidget {
        Q_OBJECT
    public:
        explicit DashboardPage(QWidget *parent = nullptr) : QWidget(parent) {
            auto* layout = new QVBoxLayout(this);
            
            // Title
            titleLabel = new QLabel("📊 Recent Operations", this);
            titleLabel->setStyleSheet("font-size: 20px; font-weight: bold; color: #ffffff; padding: 5px;");
            layout->addWidget(titleLabel);
            
            // Scrollable table for operations history
            auto* scrollArea = new QScrollArea();
            scrollArea->setWidgetResizable(true);
            
            auto* tableContainer = new QWidget();
            auto* tableLayout = new QVBoxLayout(tableContainer);
            
            // Table headers
            auto* headerBox = new QHBoxLayout();
            headerBox->addWidget(new QLabel("#", this));
            headerBox->addWidget(new QLabel("Operation", this));
            headerBox->addWidget(new QLabel("Status", this));
            headerBox->addWidget(new QLabel("Details", this));
            
            tableLayout->addLayout(headerBox);
            
            // Recent operations container (starts empty)
            recentOpsContainer = new QWidget();
            recentOpsLayout = new QVBoxLayout(recentOpsContainer);
            recentOpsLayout->setContentsMargins(0, 0, 0, 0);
            tableLayout->addWidget(recentOpsContainer);
            
            scrollArea->setWidget(tableContainer);
            layout->addWidget(scrollArea);
            
            // Empty state message
            emptyStateLabel = new QLabel("No operations yet\n<br>Go to 'Create Backup' to get started", this);
            emptyStateLabel->setTextFormat(Qt::RichText);
            emptyStateLabel->setStyleSheet("color: #606060; padding: 20px;");
            layout->addWidget(emptyStateLabel);
        }

    public slots:
        void addRecentOperation(const QString& operation, const QString& status, 
                                const QString& details) {
            // Remove empty state if present
            if (emptyStateLabel && emptyStateLabel->parent()) {
                QWidget* parent = qobject_cast<QWidget*>(emptyStateLabel->parent());
                if (parent) parent->layout()->removeWidget(emptyStateLabel);
            }
            
            // Create operation row
            auto* rowBox = new QHBoxLayout();
            
            // Number
            QLabel* num = new QLabel(QString::number(recentOperations.size() + 1), this);
            num->setAlignment(Qt::AlignCenter);
            
            // Operation type
            QLabel* opLabel = new QLabel(operation, this);
            opLabel->setStyleSheet("font-weight: bold; color: #98a7ca;");
            
            // Status
            QLabel* statusLabel = new QLabel(status, this);
            if (status == "Success") {
                statusLabel->setStyleSheet("color: #3fb95e; font-weight: bold;");
            } else {
                statusLabel->setStyleSheet("color: #ff4d4d; font-weight: bold;");
            }
            
            // Details (truncated to 100 chars)
            QLabel* detailsLabel = new QLabel(details.left(100), this);
            
            rowBox->addWidget(num, 0);
            rowBox->addWidget(opLabel, 1);
            rowBox->addWidget(statusLabel, 0);
            rowBox->addWidget(detailsLabel, 2);
            
            recentOpsLayout->addLayout(rowBox);
        }

    private:
        QLabel* titleLabel;
        QWidget* recentOpsContainer;
        QVBoxLayout* recentOpsLayout;
        QLabel* emptyStateLabel;
    };

private:
    // UI components for Settings tab
    class SettingsPage : public QWidget {
        Q_OBJECT
    public:
        explicit SettingsPage() : QWidget(nullptr) {
            auto* layout = new QVBoxLayout(this);
            
            // Title
            titleLabel = new QLabel("⚙️ Backup Settings", this);
            titleLabel->setStyleSheet("font-size: 20px; font-weight: bold; color: #ffffff; padding: 5px;");
            layout->addWidget(titleLabel);
            
            // Container frame
            auto* container = new QFrame();
            container->setStyleSheet("background-color: #1e1e1e; border-radius: 8px; padding: 15px;");
            
            auto* settingsLayout = new QVBoxLayout(container);
            
            // Encryption section
            QLabel* encryptionTitle = new QLabel("🔐 Encryption Settings", this);
            encryptionTitle->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
            settingsLayout->addWidget(encryptionTitle);
            
            QLabel* encPasswordLabel = new QLabel("Backup Password:", this);
            encPasswordLabel->setStyleSheet("color: #ffffff;");
            
            encPasswordEntry = new QLineEdit();
            encPasswordEntry->setPlaceholderText("Enter a strong password for your backups");
            encPasswordEntry->setEchoMode(QLineEdit::Password);
            encPasswordEntry->setStyleSheet(
                "background-color: #2a2a2a; color: white; padding: 8px; border: none; border-radius: 4px;"
            );
            
            auto* encRow = new QHBoxLayout();
            encRow->addWidget(encPasswordLabel);
            encRow->addWidget(encPasswordEntry);
            settingsLayout->addLayout(encRow);
            
            // Retention section
            QLabel* retentionTitle = new QLabel("🗑️ Retention Settings", this);
            retentionTitle->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
            settingsLayout->addWidget(retentionTitle);
            
            QLabel* retentionLabel = new QLabel("Keep last N backups:", this);
            retentionLabel->setStyleSheet("color: #ffffff;");
            
            retentionSpinBox = new QSpinBox();
            retentionSpinBox->setRange(1, 100);
            retentionSpinBox->setValue(5);
            retentionSpinBox->setSuffix(" backups");
            
            auto* retRow = new QHBoxLayout();
            retRow->addWidget(retentionLabel);
            retRow->addWidget(retentionSpinBox);
            settingsLayout->addLayout(retRow);
            
            // Auto-delete section
            QLabel* autoDelTitle = new QLabel("🔄 Automation", this);
            autoDelTitle->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
            settingsLayout->addWidget(autoDelTitle);
            
            QCheckBox* autoDeleteCb = new QCheckBox(
                "Automatically delete backups older than", this);
            
            autoDeleteSpinBox = new QSpinBox();
            autoDeleteSpinBox->setRange(1, 365);
            autoDeleteSpinBox->setValue(90);
            autoDeleteSpinBox->setSuffix(" days");
            
            auto* autoDelRow = new QHBoxLayout();
            autoDelRow->addWidget(autoDeleteCb);
            autoDelRow->addWidget(autoDeleteSpinBox);
            settingsLayout->addLayout(autoDelRow);
            
            // About section
            QLabel* aboutTitle = new QLabel("ℹ️ About Dvx3 Backup Manager", this);
            aboutTitle->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
            settingsLayout->addWidget(aboutTitle);
            
            QLabel* aboutLabel = new QLabel(
                "Dvx3 Backup Manager v1.0.0<br><br>"
                "A secure backup solution using:<br>"
                "• AES-256 encryption via libsodium SecretBox<br>"
                "• Zstandard compression (zstd)<br>"
                "• Argon2id key derivation for passwords<br>"
                "• SHA-256 integrity verification", this);
            aboutLabel->setWordWrap(true);
            aboutLabel->setStyleSheet("font-size: 10px; color: #98a7ca; padding: 10px; background-color: #1e1e1e; border-radius: 4px;");
            
            settingsLayout->addWidget(aboutLabel);
            
            layout->addWidget(container);
        }

private:
        QLabel* titleLabel;
        QLineEdit* encPasswordEntry;
        QSpinBox* retentionSpinBox;
        QSpinBox* autoDeleteSpinBox;
    };

public:
    QWidget* WelcomeTab = nullptr;
    QWidget* BackupTab = nullptr;
    QWidget* RestoreTab = nullptr;
    QWidget* DashboardTab = nullptr;
    QWidget* SettingsTab = nullptr;
    
    QPushButton* browseSourceBtn;
    QPushButton* browseBackupBtn;
    QLabel* backupSourceLabel;
    QLabel* backupPathLabel;
    QPushButton* browseRestoreBtn;
    QProgressBar* progressBar;
    QLabel* progressBarStatus;
    QPushButton* encryptBtn;
    QPushButton* restoreBtn;
    
    QLineEdit* encPasswordEntry;
    QSpinBox* retentionSpinBox;
    QSpinBox* autoDeleteSpinBox;
    
    QLabel* titleLabel;
    QWidget* recentOpsContainer;
    QVBoxLayout* recentOpsLayout;
    QLabel* emptyStateLabel;

private:
    QTabWidget* TabWidget = nullptr;
    QSystemTrayIcon* TrayIcon = nullptr;
    QMenu* TrayMenu = nullptr;
    
    QAction* ActionBackup = nullptr;
    QAction* ActionRestore = nullptr;
    QAction* ActionQuit = nullptr;
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName("Dvx3 Backup Manager");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("dvx3");
    
    // Set application-wide style for consistent dark theme
    QPalette darkPalette;
    darkPalette.setColor(QPalette::Window, QColor(30, 30, 32));
    darkPalette.setColor(QPalette::WindowText, Qt::white);
    darkPalette.setColor(QPalette::Base, QColor(40, 40, 42));
    darkPalette.setColor(QPalette::AltBase, QColor(60, 60, 65));
    darkPalette.setColor(QPalette::Text, Qt::white);
    darkPalette.setColor(QPalette::Button, QColor(30, 30, 32));
    darkPalette.setColor(QPalette::ButtonText, Qt::white);
    darkPalette.setColor(QPalette::BrightText, QColor("#3fb95e"));
    darkPalette.setColor(QPalette::Link, QColor("#1f4680"));
    darkPalette.setColor(QPalette::Highlight, QColor("#1f4680"));
    darkPalette.setColor(QPalette::HighlightedText, Qt::white);
    
    app.setPalette(darkPalette);
    
    // Set custom font (system default or user preference)
    QFont font = app.font();
    font.setPointSize(10);
    app.setFont(font);
    
    Dvx3BackupApp window;
    window.show();
    
    return app.exec();
}

#include "main.moc"