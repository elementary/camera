include(Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/com.github.elementary.camera.desktop.in
    APPDATA_FILES
        ../data/com.github.elementary.camera.appdata.xml.in
)
