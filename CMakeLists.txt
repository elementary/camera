# Project name
project (pantheon-camera)

# CMake version
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

# Project configuration
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share/pantheon-camera")
set (PKGDATADIR "${DATADIR}/pantheon-camera")
set (GETTEXT_PACKAGE "pantheon-camera")
set (RELEASE_NAME "The elementary Camera Viewer.")
set (VERSION "0.3.0.1")
set (VERSION_INFO "Release")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Add 'make dist' command for creating release tarball
set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

set (APP_NAME "Camera")

# CPack
include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

# CTest
include (CTest)
if (BUILD_TESTING)
    add_test (NAME validate-desktop-file COMMAND desktop-file-validate ${CMAKE_BINARY_DIR}/data/org.pantheon.camera.desktop)
    add_test (NAME validate-appdata COMMAND appstreamcli validate ${CMAKE_BINARY_DIR}/data/org.pantheon.camera.appdata.xml)
endif ()

# Some configuration
configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)

# Some definitions
add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

# Vala
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.20" MINIMUM)
include (ValaPrecompile)
add_definitions (-DVALA_VERSION="${VALA_SHORTVER}")

# Disable gcc warnings
add_definitions (-w)

# Dependencies
find_package (PkgConfig)
set (SNAP_DEPS gio-2.0 gee-0.8 gtk+-3.0 granite clutter-gst-3.0 clutter-gtk-1.0)
pkg_check_modules (DEPS REQUIRED ${SNAP_DEPS})

# Linking paramaters
set (NORMAL_CFLAGS ${DEPS_CFLAGS})
set (NORMAL_LINK_DIRS ${DEPS_LIBRARY_DIRS})
set (NORMAL_LIBRARIES ${DEPS_LIBRARIES})

# Linking
add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

# Subdirectories
add_subdirectory (src)
add_subdirectory (schemas)
add_subdirectory (data)
add_subdirectory (po)
