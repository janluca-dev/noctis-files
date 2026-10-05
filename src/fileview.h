// ============================================================================
//  fileview.h — FileView, im Zuschnitt von Quickshell.Io.
//
//  Gelesen wird beim Fertigwerden des Objekts und bei jedem neuen Pfad;
//  `loaded` kommt erst danach, also immer an einem Punkt, an dem die
//  Signalverbindungen in QML schon stehen.
//
//  BEOBACHTEN. QFileSystemWatcher verliert eine Datei, sobald sie durch eine
//  neue ersetzt wird — und genau so schreiben fast alle Programme ihre
//  Einstellungen (in eine Zwischendatei, dann umbenennen). Deshalb wird
//  zusätzlich der Ordner beobachtet und die Datei danach neu angemeldet.
// ============================================================================
#pragma once

#include <QByteArray>
#include <QFileSystemWatcher>
#include <QObject>
#include <QQmlParserStatus>
#include <QTimer>

class FileView : public QObject, public QQmlParserStatus {
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool watchChanges READ watchChanges WRITE setWatchChanges NOTIFY watchChangesChanged)
    Q_PROPERTY(bool printErrors MEMBER m_printErrors NOTIFY printErrorsChanged)
    Q_PROPERTY(bool blockLoading MEMBER m_blockLoading NOTIFY blockLoadingChanged)
    Q_PROPERTY(bool blockWrites MEMBER m_blockWrites NOTIFY blockWritesChanged)
    Q_PROPERTY(bool atomicWrites MEMBER m_atomicWrites NOTIFY atomicWritesChanged)
public:
    explicit FileView(QObject *parent = nullptr);

    void classBegin() override {}
    void componentComplete() override;

    QString path() const { return m_path; }
    void setPath(const QString &p);
    bool watchChanges() const { return m_watch; }
    void setWatchChanges(bool w);

    Q_INVOKABLE QString text() const { return QString::fromUtf8(m_data); }
    Q_INVOKABLE void setText(const QString &t);
    Q_INVOKABLE void reload();

signals:
    void pathChanged();
    void watchChangesChanged();
    void printErrorsChanged();
    void blockLoadingChanged();
    void blockWritesChanged();
    void atomicWritesChanged();
    // In QML `onLoaded` — dieselbe Benennung wie in Quickshell.
    void loaded();
    void loadFailed(const QString &error);
    void fileChanged();

private:
    bool read();
    void load();
    void rewatch();

    QString m_path;
    QByteArray m_data;
    bool m_watch = false;
    bool m_printErrors = true;
    bool m_blockLoading = false;
    bool m_blockWrites = false;
    bool m_atomicWrites = false;
    bool m_complete = false;
    QFileSystemWatcher m_watcher;
    QTimer m_settle;
};
