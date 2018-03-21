# Pantheon Camera
[![Translation status](https://l10n.elementary.io/widgets/camera/-/svg-badge.svg)](https://l10n.elementary.io/projects/camera/?utm_source=widget)
[![Bountysource](https://www.bountysource.com/badge/tracker?tracker_id=45629460)](https://www.bountysource.com/trackers/45629460-elementary-camera)

The camera app designed for elementary OS

## Building, Testing, and Installation

You'll need the following dependencies:

 - meson >= 0.43
 - valac-0.30
 - libgtk-3.0-dev
 - libgranite-dev
 - libclutter-gst-3.0-dev
 - libclutter-gtk-1.0-dev
 - libcanberra-dev

Run `meson build` to configure the build environment. Change to the build directory and run `ninja test` to build and run automated tests

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `io.elementary.camera`

    sudo ninja install
    io.elementary.camera
