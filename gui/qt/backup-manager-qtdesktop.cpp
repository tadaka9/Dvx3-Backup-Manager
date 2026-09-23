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
#include <QtConcurrent>
#include <QHBoxLayout>
#include <QGroupBox>
#include <QListWidget>
#include <QTableWidget>
#include <QHeaderView>
#include <QComboBox>
#include <QCheckBox>
#include <QTextEdit>
#include <QScrollArea>
#include <QSplitter>
#include <QFrame>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QAction>
#include <QStyle>
#include <QFont>
#include <QDateTime>
#include <QColor>
#include <QJsonDocument>
#include <QJsonObject>

// Enhanced status bar with dynamic labels
class StatusBar : public QStatusBar {
public:
    StatusBar(QWidget *parent = nullptr) : QStatusBar(parent) {
        setStyleSheet("background-color: #303030; color: #ffffff; padding: 2px;");
        showMessage("Dvx3 Backup Manager - Ready", 10000);
    }
    
    void setStatusText(const QString &text, int timeout = -1) override {
        if (timeout == -1) {
            showMessage(text, 0); // Permanent
        } else {
            showMessage(text, timeout);
        }
    }

    Q_SLOT void setProgress(int value, const QString &description = "") {
        QProgressBar *bar = this->findChild<QProgressBar*>();
        if (bar) {
            bar->setValue(value);
        }
    }
};

class DashboardWidget : public QWidget {
public:
    DashboardWidget() {
        setLayout(createDashboardLayout());
        updateDashboard();
    }

private:
    QVBoxLayout *createDashboardLayout() {
        auto *layout = new QVBoxLayout(this);
        layout->setContentsMargins(10, 10, 10, 10);
        
        // Status summary card
        auto *statusCard = new QGroupBox("📊 Dashboard Summary");
        auto *cardLayout = new QVBoxLayout(statusCard);
        
        // Progress section
        auto *progressGroup = new QGroupBox("🔄 Current Operation");
        auto *progressLayout = new QVBoxLayout(progressGroup);
        
        progressBar = new QProgressBar();
        progressBar->setValue(0);
        progressBar->setStyleSheet(
            "QProgressBar {"
            "    background-color: #404040;"
            "    border: 1px solid #555555;"
            "    border-radius: 4px;"
            "    text-align: center;"
            "}"
            "QProgressBar::chunk {"
            "    background-color: #3fb95e;"
            "}"
        );
        progressBar->setFixedSize(300, 25);
        progressLayout->addWidget(progressBar);
        
        currentStatus = new QLabel("Ready");
        currentStatus->setStyleSheet("color: #ffffff; padding: 5px;");
        progressLayout->addWidget(currentStatus);
        
        cardLayout->addWidget(progressGroup);
        
        // Quick stats cards
        auto *statsRow = new QHBoxLayout();
        
        // Recent backups count
        recentBackupsLabel = new QLabel("0");
        recentBackupsLabel->setStyleSheet("font-size: 24px; font-weight: bold; color: #3fb95e; padding: 10px;");
        statsRow->addWidget(recentBackupsLabel);
        statsRow->addStretch();
        
        // Last backup time
        lastBackupLabel = new QLabel("Never");
        lastBackupLabel->setStyleSheet("font-size: 24px; font-weight: bold; color: #98a7ca; padding: 10px;");
        statsRow->addWidget(lastBackupLabel);
        statsRow->addStretch();
        
        cardLayout->addLayout(statsRow);
        layout->addWidget(statusCard);
        
        // Operation history table
        auto *historyGroup = new QGroupBox("📋 Recent Operations");
        auto *historyLayout = new QVBoxLayout(historyGroup);
        
        recentOpsTable = new QTableWidget();
        recentOpsTable->setColumnCount(5);
        recentOpsTable->horizontalHeader()->setVisible(true);
        recentOpsTable->horizontalHeader()->setSectionResizeMode(0, QHeaderView::Stretch);
        recentOpsTable->horizontalHeader()->setSectionResizeMode(4, QHeaderView::Interactive);
        
        recentOpsTable->setHorizontalHeaderLabels({"#", "Operation", "Status", "Source/Destination", "Size", "Time"});
        recentOpsTable->setItemDelegate(new QItemDelegate());
        recentOpsTable->setStyleSheet(
            "QTableWidget {"
            "    background-color: #202020;"
            "    border: 1px solid #404040;"
            "}"
            "QTableWidget::item {"
            "    padding: 3px;"
            "}"
            "QHeaderView::section {"
            "    background-color: #353535;"
            "    color: #98a7ca;"
            "    border-bottom: 1px solid #404040;"
            "}"
        );
        historyLayout->addWidget(recentOpsTable);
        layout->addWidget(historyGroup);
        
        return layout;
    }

