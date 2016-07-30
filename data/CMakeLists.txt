include (Translations)

# We need to create two temporary desktop files in order to have all translations available.
set (APP_NAME "Camera")
configure_file(snap-photobooth.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth.desktop.in)
set (APP_NAME "Snap")
configure_file(snap-photobooth.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth-original.desktop.in)
if (BUILD_FOR_ELEMENTARY)
    configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth.desktop ${CMAKE_SOURCE_DIR}/po/)
else ()
    configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth-original.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth.desktop ${CMAKE_SOURCE_DIR}/po/)
endif ()

configure_file_translation(${CMAKE_CURRENT_SOURCE_DIR}/snap-photobooth.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth.appdata.xml DESTINATION share/appdata)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/snap-photobooth.desktop DESTINATION share/applications)
