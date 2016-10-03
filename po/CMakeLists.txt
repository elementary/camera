include(Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/org.pantheon.camera.desktop.in
    APPDATA_FILES
        ../data/org.pantheon.camera.appdata.xml.in
)