    Q_SLOT void updateDashboard() {
        // Update recent operations table
        recentOpsTable->clear();
        if (recentOperations.isEmpty()) {
            currentStatus->setText("Ready");
            progressBar->setValue(0);
            return;
        }
        
        int row = 0;
        for (const auto &op : recentOperations) {
            QTableWidgetItem *itemNum = new QTableWidgetItem(QString::number(row + 1));
            itemNum->setTextAlignment(Qt::AlignCenter);
            
            QTableWidgetItem *itemOp = new QTableWidgetItem(op.operation);
            QTableWidgetItem *itemStatus = new QTableWidgetItem(op.status);
            itemStatus->setForeground(QColor("#3fb95e")); // Green for success
            
            if (op.error.isNotEmpty()) {
                itemStatus->setForeground(QColor("#ff4d4d")); // Red for error
            }
            
            QTableWidgetItem *itemSrc = new QTableWidgetItem(op.sourceOrDest);
            QTableWidgetItem *itemSize = op.size.isEmpty() ? 
                new QTableWidgetItem("-") : new QTableWidgetItem(op.size);
            
            QTableWidgetItem *itemTime = new QTableWidgetItem(op.duration);
            
            recentOpsTable->setItem(row, 0, itemNum);
            recentOpsTable->setItem(row, 1, itemOp);
            recentOpsTable->setItem(row, 2, itemStatus);
            recentOpsTable->setItem(row, 3, itemSrc);
            recentOpsTable->setItem(row, 4, itemSize);
            
            if (op.duration.isEmpty()) {
                QTableWidgetItem *timeItem = new QTableWidgetItem(op.size.isEmpty() ? "-" : op.size);
                // For simplicity, reuse size column when duration is empty
            }
            
            row++;
        }
        
        // Update stats
        recentBackupsLabel->setText(QString::number(recentBackups.count()));
        if (!lastBackup.isNull()) {
            lastBackupLabel->setText(lastBackup.toString("yyyy-MM-dd HH:mm:ss"));
        }
    }

private:
    QProgressBar *progressBar;
    QLabel *currentStatus;
    QLabel *recentBackupsLabel;
    QLabel *lastBackupLabel;
    QTableWidget *recentOpsTable;
    QList<RecentOperation> recentOperations;
    QDate lastBackup;
    QList<QPair<QString, QString>> recentBackups;
    
    struct RecentOperation {
        QString operation;      // "Encrypt" or "Decrypt"
        QString status;         // "Success", "Error", etc.
        QString sourceOrDest;   // Source dir or backup file
        QString size;           // Size of data processed
        QString duration;       // Time elapsed
    };
};

