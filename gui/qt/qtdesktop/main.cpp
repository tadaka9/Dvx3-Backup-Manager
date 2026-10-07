/* Qt owns presentation only. Archive work always uses the generated Vala C API. */
#include "dvx3.hpp"

#include <algorithm>
#include <functional>
#include <QApplication>
#include <QButtonGroup>
#include <QCheckBox>
#include <QClipboard>
#include <QCloseEvent>
#include <QComboBox>
#include <QDesktopServices>
#include <QDialog>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QFileDialog>
#include <QFileInfo>
#include <QFrame>
#include <QGraphicsOpacityEffect>
#include <QHeaderView>
#include <QHash>
#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMainWindow>
#include <QMenuBar>
#include <QMessageBox>
#include <QMimeData>
#include <QParallelAnimationGroup>
#include <QPlainTextEdit>
#include <QProgressBar>
#include <QPropertyAnimation>
#include <QPushButton>
#include <QScrollArea>
#include <QSettings>
#include <QSignalBlocker>
#include <QStackedWidget>
#include <QStatusBar>
#include <QSysInfo>
#include <QTableWidget>
#include <QThread>
#include <QTime>
#include <QUrl>
#include <QVBoxLayout>

namespace {
enum Page { Dashboard, Archive, Codecs, Activity, About };

const char* theme = R"CSS(
* { font-family: "Inter", "SF Pro Display", "Segoe UI", sans-serif; }
QMainWindow, QDialog { background: #090909; color: #f4f4f4; }
QMenuBar { background: #090909; color: #aaa; border-bottom: 1px solid #252525; padding: 3px; }
QMenuBar::item { padding: 7px 12px; border-radius: 5px; }
QMenuBar::item:selected { background: #f4f4f4; color: #090909; }
QMenu { background: #151515; color: #f4f4f4; border: 1px solid #333; padding: 6px; }
QMenu::item { padding: 8px 28px 8px 12px; border-radius: 4px; }
QMenu::item:selected { background: #f4f4f4; color: #090909; }
#sidebar { background: #050505; border-right: 1px solid #252525; }
#content { background: #0c0c0c; }
#wordmark { font-size: 20px; font-weight: 800; letter-spacing: 3px; }
#eyebrow { color: #888; font-size: 10px; font-weight: 700; letter-spacing: 2px; }
#pageTitle { font-size: 34px; font-weight: 750; }
#pageSubtitle { color: #929292; font-size: 14px; }
#heroTitle { font-size: 39px; font-weight: 780; }
#heroCopy { color: #333; font-size: 15px; }
#sectionTitle { font-size: 17px; font-weight: 700; }
QPushButton[nav="true"] { background: transparent; color: #8d8d8d; border: 0; border-radius: 8px; padding: 12px 14px; text-align: left; font-weight: 600; }
QPushButton[nav="true"]:hover { background: #151515; color: #fff; }
QPushButton[nav="true"]:checked { background: #f4f4f4; color: #090909; }
QFrame[card="true"] { background: #131313; border: 1px solid #292929; border-radius: 13px; }
QFrame[hero="true"] { background: #f4f4f4; border: 0; border-radius: 15px; color: #090909; }
QFrame[hero="true"] QLabel { color: #090909; }
QLabel[muted="true"] { color: #8c8c8c; }
QLabel[chip="true"] { background: #202020; color: #ddd; border: 1px solid #363636; border-radius: 10px; padding: 3px 9px; font-size: 11px; }
QLineEdit, QComboBox, QPlainTextEdit, QTableWidget, QListWidget { background: #101010; color: #f3f3f3; border: 1px solid #303030; border-radius: 8px; padding: 10px; selection-background-color: #f4f4f4; selection-color: #090909; }
QLineEdit:focus, QComboBox:focus, QPlainTextEdit:focus { border-color: #ededed; }
QComboBox::drop-down { border: 0; width: 28px; }
QComboBox QAbstractItemView { background: #151515; color: #f4f4f4; border: 1px solid #383838; selection-background-color: #f4f4f4; selection-color: #090909; }
QPushButton { background: #f4f4f4; color: #090909; border: 1px solid #f4f4f4; border-radius: 8px; padding: 10px 15px; font-weight: 700; }
QPushButton:hover { background: #fff; }
QPushButton:pressed { background: #ccc; }
QPushButton:disabled { background: #242424; color: #656565; border-color: #303030; }
QPushButton[quiet="true"] { background: transparent; color: #aaa; border-color: #333; }
QProgressBar { background: #202020; border: 0; border-radius: 4px; height: 8px; color: transparent; }
QProgressBar::chunk { background: #f4f4f4; border-radius: 4px; }
QTableWidget { gridline-color: #242424; padding: 0; }
QHeaderView::section { background: #171717; color: #999; border: 0; border-bottom: 1px solid #2b2b2b; padding: 9px; font-weight: 700; }
QScrollBar:vertical { background: transparent; width: 9px; }
QScrollBar::handle:vertical { background: #3b3b3b; border-radius: 4px; min-height: 28px; }
QStatusBar { background: #090909; color: #888; border-top: 1px solid #242424; }
QToolTip { background: #f4f4f4; color: #090909; border: 0; padding: 5px; }
QScrollArea { background: transparent; border: 0; }
#archiveContent { background: #0c0c0c; }
)CSS";

QLabel* text(const QString& value, const char* id = nullptr) {
    auto* result = new QLabel(value);
    if (id) result->setObjectName(id);
    result->setWordWrap(true);
    return result;
}

QFrame* card(QLayout* layout) {
    auto* result = new QFrame;
    result->setProperty("card", true);
    result->setLayout(layout);
    return result;
}
}

class Operation : public QThread {
    Q_OBJECT
public:
    bool restore;
    QString source, destination, password, codec;
    Operation(bool decrypt, QString src, QString dst, QString pass, QString compression, QObject* parent)
        : QThread(parent), restore(decrypt), source(std::move(src)), destination(std::move(dst)),
          password(std::move(pass)), codec(std::move(compression)) {}
    void run() override {
        try {
            auto report = [this](uint64_t done, uint64_t total, uint64_t output) {
                emit advanced(total ? static_cast<int>(std::min(100.0, 100.0 * done / total)) : 0, done, output);
            };
            if (restore)
                dvx3::decrypt(source.toUtf8().toStdString(), destination.toUtf8().toStdString(), password.toUtf8().toStdString(), report);
            else
                dvx3::encrypt(source.toUtf8().toStdString(), destination.toUtf8().toStdString(), password.toUtf8().toStdString(), "", report, codec.toUtf8().toStdString());
            password.fill(QChar('\0')); password.clear();
            emit completed(QString());
        } catch (const std::exception& error) {
            password.fill(QChar('\0')); password.clear();
            emit completed(QString::fromUtf8(error.what()));
        }
    }
signals:
    void advanced(int percent, quint64 processed, quint64 output);
    void completed(const QString& error);
};

class Window : public QMainWindow {
    Q_OBJECT
    QStackedWidget* pages = nullptr;
    QWidget* sidebar = nullptr;
    QButtonGroup* navigation = nullptr;
    QPushButton *overviewNav = nullptr, *backupNav = nullptr, *restoreNav = nullptr;
    QList<QPushButton*> navButtons;
    QHash<int, QPushButton*> pageButtons;
    QWidget* brandWords = nullptr;
    QLineEdit *source = nullptr, *destination = nullptr, *password = nullptr;
    QComboBox* codec = nullptr;
    QLabel *formTitle = nullptr, *formCopy = nullptr, *status = nullptr,
           *modeMetric = nullptr, *codecMetric = nullptr, *readyMetric = nullptr,
           *passwordHint = nullptr;
    QPushButton* start = nullptr;
    QProgressBar* progress = nullptr;
    QPlainTextEdit* activity = nullptr;
    QTableWidget* codecTable = nullptr;
    Operation* operation = nullptr;
    QAction *reduceMotion = nullptr, *compactSidebar = nullptr;
    bool restoreMode = false;

public:
    Window() {
        setWindowTitle("DVX3 — Backup Manager");
        setMinimumSize(880, 620);
        resize(1180, 760);
        setAcceptDrops(true);
        buildMenus();
        buildUi();
        applyPreferences();
        refreshCodecs();
        showDashboard();
        statusBar()->showMessage("Local engine ready");
    }

    void prepareSmokePage(const QString& page) {
        const QSignalBlocker guard(reduceMotion);
        reduceMotion->setChecked(true);
        if (page == "archive") setMode(false);
        else if (page == "restore") setMode(true);
        else if (page == "codecs") switchPage(Codecs);
        else if (page == "activity") switchPage(Activity);
        else if (page == "about") switchPage(About);
        QApplication::processEvents();
    }

protected:
    void closeEvent(QCloseEvent* event) override {
        if (operation) {
            status->setText("Wait for the current operation before closing.");
            switchPage(Archive);
            event->ignore();
            return;
        }
        QSettings("DVX3", "Backup Manager").setValue("geometry", saveGeometry());
        event->accept();
    }
    void dragEnterEvent(QDragEnterEvent* event) override {
        if (event->mimeData()->hasUrls() && event->mimeData()->urls().size() == 1) event->acceptProposedAction();
    }
    void dropEvent(QDropEvent* event) override {
        const QString path = event->mimeData()->urls().constFirst().toLocalFile();
        if (QFileInfo(path).isDir()) setMode(false);
        else if (path.endsWith(".dvx3", Qt::CaseInsensitive)) setMode(true);
        else return;
        source->setText(path);
        log("Dropped source · " + path);
        event->acceptProposedAction();
    }

private:
    void buildMenus() {
        auto* file = menuBar()->addMenu("File");
        file->addAction("New backup", QKeySequence("Ctrl+N"), this, [this] { setMode(false); });
        file->addAction("Restore archive", QKeySequence("Ctrl+R"), this, [this] { setMode(true); });
        file->addSeparator();
        file->addAction("Quit", QKeySequence::Quit, this, &QWidget::close);
        auto* view = menuBar()->addMenu("View");
        view->addAction("Overview", QKeySequence("Ctrl+1"), this, &Window::showDashboard);
        view->addAction("Archive workspace", QKeySequence("Ctrl+2"), this, [this] { switchPage(Archive); });
        view->addAction("Codec matrix", QKeySequence("Ctrl+3"), this, [this] { switchPage(Codecs); });
        view->addAction("Activity", QKeySequence("Ctrl+4"), this, [this] { switchPage(Activity); });
        view->addSeparator();
        compactSidebar = view->addAction("Compact sidebar");
        compactSidebar->setCheckable(true);
        connect(compactSidebar, &QAction::toggled, this, &Window::setSidebarCompact);
        reduceMotion = view->addAction("Reduce motion");
        reduceMotion->setCheckable(true);
        connect(reduceMotion, &QAction::toggled, this, [](bool value) { QSettings("DVX3", "Backup Manager").setValue("reduceMotion", value); });
        auto* tools = menuBar()->addMenu("Tools");
        tools->addAction("Refresh codec detection", QKeySequence("F5"), this, &Window::refreshCodecs);
        tools->addAction("Copy diagnostics", this, &Window::copyDiagnostics);
        tools->addAction("Command palette…", QKeySequence("Ctrl+K"), this, &Window::showCommandPalette);
        auto* help = menuBar()->addMenu("Help");
        help->addAction("Project documentation", this, [] { QDesktopServices::openUrl(QUrl("https://github.com/tadaka9/Dvx3-Backup-Manager")); });
        help->addAction("About DVX3", this, [this] { switchPage(About); });
    }

    void buildUi() {
        auto* root = new QWidget;
        auto* shell = new QHBoxLayout(root);
        shell->setContentsMargins(0, 0, 0, 0); shell->setSpacing(0);
        sidebar = buildSidebar();
        pages = new QStackedWidget; pages->setObjectName("content");
        pages->addWidget(buildDashboard()); pages->addWidget(buildArchive());
        pages->addWidget(buildCodecs()); pages->addWidget(buildActivity()); pages->addWidget(buildAbout());
        shell->addWidget(sidebar); shell->addWidget(pages, 1);
        setCentralWidget(root);
    }

    QWidget* buildSidebar() {
        auto* panel = new QWidget; panel->setObjectName("sidebar");
        panel->setMinimumWidth(230); panel->setMaximumWidth(230);
        auto* layout = new QVBoxLayout(panel); layout->setContentsMargins(18, 22, 18, 18); layout->setSpacing(8);
        auto* brand = new QHBoxLayout;
        auto* mark = new QLabel; mark->setPixmap(QPixmap(":/brand/logo-mono.png").scaled(44, 44, Qt::KeepAspectRatio, Qt::SmoothTransformation));
        mark->setAccessibleName("DVX3 logo");
        brandWords = new QWidget;
        auto* name = new QVBoxLayout(brandWords);
        name->setContentsMargins(0, 0, 0, 0);
        name->setSpacing(0);
        name->addWidget(text("DVX3", "wordmark"));
        name->addWidget(text("BACKUP MANAGER", "eyebrow"));
        brand->addWidget(mark); brand->addWidget(brandWords); brand->addStretch(); layout->addLayout(brand); layout->addSpacing(26);
        navigation = new QButtonGroup(this); navigation->setExclusive(true);
        overviewNav = nav("Overview", Dashboard, layout); backupNav = nav("Create backup", Archive, layout);
        restoreNav = nav("Restore archive", Archive, layout); nav("Codec matrix", Codecs, layout); nav("Activity", Activity, layout);
        layout->addStretch(); nav("About", About, layout); layout->addWidget(text(QString("CORE %1").arg(DVX3_VERSION), "eyebrow"));
        return panel;
    }

    QPushButton* nav(const QString& title, int page, QVBoxLayout* layout) {
        auto* button = new QPushButton(title); button->setProperty("nav", true); button->setCheckable(true);
        button->setCursor(Qt::PointingHandCursor);
        button->setProperty("fullText", title);
        button->setToolTip(title);
        navButtons.append(button);
        if (page != Archive) pageButtons.insert(page, button);
        navigation->addButton(button); layout->addWidget(button);
        connect(button, &QPushButton::clicked, this, [this, page, button] {
            if (button == backupNav) setMode(false); else if (button == restoreNav) setMode(true); else switchPage(page);
        });
        return button;
    }

    QWidget* shell(const QString& title, const QString& copy, QVBoxLayout** body) {
        auto* page = new QWidget; auto* layout = new QVBoxLayout(page);
        layout->setContentsMargins(42, 36, 42, 34); layout->setSpacing(20);
        layout->addWidget(text(title, "pageTitle")); layout->addWidget(text(copy, "pageSubtitle")); *body = layout; return page;
    }

    QLabel* metric(const QString& caption, const QString& value) {
        auto* layout = new QVBoxLayout; layout->setContentsMargins(20, 18, 20, 18);
        layout->addWidget(text(caption, "eyebrow")); auto* result = text(value, "sectionTitle"); layout->addWidget(result); card(layout); return result;
    }

    QWidget* buildDashboard() {
        QVBoxLayout* layout; auto* page = shell("Control center", "Private, local and under your control.", &layout);
        auto* heroLayout = new QVBoxLayout; heroLayout->setContentsMargins(28, 28, 28, 28); heroLayout->setSpacing(12);
        heroLayout->addWidget(text("Make the archive.\nKeep the key.", "heroTitle"));
        heroLayout->addWidget(text("Authenticated encryption and the codec you choose, powered by one canonical Vala engine.", "heroCopy"));
        auto* actions = new QHBoxLayout; auto* create = new QPushButton("Create a backup"); auto* restore = new QPushButton("Restore an archive");
        create->setStyleSheet("background:#090909;color:#fff;border-color:#090909;"); restore->setStyleSheet("background:transparent;color:#090909;border-color:#090909;");
        connect(create, &QPushButton::clicked, this, [this] { setMode(false); }); connect(restore, &QPushButton::clicked, this, [this] { setMode(true); });
        actions->addWidget(create); actions->addWidget(restore); actions->addStretch(); heroLayout->addLayout(actions);
        auto* hero = new QFrame; hero->setProperty("hero", true); hero->setLayout(heroLayout); layout->addWidget(hero);
        auto* metrics = new QHBoxLayout; modeMetric = metric("ENGINE", "LOCAL"); codecMetric = metric("DEFAULT CODEC", "ZSTD"); readyMetric = metric("CODECS READY", "—");
        metrics->addWidget(modeMetric->parentWidget()); metrics->addWidget(codecMetric->parentWidget()); metrics->addWidget(readyMetric->parentWidget()); layout->addLayout(metrics); layout->addStretch();
        return page;
    }

    QVBoxLayout* pathField(const QString& title, QLineEdit* edit, const QString& buttonTitle, const std::function<void()>& action) {
        auto* group = new QVBoxLayout; group->setSpacing(6); group->addWidget(text(title, "eyebrow"));
        auto* row = new QHBoxLayout; row->setSpacing(8); row->addWidget(edit, 1); auto* button = new QPushButton(buttonTitle); button->setProperty("quiet", true);
        connect(button, &QPushButton::clicked, this, action); row->addWidget(button); group->addLayout(row); return group;
    }

    QWidget* buildArchive() {
        QVBoxLayout* layout; auto* page = shell("Archive workspace", "Create and restore without leaving the local machine.", &layout);
        auto* content = new QWidget;
        content->setObjectName("archiveContent");
        auto* contentLayout = new QVBoxLayout(content);
        contentLayout->setContentsMargins(0, 0, 8, 0);
        contentLayout->setSpacing(14);
        auto* form = new QVBoxLayout; form->setContentsMargins(24, 22, 24, 24); form->setSpacing(13);
        auto* header = new QHBoxLayout; auto* heading = new QVBoxLayout; formTitle = text("Create encrypted backup", "sectionTitle");
        formCopy = text("Choose a directory, destination archive, password and codec.", "pageSubtitle"); heading->addWidget(formTitle); heading->addWidget(formCopy);
        auto* chip = text("ENCRYPT + AUTHENTICATE"); chip->setProperty("chip", true); header->addLayout(heading); header->addStretch(); header->addWidget(chip); form->addLayout(header); form->addSpacing(8);
        source = new QLineEdit; destination = new QLineEdit; password = new QLineEdit; password->setEchoMode(QLineEdit::Password); password->setPlaceholderText("Never stored by DVX3"); codec = new QComboBox;
        form->addLayout(pathField("Source", source, "Browse…", [this] { browseSource(); }));
        form->addLayout(pathField("Destination", destination, "Choose…", [this] { browseDestination(); }));
        auto* passRow = new QHBoxLayout; auto* passGroup = new QVBoxLayout; passGroup->addWidget(text("Password", "eyebrow")); passGroup->addWidget(password);
        passwordHint = text("Use a unique passphrase. DVX3 never stores it and cannot recover it.");
        passwordHint->setProperty("muted", true);
        passGroup->addWidget(passwordHint);
        auto* reveal = new QCheckBox("Show"); connect(reveal, &QCheckBox::toggled, this, [this](bool shown) { password->setEchoMode(shown ? QLineEdit::Normal : QLineEdit::Password); });
        passRow->addLayout(passGroup, 1); passRow->addWidget(reveal, 0, Qt::AlignBottom); form->addLayout(passRow); form->addWidget(text("Compression", "eyebrow")); form->addWidget(codec); contentLayout->addWidget(card(form));
        auto* trust = new QHBoxLayout;
        for (const QString& cue : {QString("LOCAL PROCESSING"), QString("PASSWORD NEVER SAVED"), QString("VERIFY BEFORE EXTRACT")}) {
            auto* item = text(cue);
            item->setProperty("chip", true);
            item->setAlignment(Qt::AlignCenter);
            trust->addWidget(item);
        }
        contentLayout->addLayout(trust);
        auto* footer = new QVBoxLayout; footer->setContentsMargins(22, 18, 22, 18); progress = new QProgressBar; progress->setRange(0, 100); progress->setValue(0);
        auto* action = new QHBoxLayout; status = text("Ready. Drop a directory or .dvx3 archive anywhere in the window."); status->setProperty("muted", true); start = new QPushButton("Create backup"); start->setMinimumWidth(170);
        action->addWidget(status, 1); action->addWidget(start); footer->addWidget(progress); footer->addLayout(action); contentLayout->addStretch();
        auto* scroll = new QScrollArea;
        scroll->setWidgetResizable(true);
        scroll->setFrameShape(QFrame::NoFrame);
        scroll->setWidget(content);
        layout->addWidget(scroll, 1);
        layout->addWidget(card(footer));
        connect(start, &QPushButton::clicked, this, &Window::startOperation);
        connect(source, &QLineEdit::textChanged, this, [this] { updateReadiness(); });
        connect(destination, &QLineEdit::textChanged, this, [this] { updateReadiness(); });
        connect(password, &QLineEdit::textChanged, this, [this](const QString& value) {
            passwordHint->setText(value.isEmpty()
                ? "Use a unique passphrase. DVX3 never stores it and cannot recover it."
                : value.size() < 16
                    ? QString("%1 characters entered. A longer passphrase is easier to remember and harder to guess.").arg(value.size())
                    : QString("%1 characters entered. Keep this passphrase somewhere safe.").arg(value.size()));
            updateReadiness();
        });
        updateReadiness();
        return page;
    }

    QWidget* buildCodecs() {
        QVBoxLayout* layout; auto* page = shell("Codec matrix", "Capabilities detected on this machine right now.", &layout);
        codecTable = new QTableWidget(0, 2); codecTable->setHorizontalHeaderLabels({"Codec", "Status"}); codecTable->horizontalHeader()->setStretchLastSection(true);
        codecTable->verticalHeader()->setVisible(false); codecTable->setEditTriggers(QAbstractItemView::NoEditTriggers); codecTable->setSelectionBehavior(QAbstractItemView::SelectRows); layout->addWidget(codecTable, 1);
        auto* note = text("Codec executables are detected locally. Custom profiles remain available through DVX3_CODECS or the native configuration directory."); note->setProperty("muted", true); layout->addWidget(note); return page;
    }

    QWidget* buildActivity() {
        QVBoxLayout* layout; auto* page = shell("Activity", "This session only. Passwords never appear here.", &layout);
        activity = new QPlainTextEdit; activity->setReadOnly(true); activity->setPlaceholderText("Operations and interface events will appear here."); layout->addWidget(activity, 1);
        auto* clear = new QPushButton("Clear activity"); clear->setProperty("quiet", true); connect(clear, &QPushButton::clicked, activity, &QPlainTextEdit::clear); layout->addWidget(clear, 0, Qt::AlignRight); return page;
    }

    QWidget* buildAbout() {
        QVBoxLayout* layout; auto* page = shell("About DVX3", "A small interface around a serious local engine.", &layout);
        auto* body = new QVBoxLayout; body->setContentsMargins(26, 26, 26, 26); body->setSpacing(14); body->addWidget(text("DVX3", "heroTitle")); body->addWidget(text(QString("Backup Manager · %1").arg(DVX3_VERSION), "sectionTitle"));
        body->addWidget(text("The Vala core owns archive creation, restore, codec validation and cryptography. Qt owns presentation only. Argon2id and libsodium protect the archive; your password stays yours."));
        auto* docs = new QPushButton("Open project documentation"); connect(docs, &QPushButton::clicked, this, [] { QDesktopServices::openUrl(QUrl("https://github.com/tadaka9/Dvx3-Backup-Manager")); }); body->addWidget(docs, 0, Qt::AlignLeft); layout->addWidget(card(body)); layout->addStretch(); return page;
    }

    void applyPreferences() {
        QSettings settings("DVX3", "Backup Manager"); restoreGeometry(settings.value("geometry").toByteArray());
        reduceMotion->setChecked(settings.value("reduceMotion", false).toBool()); compactSidebar->setChecked(settings.value("compactSidebar", false).toBool());
    }
    void showDashboard() { overviewNav->setChecked(true); switchPage(Dashboard); }
    void setMode(bool restoring) {
        restoreMode = restoring; (restoring ? restoreNav : backupNav)->setChecked(true);
        formTitle->setText(restoring ? "Restore encrypted archive" : "Create encrypted backup");
        formCopy->setText(restoring ? "Select a .dvx3 archive and an empty destination directory." : "Choose a directory, destination archive, password and codec.");
        source->setPlaceholderText(restoring ? "Encrypted .dvx3 archive" : "Directory to back up"); destination->setPlaceholderText(restoring ? "Empty restore directory" : "Output .dvx3 archive");
        codec->setEnabled(!restoring); start->setText(restoring ? "Restore archive" : "Create backup"); modeMetric->setText(restoring ? "RESTORE" : "LOCAL"); progress->setValue(0);
        status->setText(restoring ? "Restore verifies the archive before extraction and requires an empty directory." : "Ready. Drop a directory anywhere in the window."); switchPage(Archive);
        updateReadiness();
    }
    void switchPage(int index) {
        if (pageButtons.contains(index)) pageButtons.value(index)->setChecked(true);
        if (pages->currentIndex() == index) return;
        pages->setCurrentIndex(index);
        if (index == Codecs) refreshCodecs();
        if (reduceMotion && reduceMotion->isChecked()) return;
        auto* effect = new QGraphicsOpacityEffect(pages->currentWidget()); pages->currentWidget()->setGraphicsEffect(effect);
        auto* animation = new QPropertyAnimation(effect, "opacity", effect); animation->setDuration(210); animation->setStartValue(0.0); animation->setEndValue(1.0); animation->setEasingCurve(QEasingCurve::OutCubic);
        connect(animation, &QPropertyAnimation::finished, effect, [effect] { effect->setEnabled(false); }); animation->start(QAbstractAnimation::DeleteWhenStopped);
    }
    void setSidebarCompact(bool compact) {
        QSettings("DVX3", "Backup Manager").setValue("compactSidebar", compact); const int width = compact ? 82 : 230;
        brandWords->setVisible(!compact);
        for (int index = 0; index < navButtons.size(); ++index)
            navButtons[index]->setText(compact ? QString("%1").arg(index + 1, 2, 10, QChar('0'))
                                               : navButtons[index]->property("fullText").toString());
        if (reduceMotion && reduceMotion->isChecked()) { sidebar->setMinimumWidth(width); sidebar->setMaximumWidth(width); return; }
        auto* group = new QParallelAnimationGroup(sidebar);
        for (const QByteArray& property : {QByteArray("minimumWidth"), QByteArray("maximumWidth")}) {
            auto* animation = new QPropertyAnimation(sidebar, property, group);
            animation->setDuration(260);
            animation->setEndValue(width);
            animation->setEasingCurve(QEasingCurve::OutCubic);
            group->addAnimation(animation);
        }
        group->start(QAbstractAnimation::DeleteWhenStopped);
    }
    void browseSource() {
        const QString path = restoreMode ? QFileDialog::getOpenFileName(this, "Open encrypted archive", QString(), "DVX3 archives (*.dvx3)") : QFileDialog::getExistingDirectory(this, "Choose source directory");
        if (!path.isEmpty()) source->setText(path);
    }
    void browseDestination() {
        QString path = restoreMode ? QFileDialog::getExistingDirectory(this, "Choose empty restore directory") : QFileDialog::getSaveFileName(this, "Save encrypted archive", QString(), "DVX3 archives (*.dvx3)");
        if (!restoreMode && !path.isEmpty() && !path.endsWith(".dvx3", Qt::CaseInsensitive))
            path += ".dvx3";
        if (!path.isEmpty()) destination->setText(path);
    }
    void startOperation() {
        if (source->text().trimmed().isEmpty() || destination->text().trimmed().isEmpty() || password->text().isEmpty()) { QMessageBox::warning(this, "Missing information", "Choose source, destination and password."); return; }
        if (restoreMode && !source->text().endsWith(".dvx3", Qt::CaseInsensitive)) { QMessageBox::warning(this, "Not a DVX3 archive", "Restore expects a .dvx3 archive."); return; }
        start->setEnabled(false); progress->setRange(0, 0); status->setText(restoreMode ? "Authenticating archive…" : "Preparing archive…"); const QString selectedCodec = codec->currentText();
        operation = new Operation(restoreMode, source->text(), destination->text(), password->text(), selectedCodec, this); password->clear(); password->setEchoMode(QLineEdit::Password);
        log(QString("%1 started · %2").arg(restoreMode ? "Restore" : "Backup", restoreMode ? "archive metadata" : selectedCodec));
        connect(operation, &Operation::advanced, this, [this](int value, quint64 processed, quint64 output) { progress->setRange(0, 100); progress->setValue(value); status->setText(QString("%1% · %2 processed · %3 output").arg(value).arg(QString::fromStdString(dvx3::format_size(processed))).arg(QString::fromStdString(dvx3::format_size(output)))); });
        connect(operation, &Operation::completed, this, [this](const QString& error) { progress->setRange(0, 100); progress->setValue(error.isEmpty() ? 100 : 0); status->setText(error.isEmpty() ? "Completed successfully." : error); log(error.isEmpty() ? "Operation completed successfully" : "Operation failed · " + error); });
        connect(operation, &QThread::finished, this, [this] {
            operation->deleteLater();
            operation = nullptr;
            updateReadiness(false);
        });
        operation->start();
    }
    void updateReadiness(bool explain = true) {
        if (!start || operation) return;
        int missing = 0;
        if (source->text().trimmed().isEmpty()) ++missing;
        if (destination->text().trimmed().isEmpty()) ++missing;
        if (password->text().isEmpty()) ++missing;
        const bool sourceTypeValid = !restoreMode || source->text().trimmed().isEmpty()
            || source->text().endsWith(".dvx3", Qt::CaseInsensitive);
        start->setEnabled(missing == 0 && sourceTypeValid);
        if (!explain) return;
        if (!sourceTypeValid)
            status->setText("Choose a .dvx3 archive to restore.");
        else if (missing > 0)
            status->setText(QString("%1 %2 remaining before you can continue.")
                .arg(missing).arg(missing == 1 ? "detail" : "details"));
        else
            status->setText(restoreMode
                ? "Ready to verify and restore into the empty destination."
                : "Ready to create the encrypted archive.");
    }
    void refreshCodecs() {
        if (!codec || !codecTable) return;
        const QString selected = codec->currentText();
        codec->clear();
        codecTable->setRowCount(0);
        int count = 0;
        int available = 0;
        gchar** names = dvx3_codec_names(&count);
        for (int row = 0; row < count; ++row) { const QString name = QString::fromUtf8(names[row]); const bool ready = dvx3_codec_available(names[row]); codecTable->insertRow(row); codecTable->setItem(row, 0, new QTableWidgetItem(name)); codecTable->setItem(row, 1, new QTableWidgetItem(ready ? "Available" : "Missing tool or adapter")); if (ready) { codec->addItem(name); ++available; } }
        g_strfreev(names); codec->setCurrentText(codec->findText(selected) >= 0 ? selected : "zstd"); readyMetric->setText(QString("%1 / %2").arg(available).arg(count)); codecMetric->setText(codec->currentText().toUpper()); codecTable->resizeColumnsToContents(); statusBar()->showMessage(QString("%1 of %2 codecs available").arg(available).arg(count), 3500);
    }
    void log(const QString& message) { activity->appendPlainText(QTime::currentTime().toString("HH:mm:ss") + "  " + message); }
    void copyDiagnostics() {
        QStringList ready; for (int row = 0; row < codecTable->rowCount(); ++row) if (codecTable->item(row, 1)->text() == "Available") ready << codecTable->item(row, 0)->text();
        QApplication::clipboard()->setText(QString("DVX3 %1\nQt %2\nOS %3\nAvailable codecs: %4").arg(DVX3_VERSION, qVersion(), QSysInfo::prettyProductName(), ready.join(", "))); statusBar()->showMessage("Diagnostics copied", 2500); log("Diagnostics copied to clipboard");
    }
    void showCommandPalette() {
        QDialog dialog(this); dialog.setWindowTitle("Command palette"); dialog.resize(520, 380); auto* layout = new QVBoxLayout(&dialog); auto* search = new QLineEdit; search->setPlaceholderText("Type a command…"); auto* list = new QListWidget;
        const QList<QPair<QString, QString>> commands = {{"Go to overview","dashboard"},{"Create a backup","backup"},{"Restore an archive","restore"},{"Inspect codecs","codecs"},{"Open activity","activity"},{"Copy diagnostics","diagnostics"},{"About DVX3","about"}};
        for (const auto& command : commands) { auto* item = new QListWidgetItem(command.first, list); item->setData(Qt::UserRole, command.second); }
        layout->addWidget(search); layout->addWidget(list); connect(search, &QLineEdit::textChanged, &dialog, [list](const QString& query) { for (int row = 0; row < list->count(); ++row) list->item(row)->setHidden(!list->item(row)->text().contains(query, Qt::CaseInsensitive)); });
        connect(list, &QListWidget::itemActivated, &dialog, [this, &dialog](QListWidgetItem* item) { const QString command = item->data(Qt::UserRole).toString(); if (command == "dashboard") showDashboard(); else if (command == "backup") setMode(false); else if (command == "restore") setMode(true); else if (command == "codecs") switchPage(Codecs); else if (command == "activity") switchPage(Activity); else if (command == "diagnostics") copyDiagnostics(); else if (command == "about") switchPage(About); dialog.accept(); });
        list->setCurrentRow(0); search->setFocus(); dialog.exec();
    }
};

int main(int argc, char** argv) {
    QApplication app(argc, argv); app.setApplicationName("DVX3 Backup Manager"); app.setOrganizationName("DVX3"); app.setWindowIcon(QIcon(":/brand/logo.png")); app.setStyleSheet(theme);
    if (app.arguments().contains("--version")) { qInfo("DVX3 %s", DVX3_VERSION); return 0; }
    Window window; window.show();
    if (app.arguments().contains("--smoke-test")) {
        app.processEvents();
        window.prepareSmokePage(qEnvironmentVariable("DVX3_SMOKE_PAGE"));
        const auto frame = window.grab();
        if (frame.isNull()) return 1;
        const QString output = qEnvironmentVariable("DVX3_SMOKE_IMAGE");
        if (!output.isEmpty() && !frame.save(output)) return 1;
        return 0;
    }
    return app.exec();
}

#include "main.moc"
