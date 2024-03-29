# Camera
[![Translation status](https://l10n.elementary.io/widgets/camera/-/svg-badge.svg)](https://l10n.elementary.io/projects/camera/?utm_source=widget)

The camera app designed for elementary OS

![Camera Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:

 - gstreamer1.0-gtk3
 - libcanberra-dev
 - libclutter-gst-3.0-dev
 - libclutter-gtk-1.0-dev
 - libgranite-dev
 - libgstreamer1.0-dev
 - libgstreamer-plugins-base1.0-dev
 - libgtk-3-dev
 - libhandy-1-dev
 - meson >= 0.46
 - valac

Run `meson build` to configure the build environment. Change to the build directory and run `ninja test` to build and run automated tests

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `io.elementary.camera`

    sudo ninja install
    io.elementary.camera