// Settings widget for configuration
class SettingsWidget : public QWidget {
public:
    SettingsWidget() {
        setLayout(createSettingsLayout());
    }

private:
    QVBoxLayout *createSettingsLayout() {
        auto *layout = new QVBoxLayout(this);
        layout->setContentsMargins(10, 10, 10, 10);
        
        // Encryption settings group
        auto *encryptionGroup = new QGroupBox("🔐 Encryption Settings");
        auto *encLayout = new QVBoxLayout(encryptionGroup);
        
        encPasswordLabel = new QLabel("Backup Password:");
        encPasswordInput = new QLineEdit();
        encPasswordInput->setPlaceholderText("Enter a strong password for your backups");
        encPasswordInput->setEchoMode(QLineEdit::Password);
        encPasswordInput->setStyleSheet("background-color: #2a2a2a; color: white; padding: 8px; border: none; border-radius: 4px;");
        
        auto *encLayoutRow = new QHBoxLayout();
        encLayoutRow->addWidget(encPasswordLabel);
        encLayoutRow->addWidget(encPasswordInput);
        encLayout->addLayout(encLayoutRow);
        
        // Retention settings group
        auto *retentionGroup = new QGroupBox("🗑️ Retention Settings");
        auto *retLayout = new QVBoxLayout(retentionGroup);
        
        retentionLabel = new QLabel("Keep last N backups:");
        retentionSpinBox = new QSpinBox();
        retentionSpinBox->setRange(1, 100);
        retentionSpinBox->setValue(5);
        retentionSpinBox->setSuffix(" backups");
        
        auto *retRow = new QHBoxLayout();
        retRow->addWidget(retentionLabel);
        retRow->addWidget(retentionSpinBox);
        retLayout->addLayout(retRow);
        
        // Auto-delete old backups
        auto *autoDeleteGroup = new QGroupBox("🔄 Automation");
        auto *autoDelLayout = new QVBoxLayout(autoDeleteGroup);
        
        autoDeleteCheckBox = new QCheckBox("Automatically delete backups older than:");
        autoSpinBox = new QSpinBox();
        autoSpinBox->setRange(1, 365);
        autoSpinBox->setValue(90);
        autoSpinBox->setSuffix(" days");
        
        auto *autoDelRow = new QHBoxLayout();
        autoDelRow->addWidget(autoDeleteCheckBox);
        autoDelRow->addWidget(autoSpinBox);
        autoDelLayout->addLayout(autoDelRow);
        
        // About section
        auto *aboutGroup = new QGroupBox("ℹ️ About Dvx3 Backup Manager");
        auto *aboutLayout = new QVBoxLayout(aboutGroup);
        
        aboutLabel = new QLabel("Dvx3 Backup Manager v1.0.0\n\nA secure backup solution using:\n• AES-256 encryption via libsodium\n• Zstandard compression\n• Argon2id key derivation\n• SHA-256 integrity verification");
        aboutLabel->setWordWrap(true);
        aboutLabel->setStyleSheet("font-size: 10px; color: #98a7ca; padding: 10px; background-color: #1e1e1e; border-radius: 4px;");
        aboutLayout->addWidget(aboutLabel);
        
        layout->addWidget(encryptionGroup);
        layout->addWidget(retentionGroup);
        layout->addWidget(autoDeleteGroup);
        layout->addWidget(aboutGroup);
        
        return layout;
    }

private:
    QLabel *encPasswordLabel;
    QLineEdit *encPasswordInput;
    QLabel *retentionLabel;
    QSpinBox *retentionSpinBox;
    QCheckBox *autoDeleteCheckBox;
    QSpinBox *autoSpinBox;
    QLabel *aboutLabel;
};


