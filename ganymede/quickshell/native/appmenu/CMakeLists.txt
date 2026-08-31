cmake_minimum_required(VERSION 3.21)

project(QuickshellAppMenuHelper VERSION 0.1.0 LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Widgets)

qt_standard_project_setup(REQUIRES 6.8)

set_source_files_properties(dbusmenuqt/com.canonical.dbusmenu.xml PROPERTIES
    NO_NAMESPACE true
    INCLUDE "dbusmenutypes_p.h"
    CLASSNAME DBusMenuInterface
)

qt_add_dbus_interface(appmenu_helper_sources
    dbusmenuqt/com.canonical.dbusmenu.xml
    dbusmenu_interface
)

qt_add_executable(appmenu-helper
    AppMenuBridge.cpp
    AppMenuBridge.hpp
    main.cpp
    dbusmenuqt/dbusmenuimporter.cpp
    dbusmenuqt/dbusmenuimporter.h
    dbusmenuqt/dbusmenushortcut_p.cpp
    dbusmenuqt/dbusmenushortcut_p.h
    dbusmenuqt/dbusmenutypes_p.cpp
    dbusmenuqt/dbusmenutypes_p.h
    dbusmenuqt/debug.cpp
    dbusmenuqt/debug.h
    dbusmenuqt/utils.cpp
    dbusmenuqt/utils_p.h
    ${appmenu_helper_sources}
)

target_compile_features(appmenu-helper PRIVATE cxx_std_20)

target_include_directories(appmenu-helper PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/dbusmenuqt"
)

target_link_libraries(appmenu-helper
    PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Gui
        Qt6::Widgets
)
