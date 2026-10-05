// ============================================================================
//  host.h — was die Oberfläche vom Programm braucht, das sie trägt.
//
//  In der Quickshell-Fassung kam das von Quickshell selbst (Umgebung,
//  Fenster) oder aus Hilfsprogrammen (wl-copy, hyprctl). Als eigenes
//  Programm muss es auf jedem Schreibtisch laufen — deshalb steht hier, was
//  vorher stillschweigend vorausgesetzt war:
//
//   * Umgebung und Pfade (`env`, `home`, `ctl`),
//   * die Zwischenablage — über Qt, mit wl-copy als Verstärkung unter
//     Wayland, weil Qt die Ablage mit dem Fenster wieder hergibt,
//   * EIN Fenster für alle Aufrufe: ein zweiter Start reicht seinen Ordner
//     an das laufende Programm weiter und beendet sich.
// ============================================================================
#pragma once

#include <QLocalServer>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QVariantMap>
#include <QWindow>

class Host : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString home READ home CONSTANT)
    Q_PROPERTY(QString ctl READ ctl CONSTANT)
    Q_PROPERTY(QString python READ python CONSTANT)
    Q_PROPERTY(QString startPath READ startPath CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(bool compositorBlur READ compositorBlur CONSTANT)
public:
    explicit Host(QObject *parent = nullptr);

    QString home() const;
    QString ctl() const { return m_ctl; }
    QString python() const { return m_python; }
    QString startPath() const { return m_startPath; }
    QString version() const;
    bool compositorBlur() const;

    void setStartPath(const QString &p) { m_startPath = p; }
    void setWindow(QWindow *w) { m_window = w; }

    // Einzelinstanz. `claim` gibt false zurück, wenn schon ein Fenster
    // steht — dann ist der Auftrag bereits übergeben.
    bool claim(const QString &path);

    Q_INVOKABLE QString env(const QString &name) const;

    Q_INVOKABLE void copyFiles(const QString &mode, const QStringList &paths);
    Q_INVOKABLE void copyText(const QStringList &lines);
    Q_INVOKABLE QVariantMap pasteFiles();

    Q_INVOKABLE void raiseWindow();

signals:
    void openRequested(const QString &path);

private:
    static QString socketPath();
    void onConnection();
    bool hasWlCopy() const;

    QString m_ctl;
    QString m_python;
    QString m_startPath;
    QPointer<QWindow> m_window;
    QLocalServer *m_server = nullptr;
};
