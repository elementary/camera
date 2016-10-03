# Configure precompilation
vala_precompile (VALA_C
    config.vala
    Utils.vala
    Application.vala
    MainWindow.vala
    Widgets/HeaderBar.vala
    Widgets/LoadingView.vala
    Widgets/CameraView.vala
    Backend/Settings.vala
PACKAGES
    ${SNAP_DEPS}
    posix
OPTIONS
    --thread
    --target-glib=2.32
    --enable-experimental
)

# Register new executable
add_executable (pantheon-camera ${VALA_C})

# Installation
install (TARGETS pantheon-camera RUNTIME DESTINATION bin)
