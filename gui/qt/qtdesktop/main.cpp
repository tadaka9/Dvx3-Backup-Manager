/* Qt owns presentation only. Every archive operation uses the generated Vala C API. */
#include "dvx3.hpp"
#include <algorithm>
#include <QApplication>
#include <QCloseEvent>
#include <QComboBox>
#include <QFileDialog>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QProgressBar>
#include <QPushButton>
#include <QThread>
#include <QVBoxLayout>
#include <QWidget>

class Operation : public QThread {
    Q_OBJECT
public:
    bool restore;
    QString source, destination, password, codec;
    explicit Operation(bool decrypt, QString src, QString dst, QString pass, QString compression, QObject* parent)
        : QThread(parent), restore(decrypt), source(src), destination(dst), password(pass), codec(compression) {}
    void run() override {
        try {
            auto progress = [this](uint64_t processed, uint64_t total, uint64_t) {
                emit advanced(total ? static_cast<int>(std::min(100.0, 100.0 * processed / total)) : 0);
            };
            if (restore) dvx3::decrypt(source.toUtf8().toStdString(), destination.toUtf8().toStdString(), password.toUtf8().toStdString(), progress);
            else dvx3::encrypt(source.toUtf8().toStdString(), destination.toUtf8().toStdString(), password.toUtf8().toStdString(), "", progress, codec.toUtf8().toStdString());
            password.fill(QChar('\0')); password.clear();
            emit completed(QString());
        } catch (const std::exception& e) {
            password.fill(QChar('\0')); password.clear();
            emit completed(QString::fromUtf8(e.what()));
        }
    }
signals:
    void advanced(int percent);
    void completed(const QString& error);
};

class Window : public QWidget {
    Q_OBJECT
    QLineEdit *source, *destination, *password;
    QComboBox *mode, *codec;
    QPushButton* start;
    QProgressBar* progress;
    QLabel* status;
    Operation* operation = nullptr;
public:
    Window() {
        setWindowTitle("Dvx3 Backup Manager");
        auto* layout = new QVBoxLayout(this);
        auto* form = new QFormLayout;
        mode = new QComboBox; mode->addItems({"Create backup", "Restore backup"});
        source = new QLineEdit; destination = new QLineEdit;
        password = new QLineEdit; password->setEchoMode(QLineEdit::Password);
        codec = new QComboBox;
        int length = 0;
        gchar** names = dvx3_codec_names(&length);
        for (int i = 0; i < length; ++i) if (dvx3_codec_available(names[i])) codec->addItem(QString::fromUtf8(names[i]));
        g_strfreev(names);
        codec->setCurrentText("zstd");
        form->addRow("Operation", mode);
        form->addRow("Source", source);
        auto* browseSource = new QPushButton("Choose source…");
        form->addRow(browseSource);
        form->addRow("Destination", destination);
        auto* browseDestination = new QPushButton("Choose destination…");
        form->addRow(browseDestination);
        form->addRow("Password", password); form->addRow("Compression", codec);
        layout->addLayout(form);
        layout->addWidget(new QLabel("Restore into an empty directory. Keep your password: it is never saved."));
        progress = new QProgressBar; progress->setRange(0, 100); layout->addWidget(progress);
        status = new QLabel("Ready"); status->setWordWrap(true); layout->addWidget(status);
        start = new QPushButton("Start"); layout->addWidget(start);
        connect(mode, &QComboBox::currentIndexChanged, this, [this](int index) { codec->setEnabled(index == 0); });
        connect(browseSource, &QPushButton::clicked, this, [this]() {
            auto path = mode->currentIndex() == 0 ? QFileDialog::getExistingDirectory(this, "Source directory")
                : QFileDialog::getOpenFileName(this, "Archive", QString(), "Dvx3 archives (*.dvx3)");
            if (!path.isEmpty()) source->setText(path);
        });
        connect(browseDestination, &QPushButton::clicked, this, [this]() {
            auto path = mode->currentIndex() == 0 ? QFileDialog::getSaveFileName(this, "Save archive", QString(), "Dvx3 archives (*.dvx3)")
                : QFileDialog::getExistingDirectory(this, "Empty restore directory");
            if (!path.isEmpty()) destination->setText(path);
        });
        connect(start, &QPushButton::clicked, this, [this]() {
            if (source->text().isEmpty() || destination->text().isEmpty() || password->text().isEmpty()) {
                QMessageBox::warning(this, "Missing information", "Choose source, destination and password."); return;
            }
            start->setEnabled(false); mode->setEnabled(false);
            progress->setRange(0, 0); status->setText("Preparing archive…");
            operation = new Operation(mode->currentIndex() == 1, source->text(), destination->text(), password->text(), codec->currentText(), this);
            password->clear();
            connect(operation, &Operation::advanced, this, [this](int value) {
                progress->setRange(0, 100); progress->setValue(value); status->setText("Processing…");
            });
            connect(operation, &Operation::completed, this, [this](const QString& error) {
                progress->setRange(0, 100); progress->setValue(error.isEmpty() ? 100 : 0);
                status->setText(error.isEmpty() ? "Completed" : error);
            });
            connect(operation, &QThread::finished, this, [this]() {
                operation->deleteLater(); operation = nullptr;
                start->setEnabled(true); mode->setEnabled(true);
            });
            operation->start();
        });
        resize(650, 350);
    }
protected:
    void closeEvent(QCloseEvent* event) override {
        if (operation) { status->setText("Wait for the current operation before closing."); event->ignore(); }
        else event->accept();
    }
};
int main(int argc, char** argv) {
    QApplication app(argc, argv);
    if (app.arguments().contains("--version")) { qInfo("Dvx3 %s", DVX3_VERSION); return 0; }
    Window window; window.show();
    if (app.arguments().contains("--smoke-test")) {
        // Construct and render the real window without blocking automated runners.
        app.processEvents();
        window.grab();
        return 0;
    }
    return app.exec();
}
#include "main.moc"
