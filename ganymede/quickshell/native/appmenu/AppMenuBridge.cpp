// SPDX-License-Identifier: GPL-2.0-or-later

#include "AppMenuBridge.hpp"

#include "dbusmenuqt/dbusmenuimporter.h"

#include <QAction>
#include <QActionGroup>
#include <QBuffer>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QIcon>
#include <QJsonArray>
#include <QKeySequence>
#include <QMenu>
#include <QPixmap>
#include <QPoint>
#include <QVariant>

#include <functional>

namespace {

class ThemedDBusMenuImporter final : public DBusMenuImporter
{
public:
    using DBusMenuImporter::DBusMenuImporter;

protected:
    QIcon iconForName(const QString &name) override
    {
        return QIcon::fromTheme(name);
    }
};

} // namespace

AppMenuBridge::AppMenuBridge(QObject *parent)
    : QObject(parent)
    , m_serviceWatcher(new QDBusServiceWatcher(this))
{
    m_serviceWatcher->setConnection(QDBusConnection::sessionBus());
    m_serviceWatcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &service) {
        if (service == m_service) {
            clearMenu();
            publishState();
        }
    });
}

AppMenuBridge::~AppMenuBridge()
{
    clearMenu();
}

void AppMenuBridge::handleCommand(const QJsonObject &command)
{
    const QString commandName = command.value(QStringLiteral("command")).toString();
    if (commandName == QStringLiteral("set-active")) {
        updateApplication(
            command.value(QStringLiteral("applicationName")).toString(),
            command.value(QStringLiteral("service")).toString(),
            command.value(QStringLiteral("path")).toString());
    } else if (commandName == QStringLiteral("open")) {
        openMenu(
            command.value(QStringLiteral("index")).toInt(-1),
            QPoint(command.value(QStringLiteral("x")).toInt(), command.value(QStringLiteral("y")).toInt()),
            command.value(QStringLiteral("screen")).toString());
    } else if (commandName == QStringLiteral("close")) {
        closeMenu();
    } else if (commandName == QStringLiteral("prepare-action")) {
        prepareAction(command.value(QStringLiteral("actionId")).toInt(-1));
    } else if (commandName == QStringLiteral("trigger")) {
        triggerAction(command.value(QStringLiteral("actionId")).toInt(-1));
    }
}

void AppMenuBridge::updateApplication(const QString &applicationName, const QString &service, const QString &path)
{
    const bool endpointChanged = service != m_service || path != m_path;
    m_applicationName = applicationName;

    if (!endpointChanged) {
        if (m_importer)
            m_importer->updateMenu();
        else
            publishState();
        return;
    }

    clearMenu();
    if (service.isEmpty() || path.isEmpty()) {
        publishState();
        return;
    }

    m_service = service;
    m_path = path;
    m_serviceWatcher->setWatchedServices({m_service});
    m_importer = std::make_unique<ThemedDBusMenuImporter>(m_service, m_path, this);
    DBusMenuImporter *const importer = m_importer.get();

    connect(importer, &DBusMenuImporter::menuUpdated, this, [this, importer](QMenu *menu) {
        if (importer != m_importer.get())
            return;

        if (menu == importer->menu()) {
            updateRootMenu(menu);
        } else if (m_rootMenu) {
            reconnectActions();
            publishState();
        }
    });
    connect(importer, &DBusMenuImporter::actionActivationRequested, this, [this](QAction *action) {
        if (!m_rootMenu || !action)
            return;

        const int index = m_rootMenu->actions().indexOf(action);
        if (index >= 0)
            openMenu(index, {}, m_currentScreen);
    });

    importer->updateMenu();
    publishState();
}

