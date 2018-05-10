project('finalterm', ['c', 'vala'], version: '0.1')

gnome = import('gnome')
i18n = import('i18n')

# Add our custom VAPI dir
add_project_arguments(
  ['--vapidir', join_paths(meson.source_root(), 'vapi')],
  language: 'vala'
)

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

prefix = get_option('prefix')
datadir = join_paths(prefix, get_option('datadir'))
mandir = join_paths(prefix, get_option('mandir'))
pkgdatadir = join_paths(datadir, meson.project_name())
locale_dir = join_paths(prefix, get_option('localedir'))
po_dir = join_paths(meson.source_root(), 'po')

# Dependencies
gtk = dependency('gtk+-3.0', version: '>= 3.22.0')
gee = dependency('gee-0.8')
keybinder = dependency('keybinder-3.0')
json = dependency('json-glib-1.0')
posix = valac.find_library('posix')
linux = valac.find_library('linux')
libutil = cc.find_library('util')
libm = cc.find_library('m')

libnotify_enabled = get_option('libnotify')
libnotify = dependency('libnotify', required: libnotify_enabled)

libunity_enabled = get_option('libunity')
libunity = dependency('libunity', required: libunity_enabled)

# Configuration
conf = configuration_data()
conf.set_quoted('PKGDATADIR', pkgdatadir)
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALE_DIR', locale_dir)
conf.set_quoted('VERSION', meson.project_version())
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

# Post-install scripts
meson.add_install_script('meson_post_install.py')

# Subfolders
subdir('data')
subdir('po')
subdir('src')
