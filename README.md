# Camera
[![Translation status](https://l10n.elementary.io/widgets/camera/-/svg-badge.svg)](https://l10n.elementary.io/projects/camera/?utm_source=widget)

The camera app designed for elementary OS

![Camera Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

Run `flatpak-builder` to configure the build environment, download dependencies, build, and install

```bash
    flatpak-builder build io.elementary.camera.yml --user --install --force-clean --install-deps-from=appcenter
```

Then execute with

```bash
    flatpak run io.elementary.camera
```
