# Pantheon Camera
<a href="https://i18n.elementary.io/projects/desktop/camera/" target="_blank">
<img src="http://i18n.elementary.io/widgets/desktop/camera/svg-badge.svg" alt="Translation status" />
</a>
[![Bountysource](https://www.bountysource.com/badge/tracker?tracker_id=45629460)](https://www.bountysource.com/trackers/45629460-elementary-camera)

The camera app designed for elementary OS

## Building, Testing, and Installation

You'll need the following dependencies:

 - valac-0.30
 - libgtk-3.0-dev
 - libgranite-dev
 - libclutter-gst-3.0-dev
 - libclutter-gtk-1.0-dev

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make all test` to build and run automated tests

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make all test
    
To install, use `make install`, then execute with `pantheon-camera`

    sudo make install
    pantheon-camera
