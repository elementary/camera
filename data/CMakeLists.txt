include (Translations)

# We need to create two temporary desktop files in order to have all translations available.
set (APP_NAME "Camera")
configure_file(org.pantheon.camera.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera.desktop.in)
set (APP_NAME "Snap")
configure_file(org.pantheon.camera.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera-original.desktop.in)
if (BUILD_FOR_ELEMENTARY)
    configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera.desktop ${CMAKE_SOURCE_DIR}/po/)
else ()
    configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera-original.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera.desktop ${CMAKE_SOURCE_DIR}/po/)
endif ()

configure_file_translation(${CMAKE_CURRENT_SOURCE_DIR}/org.pantheon.camera.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera.appdata.xml DESTINATION share/appdata)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.camera.desktop DESTINATION share/applications)
