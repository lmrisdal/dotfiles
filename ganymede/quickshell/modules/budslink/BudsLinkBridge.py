#!/usr/bin/env python3
"""Expose BudsLink's custom D-Bus API as JSON lines for Quickshell.

This stays deliberately small: BudsLink remains the device backend and the
bridge only forwards its event-driven device and property updates. It never
uses BlueZ or polls for device state.
"""

import json
import signal
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


BUS_NAME = "io.github.maniacx.BudsLink"
ROOT_PATH = "/io/github/maniacx/BudsLink"
MANAGER_IFACE = "io.github.maniacx.BudsLink.DeviceManager"
DEVICE_IFACE = "io.github.maniacx.BudsLink.Device"
PROPERTIES_IFACE = "org.freedesktop.DBus.Properties"
CLIENT_ID = "quickshell-budslink"
SERVICE_VERSION = "0.0.1"
HEARTBEAT_SECONDS = 110


class BudsLinkBridge:
    def __init__(self):
        self.connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.manager = None
        self.devices = set()
        self.signal_ids = []
        self.heartbeat_id = 0
        self.name_watch = Gio.bus_watch_name(
            Gio.BusType.SESSION,
            BUS_NAME,
            Gio.BusNameWatcherFlags.AUTO_START,
            self.on_name_appeared,
            self.on_name_vanished,
        )

    def emit(self, event, **payload):
        print(json.dumps({"event": event, **payload}), flush=True)

    def on_name_appeared(self, _connection, _name, _owner):
        self.reset()
        try:
            self.manager = Gio.DBusProxy.new_sync(
                self.connection,
                Gio.DBusProxyFlags.NONE,
                None,
                BUS_NAME,
                ROOT_PATH,
                MANAGER_IFACE,
                None,
            )
            version = self.manager.call_sync(
                "ServiceVersion", None, Gio.DBusCallFlags.NONE, -1, None
            ).unpack()[0]
            if version != SERVICE_VERSION:
                self.emit(
                    "incompatible-version",
                    expected=SERVICE_VERSION,
                    actual=version,
                )
                self.manager = None
                return

            self.hold_service()
            self.heartbeat_id = GLib.timeout_add_seconds(
                HEARTBEAT_SECONDS, self.renew_hold
            )
            self.signal_ids = [
                self.connection.signal_subscribe(
                    BUS_NAME,
                    MANAGER_IFACE,
                    None,
                    ROOT_PATH,
                    None,
                    Gio.DBusSignalFlags.NONE,
                    self.on_manager_signal,
                ),
                self.connection.signal_subscribe(
                    BUS_NAME,
                    PROPERTIES_IFACE,
                    "PropertiesChanged",
                    None,
                    None,
                    Gio.DBusSignalFlags.NONE,
                    self.on_properties_changed,
                ),
            ]
            paths = self.manager.call_sync(
                "ListDevices", None, Gio.DBusCallFlags.NONE, -1, None
            ).unpack()[0]
            for path in paths:
                self.add_device(path)
        except GLib.Error as error:
            self.emit("error", message=error.message)

    def hold_service(self):
        if not self.manager:
            return
        self.manager.call_sync(
            "HoldService",
            GLib.Variant("(s)", (CLIENT_ID,)),
            Gio.DBusCallFlags.NONE,
            -1,
            None,
        )

    def renew_hold(self):
        try:
            self.hold_service()
        except GLib.Error as error:
            self.emit("error", message=error.message)
        return GLib.SOURCE_CONTINUE

    def on_name_vanished(self, _connection, _name):
        self.reset()
        self.emit("unavailable")

    def on_manager_signal(self, _connection, _sender, _path, _iface, signal_name, parameters):
        device_path = parameters.unpack()[0]
        if signal_name == "DeviceAdded":
            self.add_device(device_path)
        elif signal_name == "DeviceRemoved":
            self.remove_device(device_path)

    def on_properties_changed(self, _connection, _sender, object_path, _iface, _signal, parameters):
        interface_name, changed, _invalidated = parameters.unpack()
        if interface_name != DEVICE_IFACE or object_path not in self.devices:
            return

        alias = changed.get("Alias")
        config = changed.get("Config")
        state = changed.get("State")
        self.emit(
            "device-updated",
            path=object_path,
            alias=alias if alias else None,
            config=json.loads(config) if config else None,
            state=json.loads(state) if state else None,
        )

    def add_device(self, path):
        if path in self.devices:
            return

        try:
            result = self.connection.call_sync(
                BUS_NAME,
                path,
                PROPERTIES_IFACE,
                "GetAll",
                GLib.Variant("(s)", (DEVICE_IFACE,)),
                GLib.VariantType("(a{sv})"),
                Gio.DBusCallFlags.NONE,
                -1,
                None,
            )
            properties = result.unpack()[0]
            self.devices.add(path)
            self.emit(
                "device-added",
                path=path,
                alias=properties["Alias"],
                config=json.loads(properties["Config"]),
                state=json.loads(properties["State"]),
            )
        except (GLib.Error, KeyError, json.JSONDecodeError) as error:
            self.emit("error", message=str(error))

    def remove_device(self, path):
        if path not in self.devices:
            return
        self.devices.remove(path)
        self.emit("device-removed", path=path)

    def reset(self):
        if self.heartbeat_id:
            GLib.source_remove(self.heartbeat_id)
            self.heartbeat_id = 0
        for signal_id in self.signal_ids:
            self.connection.signal_unsubscribe(signal_id)
        self.signal_ids = []
        for path in list(self.devices):
            self.remove_device(path)
        self.manager = None

    def close(self):
        if self.manager:
            try:
                self.manager.call_sync(
                    "ReleaseService",
                    GLib.Variant("(s)", (CLIENT_ID,)),
                    Gio.DBusCallFlags.NONE,
                    1000,
                    None,
                )
            except GLib.Error:
                pass
        self.reset()
        Gio.bus_unwatch_name(self.name_watch)


def main():
    bridge = BudsLinkBridge()
    loop = GLib.MainLoop()

    def stop(*_args):
        bridge.close()
        loop.quit()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    loop.run()


if __name__ == "__main__":
    main()
