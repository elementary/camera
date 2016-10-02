# Pantheon Camera

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
    
Run `cmake` to configure the build environment and then make to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`, then execute with `snap-photobooth`

    sudo make install
    snap-photobooth
