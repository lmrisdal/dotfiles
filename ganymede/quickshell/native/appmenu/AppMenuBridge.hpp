// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QString>

#include <memory>

class QAction;
class DBusMenuImporter;
class QDBusServiceWatcher;
class QMenu;
class QPoint;

class AppMenuBridge final : public QObject
{
    Q_OBJECT

public:
    explicit AppMenuBridge(QObject *parent = nullptr);
    ~AppMenuBridge() override;

    void handleCommand(const QJsonObject &command);

Q_SIGNALS:
    void messageReady(const QJsonObject &message);

private:
    void updateApplication(const QString &applicationName, const QString &service, const QString &path);
    void clearMenu(bool clearEndpoint = true);
    void updateRootMenu(QMenu *menu);
    void reconnectActions();
    void publishState();
    void publishOpenState(bool open);
    void openMenu(int index, const QPoint &anchorPosition, const QString &screenName);
    void closeMenu();
    void prepareAction(int actionId);
    void triggerAction(int actionId);
    void sendMenuEvent(QMenu *menu, const QString &eventName);
    [[nodiscard]] QJsonArray serializeMenu(const QMenu *menu) const;
    [[nodiscard]] QJsonObject serializeAction(const QAction *action) const;
    [[nodiscard]] QAction *actionAt(int index) const;
    [[nodiscard]] QString displayText(const QString &text) const;

    QString m_applicationName;
    QString m_service;
    QString m_path;
    QString m_currentScreen;
    std::unique_ptr<DBusMenuImporter> m_importer;
    QDBusServiceWatcher *m_serviceWatcher = nullptr;
    QMenu *m_rootMenu = nullptr;
    QMenu *m_currentMenu = nullptr;
    QList<QMetaObject::Connection> m_actionConnections;
    int m_currentIndex = -1;
};
