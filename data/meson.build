# Terminal data
foreach item : ['ColorSchemes', 'KeyBindings', 'TerminalCommands', 'Termlets', 'TextMenus', 'Themes']
  install_subdir(item, install_dir: pkgdatadir)
endforeach

# Startup scripts
configure_file(
  input: 'Startup/bash_startup.in',
  output: 'bash_startup',
  configuration: conf,
  install: true,
  install_dir: join_paths(pkgdatadir, 'Startup'),
)
install_data(
  'Startup/preexec.bash',
  install_dir: join_paths(pkgdatadir, 'Startup'),
)

# Icons
iconsdir = join_paths(datadir, 'icons', 'hicolor')
foreach size: ['16x16', '22x22', '24x24', '32x32', '48x48', '64x64', '96x96', 'scalable']
  install_subdir('Icons/hicolor/' + size, install_dir: iconsdir)
endforeach

# Manpage
manconf = configuration_data()
manconf.set_quoted('DATE', run_command('date', ['+%B %Y']).stdout())
manconf.set_quoted('VERSION', meson.project_version())
man = configure_file(
  input: 'finalterm.1.in',
  output: 'finalterm.1',
  configuration: manconf,
)
install_man(man)

# Desktop file
i18n.merge_file(
  input: 'finalterm.desktop.in',
  output: 'finalterm.desktop',
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'applications'),
)

# Resources
resource_data = files(
  'ui/menu.ui',
  'ui/preferences.ui',
)

resources = gnome.compile_resources(
  'resources',
  'finalterm.gresource.xml',
  dependencies: resource_data,
)

# GSettings schemas
compiled = gnome.compile_schemas()
install_data('org.gnome.finalterm.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)
