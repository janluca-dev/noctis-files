// ============================================================================
//  process.h — Process, StdioCollector, SplitParser.
//
//  Dieselben Namen und dieselbe Bedienung wie in Quickshell.Io. Das ist
//  Absicht: die Oberfläche ist aus der Quickshell-Fassung von Noctis Files
//  übernommen, und jede Stelle, an der ein Prozess anders heißt oder anders
//  tickt, wäre eine Stelle, an der die beiden Fassungen auseinanderlaufen.
//
//  Die Regeln, auf die sich die Oberfläche verlässt:
//
//   * `running = true` startet, aber nur, wenn gerade nichts läuft. Ein
//     zweites `true` während des Laufs tut nichts.
//   * `command` wird beim START gelesen. Wer es während des Laufs ändert,
//     ändert den NÄCHSTEN Lauf.
//   * Erst kommt das Ende des Datenstroms (streamFinished / letzte Zeile),
//     dann `running = false`, dann `exited`. In `onExited` darf man sofort
//     wieder starten — dafür bekommt jeder Lauf ein frisches QProcess.
// ============================================================================
#pragma once

#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QQmlEngine>
#include <QStringList>
#include <QVariant>

class DataStreamParser : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    virtual void begin() {}
    virtual void feed(const QByteArray &data) = 0;
    virtual void end() {}
};

// Sammelt alles und meldet sich einmal, wenn der Strom zu Ende ist.
class StdioCollector : public DataStreamParser {
    Q_OBJECT
    Q_PROPERTY(QString text READ text NOTIFY textChanged)
public:
    using DataStreamParser::DataStreamParser;
    QString text() const { return QString::fromUtf8(m_buf); }
    void begin() override;
    void feed(const QByteArray &data) override { m_buf.append(data); }
    void end() override;
signals:
    void textChanged();
    void streamFinished();
private:
    QByteArray m_buf;
};

// Zerlegt den Strom an einer Marke (Vorgabe: Zeilenende) und meldet jedes
// Stück einzeln, sobald es vollständig ist.
class SplitParser : public DataStreamParser {
    Q_OBJECT
    Q_PROPERTY(QString splitMarker READ splitMarker WRITE setSplitMarker NOTIFY splitMarkerChanged)
public:
    using DataStreamParser::DataStreamParser;
    QString splitMarker() const { return m_marker; }
    void setSplitMarker(const QString &m);
    void begin() override { m_buf.clear(); }
    void feed(const QByteArray &data) override;
    void end() override;
signals:
    void read(const QString &data);
    void splitMarkerChanged();
private:
    QString m_marker = QStringLiteral("\n");
    QByteArray m_buf;
};

class Process : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList command READ command WRITE setCommand NOTIFY commandChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(bool stdinEnabled READ stdinEnabled WRITE setStdinEnabled NOTIFY stdinEnabledChanged)
    Q_PROPERTY(DataStreamParser *stdout READ stdoutParser WRITE setStdoutParser NOTIFY stdoutChanged)
    Q_PROPERTY(QString workingDirectory READ workingDirectory WRITE setWorkingDirectory NOTIFY workingDirectoryChanged)
public:
    explicit Process(QObject *parent = nullptr);
    ~Process() override;

    QVariantList command() const { return m_command; }
    void setCommand(const QVariantList &c);
    bool running() const { return m_running; }
    void setRunning(bool r);
    bool stdinEnabled() const { return m_stdin; }
    void setStdinEnabled(bool s);
    DataStreamParser *stdoutParser() const { return m_stdout; }
    void setStdoutParser(DataStreamParser *p);
    QString workingDirectory() const { return m_cwd; }
    void setWorkingDirectory(const QString &d);

    Q_INVOKABLE void write(const QString &data);
    Q_INVOKABLE void signal(int sig);

signals:
    void commandChanged();
    void runningChanged();
    void stdinEnabledChanged();
    void stdoutChanged();
    void workingDirectoryChanged();
    void started();
    void exited(int exitCode, int exitStatus);

private:
    void start();
    void stop();
    void onFinished(QProcess *p, int code, QProcess::ExitStatus st);

    QVariantList m_command;
    bool m_running = false;
    bool m_stdin = false;
    QPointer<DataStreamParser> m_stdout;
    QString m_cwd;
    QProcess *m_proc = nullptr;
};
