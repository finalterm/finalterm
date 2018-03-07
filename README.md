*This fork is a continuation of [RedHatter’s port](https://github.com/RedHatter/finalterm-reborn) to GTK 3. We are focusing on keeping Final Term up to date and getting rid of bugs.*

# About Final Term

Final Term is a new breed of terminal emulator.

It goes beyond mere emulation and understands what is happening inside the shell it is hosting. This allows it to offer features no other terminal can, including:

* Semantic text menus
* Smart command completion
* GUI terminal controls


# Installation

Final Term is written in [Vala](https://wiki.gnome.org/Projects/Vala) and built on top of [GTK+ 3](https://www.gtk.org/). It requires the development files for the following software packages:

* [Gee](https://wiki.gnome.org/Projects/Libgee)
* [GTK+ 3](https://www.gtk.org/)
* [keybinder-3.0](https://github.com/engla/keybinder/tree/keybinder-3.0)
* [libnotify](https://developer.gnome.org/libnotify/) _Optional_, for desktop notifications support
* [libunity](https://launchpad.net/libunity) _Optional_, for Unity launcher integration (progress bars)

Additionally, it requires [gettext](https://www.gnu.org/software/gettext/) for localization string extraction.

To install the dependencies on Ubuntu run the following commands:

```
# Build tools
sudo apt install gettext meson ninja valac

# Required
sudo apt install libgtk-3-dev libkeybinder-3.0-dev libgee-0.8-dev libjson-glib-dev

#Optional
sudo apt install libunity-dev libnotify-dev
```

To install Final Term, execute these shell commands:

```sh
git clone https://github.com/finalterm/finalterm.git
cd finalterm/
meson build
ninja -C build
ninja -C build install
```

If you want to install to a custom directory your `XDG_DATA_DIRS` environment variable has to point to the prefix with the file `glib-2.0/schemas/gschemas.compiled` in it.

# Acknowledgments

Final Term owes much of its existence to the awesomeness of [Vala](https://wiki.gnome.org/Projects/Vala) and [its documentation](https://valadoc.org), [Clutter](https://blogs.gnome.org/clutter/) and [Mx](https://github.com/clutter-project/mx), as well as to those projects authors’ generous decision to release their amazing work as open source software.

Much of the knowledge about terminal emulation required to build Final Term was gained from [the xterm specification](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) and the [VT100 User Guide](https://vt100.net/docs/vt100-ug/contents.html), as well as from the study of existing terminal emulators such as [st](https://st.suckless.org/) and [Terminator](https://code.google.com/archive/p/jessies/wikis/Terminator.wiki).

Final Term’s color schemes are generated using the wonderful [Base16 Builder](https://github.com/chriskempson/base16-builder) by Chris Kempson.

Final Term’s application icon is a modified version of the terminal icon from the [Faenza icon theme](http://tiheum.deviantart.com/art/Faenza-Icons-173323228) by Matthieu James.

# License
Copyright © 2013–2014 Philipp Emanuel Weidmann (pew@worldwidemann.com)  
Copyright © 2015-2016 RedHatter (timothy@idioticdev.com)

Final Term is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Final Term is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Final Term.  If not, see <https://www.gnu.org/licenses/>.