void AppMenuBridge::clearMenu(bool clearEndpoint)
{
    if (m_currentMenu)
        sendMenuEvent(m_currentMenu, QStringLiteral("closed"));

    if (m_currentIndex >= 0)
        publishOpenState(false);

    m_currentIndex = -1;
    m_currentMenu = nullptr;
    m_currentScreen.clear();
    m_rootMenu = nullptr;
    for (const QMetaObject::Connection &connection : std::as_const(m_actionConnections))
        disconnect(connection);
    m_actionConnections.clear();
    m_importer.reset();

    if (clearEndpoint) {
        m_service.clear();
        m_path.clear();
        m_serviceWatcher->setWatchedServices({});
    }
}

void AppMenuBridge::updateRootMenu(QMenu *menu)
{
    if (!m_importer || menu != m_importer->menu())
        return;

    m_rootMenu = menu;
    reconnectActions();

    for (QAction *action : menu->actions()) {
        if (action->menu())
            m_importer->updateMenu(action->menu());
    }

    publishState();
}

void AppMenuBridge::reconnectActions()
{
    for (const QMetaObject::Connection &connection : std::as_const(m_actionConnections))
        disconnect(connection);
    m_actionConnections.clear();

    if (!m_rootMenu)
        return;

    const std::function<void(QMenu *)> connectMenu = [this, &connectMenu](QMenu *menu) {
        for (QAction *action : menu->actions()) {
            m_actionConnections.append(connect(action, &QAction::changed, this, &AppMenuBridge::publishState));
            m_actionConnections.append(connect(action, &QObject::destroyed, this, [this]() {
                publishState();
            }));
            if (action->menu())
                connectMenu(action->menu());
        }
    };
    connectMenu(m_rootMenu);
}

void AppMenuBridge::publishState()
{
    const QJsonArray entries = m_rootMenu ? serializeMenu(m_rootMenu) : QJsonArray();
    bool menuAvailable = false;
    for (const QJsonValue &value : entries) {
        const QJsonObject action = value.toObject();
        menuAvailable = menuAvailable
            || (action.value(QStringLiteral("visible")).toBool()
                && !action.value(QStringLiteral("separator")).toBool());
    }

    Q_EMIT messageReady({
        {QStringLiteral("event"), QStringLiteral("state")},
        {QStringLiteral("protocol"), 1},
        {QStringLiteral("applicationName"), m_applicationName},
        {QStringLiteral("menuAvailable"), menuAvailable},
        {QStringLiteral("entries"), entries},
    });
}

void AppMenuBridge::publishOpenState(bool open)
{
    Q_EMIT messageReady({
        {QStringLiteral("event"), open ? QStringLiteral("menu-opened") : QStringLiteral("menu-closed")},
        {QStringLiteral("protocol"), 1},
        {QStringLiteral("index"), open ? m_currentIndex : -1},
        {QStringLiteral("screen"), m_currentScreen},
    });
}

void AppMenuBridge::openMenu(int index, const QPoint &anchorPosition, const QString &screenName)
{
    Q_UNUSED(anchorPosition)

    QAction *action = actionAt(index);
    if (!action || !action->isVisible() || !action->isEnabled()) {
        Q_EMIT messageReady({
            {QStringLiteral("event"), QStringLiteral("menu-open-failed")},
            {QStringLiteral("protocol"), 1},
        });
        return;
    }

    QMenu *menu = action->menu();
    if (!menu) {
        action->trigger();
        Q_EMIT messageReady({
            {QStringLiteral("event"), QStringLiteral("menu-open-failed")},
            {QStringLiteral("protocol"), 1},
        });
        return;
    }

    if (m_currentMenu == menu && m_currentIndex == index)
        return;

    if (m_currentMenu)
        sendMenuEvent(m_currentMenu, QStringLiteral("closed"));

    m_currentIndex = index;
    m_currentScreen = screenName;
    m_currentMenu = menu;
    m_importer->updateMenu(menu);
    publishOpenState(true);
}

