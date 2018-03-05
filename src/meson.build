# The finalterm binary
finalterm_sources = [
  'Autocompletion.vala',
  'CharacterAttributes.vala',
  'ColorScheme.vala',
  'Command.vala',
  'Encoder.vala',
  'FinalTerm.vala',
  'KeyBindings.vala',
  'Metrics.vala',
  'NestingContainer.vala',
  'NotifyingList.vala',
  'ScrollableTreeView.vala',
  'Settings.vala',
  'SettingsWindow.vala',
  'StatusBar.vala',
  'TerminalOutput.vala',
  'TerminalStream.vala',
  'Terminal.vala',
  'TerminalView.vala',
  'TerminalWidget.vala',
  'TextMenu.vala',
  'TextView.vala',
  'Theme.vala',
  'Utilities.vala',
]

finalterm_vala_args = [
  '--pkg', 'Config',
]

finalterm_c_args = [
  '-include', 'config.h',
]

finalterm_deps = [
  gtk,
  gee,
  keybinder,
  json,
  posix,
  linux,
  libutil,
]

if libnotify_enabled
  finalterm_deps += [ libnotify ]
  finalterm_vala_args += [ '-D', 'HAS_NOTIFY' ]
endif

if libunity_enabled
  finalterm_deps += [ libunity ]
  finalterm_vala_args += [ '-D', 'HAS_UNITY' ]
endif

executable('finalterm', finalterm_sources,
  include_directories: [ config_h_dir ],
  c_args: finalterm_c_args,
  vala_args: finalterm_vala_args,
  dependencies: finalterm_deps,
  install: true,
)
