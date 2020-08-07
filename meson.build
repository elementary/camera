project(
    'io.elementary.camera', 'vala', 'c',
    meson_version : '>= 0.43',
    version: '1.0.6'
)

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

asresources = gnome.compile_resources(
    'as-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

executable(
    meson.project_name(),
    asresources,
    'src/Application.vala',
    'src/MainWindow.vala',
    'src/Utils.vala',
    'src/Widgets/CameraView.vala',
    'src/Widgets/HeaderBar.vala',
    'src/Widgets/TimerButton.vala',
    dependencies : [
        dependency('gee-0.8'),
        dependency('gio-2.0'),
        dependency('glib-2.0'),
        dependency('granite', version: '>=5.1.0'),
        dependency('gtk+-3.0'),
        dependency('libcanberra'),
        dependency('cheese'),
        dependency('clutter-gtk-1.0'),
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

subdir('data')
subdir('po')
