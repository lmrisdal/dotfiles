// SPDX-License-Identifier: GPL-2.0-or-later

#include "AppMenuBridge.hpp"

#include <QApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusReply>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSocketNotifier>

#include <unistd.h>

namespace {

void sendMessage(const QJsonObject &message)
{
    static QFile output;
    if (!output.isOpen()
        && !output.open(STDOUT_FILENO, QIODevice::WriteOnly, QFileDevice::DontCloseHandle))
        return;

    output.write(QJsonDocument(message).toJson(QJsonDocument::Compact));
    output.write("\n");
    output.flush();
}

void handleMessage(const QByteArray &line, AppMenuBridge &bridge)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(line, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        sendMessage({
            {QStringLiteral("event"), QStringLiteral("error")},
            {QStringLiteral("message"), QStringLiteral("Invalid JSON command")},
        });
        return;
    }

    const QJsonObject command = document.object();
    if (command.value(QStringLiteral("command")) == QStringLiteral("ping")) {
        sendMessage({
            {QStringLiteral("event"), QStringLiteral("pong")},
            {QStringLiteral("protocol"), 1},
        });
    } else
        bridge.handleCommand(command);
}

} // namespace

int main(int argc, char *argv[])
{
    QApplication application(argc, argv);
    application.setQuitOnLastWindowClosed(false);
    AppMenuBridge bridge;
    QObject::connect(&bridge, &AppMenuBridge::messageReady, &application, &sendMessage);
    QByteArray inputBuffer;
    const QString viewService = QStringLiteral("org.kde.kappmenuview");
    const QDBusConnection sessionBus = QDBusConnection::sessionBus();
    QString viewerRegistration = QStringLiteral("failed");

    if (sessionBus.isConnected() && sessionBus.interface()) {
        const QDBusReply<QDBusConnectionInterface::RegisterServiceReply> reply =
            sessionBus.interface()->registerService(
                viewService,
                QDBusConnectionInterface::QueueService,
                QDBusConnectionInterface::DontAllowReplacement);

        if (reply.isValid()) {
            if (reply.value() == QDBusConnectionInterface::ServiceRegistered)
                viewerRegistration = QStringLiteral("owned");
            else if (reply.value() == QDBusConnectionInterface::ServiceQueued)
                viewerRegistration = QStringLiteral("queued");
        }

        QObject::connect(
            sessionBus.interface(),
            &QDBusConnectionInterface::serviceOwnerChanged,
            &application,
            [&](const QString &name, const QString &, const QString &newOwner) {
                if (name != viewService)
                    return;

                const QString newState = newOwner == sessionBus.baseService()
                    ? QStringLiteral("owned")
                    : QStringLiteral("queued");
                if (viewerRegistration == newState)
                    return;

                viewerRegistration = newState;
                sendMessage({
                    {QStringLiteral("event"), QStringLiteral("registration")},
                    {QStringLiteral("protocol"), 1},
                    {QStringLiteral("viewerRegistration"), viewerRegistration},
                });
            });
    }

    QSocketNotifier inputNotifier(STDIN_FILENO, QSocketNotifier::Read);
    QObject::connect(&inputNotifier, &QSocketNotifier::activated, &application, [&]() {
        char chunk[4096];
        const ssize_t bytesRead = read(STDIN_FILENO, chunk, sizeof(chunk));
        if (bytesRead <= 0) {
            application.quit();
            return;
        }

        inputBuffer.append(chunk, bytesRead);
        qsizetype newlineIndex = -1;
        while ((newlineIndex = inputBuffer.indexOf('\n')) >= 0) {
            const QByteArray line = inputBuffer.first(newlineIndex).trimmed();
            inputBuffer.remove(0, newlineIndex + 1);
            if (!line.isEmpty())
                handleMessage(line, bridge);
        }
    });

    sendMessage({
        {QStringLiteral("event"), QStringLiteral("ready")},
        {QStringLiteral("protocol"), 1},
        {QStringLiteral("menuAvailable"), false},
        {QStringLiteral("entries"), QJsonArray()},
        {QStringLiteral("viewerRegistration"), viewerRegistration},
    });

    return application.exec();
}
