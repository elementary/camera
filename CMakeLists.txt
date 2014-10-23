# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)
project (snap-photobooth)
enable_testing ()
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share/snap-photobooth")
set (PKGDATADIR "${DATADIR}/snap-photobooth")
set (GETTEXT_PACKAGE "snap-photobooth")
set (RELEASE_NAME "The elementary Text Editor.")
set (VERSION "0.1")
set (VERSION_INFO "Release")
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
ensure_vala_version ("0.20" MINIMUM)
include (ValaPrecompile)

add_definitions(-DVALA_VERSION="${VALA_SHORTVER}")
add_definitions(-w) # Disable gcc warnings

# Dependencies
find_package (PkgConfig)
set (SNAP_DEPS gee-0.8 gobject-2.0 glib-2.0 gio-2.0 gtk+-3.0>=3.10 gdk-x11-3.0 granite gstreamer-1.0 gstreamer-video-1.0 x11 gudev-1.0 unity zeitgeist-2.0)
pkg_check_modules (DEPS REQUIRED ${SNAP_DEPS})

set(NORMAL_CFLAGS ${DEPS_CFLAGS})
set(NORMAL_LINK_DIRS ${DEPS_LIBRARY_DIRS})
set(NORMAL_LIBRARIES ${DEPS_LIBRARIES})

add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

# Subdirectories
add_subdirectory (src)
add_subdirectory (schemas)
add_subdirectory (po)

# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/snap-photobooth.desktop DESTINATION share/applications)
