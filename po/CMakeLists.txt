include(Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/snap-photobooth.desktop.in
        ${CMAKE_BINARY_DIR}/data/snap-photobooth-original.desktop.in
    APPDATA_FILES
        ../data/snap-photobooth.appdata.xml.in
)
