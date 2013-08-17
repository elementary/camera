# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)
project (snap-photobooth)
enable_testing ()
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share/snap-photobooth")
set (SCRIPTDIR "${CMAKE_INSTALL_PREFIX}/share/snap-photobooth/scripts")
set (PKGDATADIR "${DATADIR}/snap-photobooth")
set (GETTEXT_PACKAGE "snap-photobooth")
set (RELEASE_NAME "Photobooth App.")
set (VERSION "0.1")
set (VERSION_INFO "Release")
set (LIBNAME "snapcore")
set (LIBVERSION "0")
set (SOVERSION 0)
set (PLUGINDIR "${CMAKE_INSTALL_PREFIX}/lib/snap-photobooth/plugins/")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Add 'make dist' command for creating release tarball
set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

# Some configuration
configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)

# Some definitions
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

# Vala
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.18" MINIMUM)
include (ValaPrecompile)

add_definitions(-DVALA_VERSION="${VALA_SHORTVER}")
add_definitions(-DGNOME_DESKTOP_USE_UNSTABLE_API)

# Dependencies
set (SNAP_DEPS gee-1.0 gobject-2.0 glib-2.0 gio-2.0 gtk+-3.0 granite clutter-1.0 clutter-gtk-1.0 gstreamer-1.0 gdk-3.0)
find_package (PkgConfig)
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.6")
pkg_check_modules (CHEESE REQUIRED "cheese >= 3.6")
pkg_check_modules (CHEESEGTK REQUIRED "cheese-gtk >= 3.6")
pkg_check_modules (GNOMEDESKTOP REQUIRED "gnome-desktop-3.0 >= 3.0")
pkg_check_modules (DEPS REQUIRED ${SNAP_DEPS})

set(NORMAL_CFLAGS ${DEPS_CFLAGS} ${CHEESE_CFLAGS} ${CHEESEGTK_CFLAGS} ${GNOMEDESKTOP_CFLAGS})
set(NORMAL_LINK_DIRS ${DEPS_LIBRARY_DIRS} ${CHEESE_LIBRARY_DIRS} ${CHEESEGTK_LIBRARY_DIRS} ${GNOMEDESKTOP_LIBRARY_DIRS})
set(NORMAL_LIBRARIES ${DEPS_LIBRARIES} ${CHEESE_LIBRARIES} ${CHEESEGTK_LIBRARIES} ${GNOMEDESKTOP_LIBRARIES})

add_definitions (${DEPS_CFLAGS} ${CHEESE_CFLAGS} ${CHEESEGTK_CFLAGS} ${GNOMEDESKTOP_CFLAGS})
link_libraries (${DEPS_LIBRARIES} ${CHEESE_LIBRARIES} ${CHEESEGTK_LIBRARIES} ${GNOMEDESKTOP_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS} ${CHEESE_LIBRARY_DIRS} ${CHEESEGTK_LIBRARY_DIRS} ${GNOMEDESKTOP_LIBRARY_DIRS})


# Some include paths
include_directories(${CMAKE_BINARY_DIR}/src)

# Subdirectories
add_subdirectory (po)
add_subdirectory (schemas)
add_subdirectory (thumbview)
add_subdirectory (src)

# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/snap-photobooth.desktop DESTINATION share/applications)