void AppMenuBridge::closeMenu()
{
    if (m_currentIndex >= 0) {
        if (m_currentMenu)
            sendMenuEvent(m_currentMenu, QStringLiteral("closed"));
        m_currentIndex = -1;
        m_currentMenu = nullptr;
        m_currentScreen.clear();
        publishOpenState(false);
    }
}

void AppMenuBridge::prepareAction(int actionId)
{
    if (!m_importer)
        return;

    QAction *action = m_importer->actionForId(actionId);
    if (action && action->menu())
        m_importer->updateMenu(action->menu());
}

void AppMenuBridge::triggerAction(int actionId)
{
    if (!m_importer)
        return;

    QAction *action = m_importer->actionForId(actionId);
    if (action && action->isVisible() && action->isEnabled() && !action->menu())
        action->trigger();
}

void AppMenuBridge::sendMenuEvent(QMenu *menu, const QString &eventName)
{
    if (!menu || m_service.isEmpty() || m_path.isEmpty())
        return;

    const int actionId = menu->menuAction()->property("_dbusmenu_id").toInt();
    QDBusInterface interface(
        m_service,
        m_path,
        QStringLiteral("com.canonical.dbusmenu"),
        QDBusConnection::sessionBus());
    interface.asyncCall(
        QStringLiteral("Event"),
        actionId,
        eventName,
        QVariant::fromValue(QDBusVariant(QString())),
        0u);
}

QJsonArray AppMenuBridge::serializeMenu(const QMenu *menu) const
{
    QJsonArray result;
    if (!menu)
        return result;

    const QList<QAction *> actions = menu->actions();
    for (int index = 0; index < actions.size(); ++index) {
        QJsonObject action = serializeAction(actions.at(index));
        action.insert(QStringLiteral("index"), index);
        result.append(action);
    }
    return result;
}

QJsonObject AppMenuBridge::serializeAction(const QAction *action) const
{
    QString iconSource;
    const QString iconName = action->property("_dbusmenu_icon_name").toString();
    if (iconName.isEmpty() && !action->icon().isNull()) {
        QByteArray iconData;
        QBuffer buffer(&iconData);
        if (buffer.open(QIODevice::WriteOnly)
            && action->icon().pixmap(16, 16).save(&buffer, "PNG")) {
            iconSource = QStringLiteral("data:image/png;base64,")
                + QString::fromLatin1(iconData.toBase64());
        }
    }

    return {
        {QStringLiteral("actionId"), action->property("_dbusmenu_id").toInt()},
        {QStringLiteral("text"), displayText(action->text())},
        {QStringLiteral("mnemonicText"), action->text()},
        {QStringLiteral("enabled"), action->isEnabled()},
        {QStringLiteral("visible"), action->isVisible()},
        {QStringLiteral("separator"), action->isSeparator()},
        {QStringLiteral("checkable"), action->isCheckable()},
        {QStringLiteral("checked"), action->isChecked()},
        {QStringLiteral("radio"), action->actionGroup() && action->actionGroup()->isExclusive()},
        {QStringLiteral("hasMenu"), action->menu() != nullptr},
        {QStringLiteral("children"), serializeMenu(action->menu())},
        {QStringLiteral("iconName"), iconName},
        {QStringLiteral("iconSource"), iconSource},
        {QStringLiteral("shortcut"), action->shortcut().toString(QKeySequence::NativeText)},
    };
}

QAction *AppMenuBridge::actionAt(int index) const
{
    if (!m_rootMenu || index < 0 || index >= m_rootMenu->actions().size())
        return nullptr;
    return m_rootMenu->actions().at(index);
}

QString AppMenuBridge::displayText(const QString &text) const
{
    QString result;
    result.reserve(text.size());
    for (qsizetype index = 0; index < text.size(); ++index) {
        if (text.at(index) != u'&') {
            result.append(text.at(index));
        } else if (index + 1 < text.size() && text.at(index + 1) == u'&') {
            result.append(u'&');
            ++index;
        }
    }
    return result;
}
