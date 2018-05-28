project(
    'pantheon-camera', 'vala', 'c',
    meson_version : '>= 0.43'
)

app_name = 'org.pantheon.camera'

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

executable(
    meson.project_name(),
    'src/Application.vala',
    'src/MainWindow.vala',
    'src/Utils.vala',
    'src/Backend/Settings.vala',
    'src/Widgets/CameraView.vala',
    'src/Widgets/HeaderBar.vala',
    'src/Widgets/LoadingView.vala',
    'src/Widgets/TakeButton.vala',
    'src/Widgets/TimerButton.vala',
    dependencies : [
        dependency('clutter-gst-3.0'),
        dependency('clutter-gtk-1.0'),
        dependency('gee-0.8'),
        dependency('gio-2.0'),
        dependency('glib-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        dependency('libcanberra'),
        meson.get_compiler('vala').find_library('posix')
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

subdir('data')
subdir('po')