// Main application window with enhanced features
class BackupManagerApp : public QMainWindow {
    Q_OBJECT

public:
    BackupManagerApp() : QMainWindow(), backupPath("/backup.dvx3") {
        setupUI();
        setupConnections();
        setupTrayIcon();
    }

private:
    void setupUI() {
        setWindowTitle("Dvx3 Backup Manager");
        resize(1200, 800);
        
        // Main splitter for tabbed interface
        auto *splitter = new QSplitter(this);
        splitter->setHandleWidth(5);
        splitter->setChildrenCollapsible(false);
        
        // Create tabs
        createWelcomeTab(splitter);
        createBackupTab(splitter);
        createRestoreTab(splitter);
        createDashboardTab(splitter);
        createSettingsTab(splitter);
        
        splitter->addWidget(welcomeTab);
        splitter->addWidget(backupTab);
        splitter->addWidget(restoreTab);
        splitter->addWidget(dashboardTab);
        splitter->addWidget(settingsTab);
        
        centralWidget()->setLayout(new QVBoxLayout());
        centralWidget()->layout()->addWidget(splitter);
        
        // Set tab bar style
        auto *tabBar = new QTabBar();
        tabBar->setDocumentMode(true);
        tabBar->setMovable(false);
        tabBar->setExpanding(true);
        
        // Style tabs
        tabBar->setStyleSheet(
            "QTabBar::tab {"
            "    background-color: #2d2d30;"
            "    color: #98a7ca;"
            "    padding: 10px;"
            "    border-top-left-radius: 4px;"
            "    border-top-right-radius: 4px;"
            "}"
            "QTabBar::tab:selected {"
            "    background-color: #3b3b3b;"
            "    color: #ffffff;"
            "}"
            "QTabBar::tab:hover {"
            "    background-color: #404042;"
            "}"
        );
        
        statusBar()->showMessage("Ready");
    }

private:
    void setupConnections() {
        // Connect status bar progress signal
        connect(statusBar(), &QStatusBar::messageChanged, this, [](const QString &) {});
    }

private:
    void createWelcomeTab(QWidget *parent) {
        welcomeTab = new QWidget(parent);
        auto *layout = new QVBoxLayout(welcomeTab);
        
        // Welcome card with gradient background
        auto *welcomeCard = new QFrame();
        welcomeCard->setStyleSheet(
            "background-color: #1e1e1e;"
            "border-radius: 8px;"
            "padding: 20px;"
            "margin: 10px;"
        );
        
        auto *welcomeLayout = new QVBoxLayout(welcomeCard);
        
        // Title with icon and text
        welcomeTitle = new QLabel("🎉 Welcome to Dvx3 Backup Manager");
        welcomeTitle->setStyleSheet("font-size: 24px; font-weight: bold; color: #ffffff; padding: 15px;");
        welcomeLayout->addWidget(welcomeTitle);
        
        // Description
        welcomeDescription = new QLabel(
            "Secure, fast, and reliable backup management.<br><br>"
            "This application provides:<br>"
            "✓ AES-256 encrypted backups with integrity verification<br>"
            "✓ Zstandard compression for fast archiving<br>"
            "✓ Argon2id key derivation for password protection<br>"
            "✓ SHA-256 integrity checking<br>"
            "✓ Cross-platform support (Linux/macOS/Windows)"
        );
        welcomeDescription->setWordWrap(true);
        welcomeDescription->setTextFormat(Qt::RichText);
        welcomeDescription->setStyleSheet("color: #98a7ca; font-size: 12px; padding: 15px;");
        welcomeLayout->addWidget(welcomeDescription);
        
        // Feature highlights
        auto *featuresGroup = new QGroupBox("✨ Features");
        auto *featuresLayout = new QVBoxLayout(featuresGroup);
        
        featuresList = new QListWidget();
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
        
        featuresLayout->addWidget(featuresList);
        welcomeLayout->addWidget(featuresGroup);
        
        // CTA button
        ctaButton = new QPushButton("Get Started →");
        ctaButton->setStyleSheet(
            "background-color: #3fb95e;"
            "color: white;"
            "font-size: 14px;"
            "font-weight: bold;"
            "padding: 12px 30px;"
            "border: none;"
            "border-radius: 6px;"
        );
        ctaButton->setText("Get Started →");
        connect(ctaButton, &QPushButton::clicked, this, [this]() {
            // Navigate to backup tab (index 1)
            for (int i = 0; i < tabBar->tabCount(); i++) {
                tabBar->setTabEnabled(i, i != 1); // Enable only backup tab
            }
            updateDashboard();
        });
        welcomeLayout->addWidget(ctaButton);
        
        layout->addWidget(welcomeCard);
    }

private:
    void createBackupTab(QWidget *parent) {
        backupTab = new QWidget(parent);
        auto *layout = new QVBoxLayout(backupTab);
        layout->setContentsMargins(10, 10, 10, 10);
        
        // Title section
        backupTitle = new QLabel("📦 Create New Backup");
        backupTitle->setStyleSheet("font-size: 20px; font-weight: bold; color: #ffffff; padding: 5px;");
        layout->addWidget(backupTitle);
        
        // Main container with card style
        auto *backupContainer = new QFrame();
        backupContainer->setStyleSheet("background-color: #1e1e1e; border-radius: 8px; padding: 15px;");
        auto *backupLayout = new QVBoxLayout(backupContainer);
        
        // Step 1: Select Source Directory
        step1Title = new QLabel("Step 1: Select Source Directory");
        step1Title->setStyleSheet("color: #ffffff; font-weight: bold; padding: 5px;");
        backupLayout->addWidget(step1Title);
        
        sourceDirLabel = new QLabel("");
        browseSourceBtn = new QPushButton("Browse...");
        browseSourceBtn->setMinimumWidth(80);
        connect(browseSourceBtn, &QPushButton::clicked, this, [this]() {
            QString selected = QFileDialog::getExistingDirectory(
                backupTab, "Select Source Directory", QDir::homePath()
            );
            if (!selected.isEmpty()) {
                sourceDirLabel->setText(selected);
                step1Title->setText("✅ Step 1: Source Selected");
                
                // Enable next button
                step2Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
                browseBackupBtn->setEnabled(true);
            }
        });
        
        auto *step1Layout = new QHBoxLayout();
        step1Layout->addWidget(sourceDirLabel, 1);
        step1Layout->addWidget(browseSourceBtn);
        backupLayout->addLayout(step1Layout);
        
        // Step 2: Select Backup Location
        step2Title = new QLabel("Step 2: Choose Backup Location");
        step2Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
        backupLayout->addWidget(step2Title);
        
        backupPathLabel = new QLabel("backup.dvx3");
        browseBackupBtn = new QPushButton("Browse...");
        browseBackupBtn->setMinimumWidth(80);
        connect(browseBackupBtn, &QPushButton::clicked, this, [this]() {
            QString selected = QFileDialog::getSaveFileName(
                backupTab, "Select Backup Location", 
                QDir::homePath() + "/backup.dvx3",
                "Dvx3 Archives (*.dvx3) All Files (**)"
            );
            if (!selected.isEmpty()) {
                backupPathLabel->setText(QFileInfo(selected).fileName());
                step2Title->setText("✅ Step 2: Location Selected");
                
                // Enable next button
                encryptBtn->setEnabled(true);
            }
        });
        
        auto *step2Layout = new QHBoxLayout();
        step2Layout->addWidget(backupPathLabel, 1);
        step2Layout->addWidget(browseBackupBtn);
        backupLayout->addLayout(step2Layout);
        
        // Step 3: Set Password
        step3Title = new QLabel("Step 3: Set Encryption Password");
        step3Title->setStyleSheet("color: #98a7ca; font-weight: bold; padding: 5px;");
        backupLayout->addWidget(step3Title);
        
        passwordLabel = new QLabel("");
        setPasswordBtn = new QPushButton("Set Password");
        setPasswordBtn->setMinimumWidth(100);
        connect(setPasswordBtn, &QPushButton::clicked, this, [this]() {
            QString pass = QInputDialog::getText(
                backupTab, "Encryption Password",
                "Enter a strong password for your backups:\n\n"
                "• Use a mix of letters, numbers, and symbols\n"
                "• At least 12 characters recommended\n"
                "• Store securely - you'll need it to restore!",
                QLineEdit::Password, "", QInputDialog::NoButtons
            );
            passwordLabel->setText(pass.isEmpty() ? "(not set)" : "★".repeated(pass.length()));
            setPasswordBtn->setEnabled(false); // Disable after setting
            
            // Enable encrypt button
            encryptBtn->setEnabled(!pass.isEmpty());
        });
        
        auto *step3Layout = new QHBoxLayout();
        step3Layout->addWidget(passwordLabel, 1);
        step3Layout->addWidget(setPasswordBtn);
        backupLayout->addLayout(step3Layout);
        
        // Encrypt button - the main action
        encryptBtn = new QPushButton("🔐 Create Encrypted Backup");
        encryptBtn->setMinimumHeight(50);
        encryptBtn->setStyleSheet(
            "background-color: #3fb95e;"
            "color: white;"
            "font-size: 16px;"
            "font-weight: bold;"
            "padding: 15px;"
            "border: none;"
            "border-radius: 6px;"
        );
        connect(encryptBtn, &QPushButton::clicked, this, &BackupManagerApp::onStartEncrypt);
        backupLayout->addWidget(encryptBtn);
        
        // Progress and status section
        progressGroup = new QGroupBox("📊 Progress");
        auto *progressGroupLayout = new QVBoxLayout(progressGroup);
        
        progressBar = new QProgressBar();
        progressBar->setMinimumWidth(300);
        progressBar->setValue(0);
        progressBar->setTextVisible(true);
        progressBar->setMaximumWidth(600);
        progressGroupLayout->addWidget(progressBar);
        
        progressLabel = new QLabel("Ready");
        progressLabel->setStyleSheet("color: #ffffff; padding: 5px;");
        progressGroupLayout->addWidget(progressLabel);
        
        backupLayout->addWidget(progressGroup);
        
        layout->addWidget(backupContainer);
    }

private slots:
    void onStartEncrypt() {
        if (sourceDirLabel->text().isEmpty()) return;
        if (passwordLabel->text() == "(not set)") {
            QMessageBox::warning(this, "Missing Password", 
                "Please set a password first.\nClick 'Set Password' to continue.");
            setPasswordBtn->setEnabled(true);
            return;
        }
        
        QString cmd = "./cli_backup_manager";
        QString exe = qApp->applicationDirPath() + "/cli_backup_manager";
        
        QStringList args;
        args << "encrypt" << sourceDirLabel->text()
              << "-p" << passwordLabel->text()
              << "-o" << backupPath;
        
        QProcess process;
        process.setProgram(exe);
        process.setArguments(args);
        
        // Connect signals for progress tracking
        connect(&process, &QProcess::started, this, [this]() {
            updateStatus("Encrypting...");
            progressBar->setMaximum(100);
            progressBar->setValue(0);
        });
        
        connect(&process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
                this, [this, process, cmd, args]() {
            if (process.exitCode() == 0) {
                updateStatus("✅ Backup completed successfully!");
                progressBar->setValue(100);
                addRecentOperation("Encrypt", "Success", sourceDirLabel->text(), "", "");
                
                // Clear success message after delay
                statusBar()->removeMessage(statusBar()->message());
                
            } else {
                QString error = process.readAllStandardError();
                QMessageBox::critical(this, "Backup Failed", 
                    "Error:\n\n" + error);
                addRecentOperation("Encrypt", "Error", sourceDirLabel->text(), "", "Exit code: " + QString::number(process.exitCode()));
                
                updateStatus("❌ Backup failed");
            }
        });
        
        process.start();
    }

private slots:
    void onBackupFinished(int exitCode) {
        if (exitCode == 0) {
            updateStatus("SUCCESS: Backup completed successfully!");
            progressBar->setValue(100);
            addRecentOperation("Encrypt", "Success", backupPathLabel->text(), "", "");
            
            // Clear success message after delay
            statusBar()->removeMessage(statusBar()->message());
        } else {
            QString error = process.readAllStandardError();
            QMessageBox::critical(this, "Backup Failed", error);
            addRecentOperation("Encrypt", "Error", backupPathLabel->text(), "", error);
            
            updateStatus("FAILURE: Backup failed");
        }
    }

private:
    void setupTrayIcon() {
        // Tray icon for system tray support
        auto *tray = new QSystemTrayIcon(this);
        auto *icon = new QIcon();
        
        tray->setIcon(*icon);
        tray->setContextMenu(contextMenu);
        connect(tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::DoubleClick) {
                showWindow();
                raise();
                activateWindow();
            }
        });
        tray->show();
    }

private:
    void setupMainWindow() {
        // Main window initialization
        setWindowTitle("Dvx3 Backup Manager");
        
        // Status bar with dynamic messages
        statusBar()->showMessage("Ready");
    }
};