vala_precompile(VALA_C
    Resources.vala
    Snap.vala
    SnapWindow.vala
    ######
    Dialogs/Preferences.vala
    ######
    Services/EffectsManager.vala
    Services/Recorder.vala
    Services/Settings.vala
    ######
    Widgets/Countdown.vala
    Widgets/EffectsPopOver.vala
    Widgets/MediaViewer.vala
    ######
    config.vala
PACKAGES
    ${SNAP_DEPS}
    posix
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --thread
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/vapi/gnome-desktop-3.0.vapi
    ${CMAKE_SOURCE_DIR}/vapi/cheese-common.vapi
    ${CMAKE_SOURCE_DIR}/thumbview/cheese-thumbview.vapi
)

add_executable (snap-photobooth ${VALA_C})
add_dependencies(snap-photobooth libsnap)
include_directories(${CMAKE_SOURCE_DIR}/thumbview)
target_link_libraries (snap-photobooth libsnap)

install (TARGETS snap-photobooth RUNTIME DESTINATION bin)
