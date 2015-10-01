vala_precompile(VALA_C
    Resources.vala
    Snap.vala
    SnapWindow.vala
    ######
    Services/Settings.vala
    Services/ThumbnailProvider.vala
    ######
    Widgets/Camera.vala
    Widgets/Gallery.vala
    Widgets/NoCamera.vala
    ######
    config.vala
PACKAGES
    ${SNAP_DEPS}
    posix
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --thread
    --enable-experimental
)

add_executable (snap-photobooth ${VALA_C})

install (TARGETS snap-photobooth RUNTIME DESTINATION bin)
