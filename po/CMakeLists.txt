include(Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/org.pantheon.snap.desktop.in
        ${CMAKE_BINARY_DIR}/data/org.pantheon.snap-original.desktop.in
    APPDATA_FILES
        ../data/org.pantheon.snap.appdata.xml.in
)
