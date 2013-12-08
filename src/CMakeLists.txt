vala_precompile(VALA_C
    Resources.vala
    Snap.vala
    SnapWindow.vala
    ######
    #Dialogs/Preferences.vala
    ######
    Services/Settings.vala
    ######
    Widgets/Camera.vala
    ######
    config.vala
PACKAGES
    ${SNAP_DEPS}
    posix
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --thread
)

add_executable (snap-photobooth ${VALA_C})

install (TARGETS snap-photobooth RUNTIME DESTINATION bin)
