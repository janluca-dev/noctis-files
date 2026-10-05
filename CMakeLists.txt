# ============================================================================
#  Noctis Files — eigenständiger Dateimanager auf der Designsprache Noctis.
# ============================================================================
cmake_minimum_required(VERSION 3.21)
project(noctis-files VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Network)

# Wo die Teile nach dem Einbau liegen. Der Wirt sucht dort zuerst neben sich
# (../lib, ../share), dann am festen Ort — so läuft er auch aus /usr/local.
set(NF_LIBDIR  "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/noctis-files")
set(NF_DATADIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_DATADIR}/noctis-files")

option(NF_DEV_SOURCE_FALLBACK "Beim Entwickeln Rückgrat und Schrift aus dem Quellbaum nehmen" OFF)

qt_add_executable(noctis-files
    src/main.cpp
    src/host.cpp        src/host.h
    src/process.cpp     src/process.h
    src/fileview.cpp    src/fileview.h
)

target_compile_definitions(noctis-files PRIVATE
    NOCTIS_FILES_VERSION="${PROJECT_VERSION}"
    NOCTIS_FILES_LIBDIR="${NF_LIBDIR}"
    NOCTIS_FILES_DATADIR="${NF_DATADIR}"
)
if(NF_DEV_SOURCE_FALLBACK)
    target_compile_definitions(noctis-files PRIVATE NOCTIS_FILES_SRCDIR="${CMAKE_CURRENT_SOURCE_DIR}")
endif()

# Die Oberfläche wird ins Programm eingebacken: ein Paket, das seine QML-Dateien
# irgendwo auf der Platte sucht, findet sie irgendwann nicht mehr.
file(GLOB NF_QML RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS
     qml/*.qml qml/qmldir qml/noctis/*.qml qml/filesapp/*.qml qml/filesapp/*.js qml/filesapp/*.svg)
qt_add_resources(noctis-files "ui" PREFIX "/" FILES ${NF_QML})

target_link_libraries(noctis-files PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network)

install(TARGETS noctis-files RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(PROGRAMS backend/fm_ctl.py backend/portal.py DESTINATION ${NF_LIBDIR})
install(FILES data/fonts/Outfit.ttf DESTINATION ${NF_DATADIR}/fonts)
install(FILES data/noctis-files.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES data/icons/noctis-files.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

# Dateidialog des Systems (XDG-Portal). Eingebaut heißt nicht eingeschaltet:
# welcher Dienst die Dateiauswahl übernimmt, entscheidet portals.conf.
configure_file(data/portal/noctis-files-portal.service.in noctis-files-portal.service @ONLY)
configure_file(data/portal/org.freedesktop.impl.portal.desktop.noctis.service.in
               org.freedesktop.impl.portal.desktop.noctis.service @ONLY)
install(FILES data/portal/noctis.portal DESTINATION ${CMAKE_INSTALL_DATADIR}/xdg-desktop-portal/portals)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/org.freedesktop.impl.portal.desktop.noctis.service
        DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/services)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/noctis-files-portal.service
        DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/systemd/user)
