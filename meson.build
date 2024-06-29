project(
    'io.elementary.camera', 'vala', 'c',
    meson_version : '>= 0.57',
    version: '6.2.2'
)

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

asresources = gnome.compile_resources(
    'as-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

executable(
    meson.project_name(),
    asresources,
    'src/Application.vala',
    'src/MainWindow.vala',
    'src/Utils.vala',
    'src/Widgets/CameraView.vala',
    'src/Widgets/TimerButton.vala',
    config_file,
    dependencies : [
        dependency('gstreamer-1.0'),
        dependency('gstreamer-pbutils-1.0'),
        dependency('gee-0.8'),
        dependency('gio-2.0'),
        dependency('glib-2.0'),
        dependency('granite-7', version: '>=7.0.0'),
        dependency('gtk4'),
        dependency('libcanberra'),
        meson.get_compiler('vala').find_library('posix')
    ],
    install : true
)

gnome.post_install(glib_compile_schemas: true)

subdir('data')
subdir('po')
