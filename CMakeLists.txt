# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
project (snap)
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/snap")
set (GETTEXT_PACKAGE "snap")
set (RELEASE_NAME ".")
set (VERSION "0.1")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "-ggdb")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
# Configure file  

configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions(-DGNOME_DESKTOP_USE_UNSTABLE_API)
# snap

set (SNAP_DEPS "gee-1.0;gobject-2.0;glib-2.0;gio-2.0;gtk+-3.0;granite;clutter-1.0;clutter-gtk-1.0;gstreamer-0.10;gstreamer-interfaces-0.10;gdk-x11-3.0;gdk-3.0;x11")
find_package (PkgConfig)
pkg_check_modules (GLIB REQUIRED "glib-2.0 >= 2.26.0")
pkg_check_modules (GOBJECT REQUIRED "gobject-2.0 >= 2.26.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.26.0")
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.2")
pkg_check_modules (GNOMEDESKTOP REQUIRED "gnome-desktop-3.0 >= 3.0")
pkg_check_modules (CHEESE REQUIRED "cheese")
pkg_check_modules (CHEESEGTK REQUIRED "cheese-gtk")
pkg_check_modules (CLUTTERGTK REQUIRED "clutter-gtk-1.0")
pkg_check_modules (LIBGRANITE REQUIRED "granite")
pkg_check_modules (LIBSQLHEAVY REQUIRED "gstreamer-0.10 >= 0.10")
pkg_check_modules (LIBSQLHEAVY REQUIRED "gstreamer-interfaces-0.10 >= 0.10")
pkg_check_modules (LIBSQLHEAVY REQUIRED "gdk-x11-3.0 >= 3.0")
pkg_check_modules (DEPS REQUIRED ${SNAP_DEPS} gthread-2.0)
add_definitions (${DEPS_CFLAGS} ${GNOMEDESKTOP_CFLAGS} ${CLUTTERGTK_CFLAGS} ${CHEESE_CFLAGS} ${CHEESEGTK_CFLAGS} ${LIBSOURCE_CFLAGS} ${GCONF_CFLAGS})
link_libraries (${DEPS_LIBRARIES} ${GNOMEDESKTOP_LIBRARIES} ${CLUTTERGTK_LIBRARIES} ${CHEESE_LIBRARIES} ${CHEESEGTK_LIBRARIES} ${LIBSOURCE_LIBRARIES} ${GCONF_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS} ${GNOMEDESKTOP_LIBRARY_DIRS} ${CLUTTERGTK_LIBRARY_DIRS} ${CHEESE_LIBRARY_DIRS} ${CHEESEGTK_LIBRARY_DIRS} ${LIBSOURCE_LIBRARY_DIRS} ${GCONF_LIBRARY_DIRS})
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.16.0" MINIMUM)
include (ValaPrecompile)
vala_precompile(VALA_C
    src/Resources.vala
    src/SnapWindow.vala
    src/Snap.vala
    src/SnapPipelines.vala
    src/Recorder.vala
    src/EffectsManager.vala
    src/shotwell-video-thumbnailer.vala
    src/config.vala
    src/Widgets/EffectPopOver.vala
    src/Widgets/Countdown.vala
    src/Widgets/MediaBin.vala
    src/Widgets/MediaViewer.vala
    src/Widgets/EffectsPopOver.vala
    src/Dialogs/Preferences.vala
    src/Services/Settings.vala
PACKAGES
   	${SNAP_DEPS}
OPTIONS
    --thread
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi/
CUSTOM_VAPIS
    vapi/gnome-desktop-3.0.vapi
    vapi/cheese-common.vapi
    vapi/cheese-thumbview.vapi
)
# tranlation stuff

add_subdirectory(po)
# add_definitions (${CFLAGS} -Wall -Winit-self -Wwrite-strings -Wunreachable-code -Wstrict-prototypes )

add_executable (snap-photobooth ${VALA_C})
target_link_libraries (snap-photobooth)
#TODO: Installation

install (TARGETS snap-photobooth RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/snap-photobooth.svg DESTINATION share/icons/hicolor/scalable/apps)
install (DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/ DESTINATION share/icons/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/snap-photobooth.desktop DESTINATION share/applications)
include(GSettings)
add_schema("org.pantheon.snap.gschema.xml")
