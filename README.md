**I am no longer working on Final Term at this time. The port is complete and it is "usable" but full vt102 emulation hasn't been implemented.**

# The Rewrite

The original Final Term depended on Clutter and Mx which are no longer viable. This forks main focus was to port Final Term to GTK+ 3.0 giving it a large performance boost. This porting is fully complete. Some aditinal vt102 emulation has been implemented but there is still a long way to go.

# About Final Term

Final Term is a new breed of terminal emulator.

It goes beyond mere emulation and understands what is happening inside the shell it is hosting. This allows it to offer features no other terminal can, including:

* Semantic text menus
* Smart command completion
* GUI terminal controls


# Installation

Final Term is written in [Vala](https://live.gnome.org/Vala) and built on top of [GTK+ 3](http://www.gtk.org). It requires the development files for the following software packages:

* [Gee](https://live.gnome.org/Libgee)
* [GTK+ 3](http://www.gtk.org)
* [keybinder-3.0](https://github.com/engla/keybinder/tree/keybinder-3.0)
* [libnotify](https://developer.gnome.org/libnotify/) _Optional_, for desktop notifications support
* [libunity](https://launchpad.net/libunity) _Optional_, for Unity launcher integration (progress bars)

Additionally, it requires [gettext](https://www.gnu.org/software/gettext/) for localization string extraction.

To install the dependencies on ubuntu run the following commands:

```
# Build tools
sudo apt-get install gettext meson ninja valac

# Required
sudo apt-get install libgtk-3-dev libkeybinder-3.0-dev libgee-0.8-dev libjson-glib-dev

#Optional
sudo apt-get install libunity-dev libnotify-dev
```

To install Final Term, execute these shell commands:

```sh
git clone https://github.com/RedHatter/finalterm-reborn.git
cd finalterm-reborn/
meson build
ninja -C build
ninja -C build install
```

If you want to install to a custom directory your `XDG_DATA_DIRS` environment variable has to point to the prefix with the file `glib-2.0/schemas/gschemas.compiled` in it.

# Acknowledgments

Final Term owes much of its existence to the awesomeness of [Vala](https://live.gnome.org/Vala) and [its documentation](http://valadoc.org), [Clutter](http://blogs.gnome.org/clutter/) and [Mx](https://github.com/clutter-project/mx), as well as to those projects authors' generous decision to release their amazing work as open source software.

Much of the knowledge about terminal emulation required to build Final Term was gained from [the xterm specification](http://invisible-island.net/xterm/ctlseqs/ctlseqs.html) and the [VT100 User Guide](http://vt100.net/docs/vt100-ug/contents.html), as well as from the study of existing terminal emulators such as [st](http://st.suckless.org) and [Terminator](http://software.jessies.org/terminator/).

Final Term's color schemes are generated using the wonderful [Base16 Builder](https://github.com/chriskempson/base16-builder) by Chris Kempson.

Final Term's application icon is a modified version of the terminal icon from the [Faenza icon theme](http://tiheum.deviantart.com/art/Faenza-Icons-173323228) by Matthieu James.

# License
Copyright © 2013–2014 Philipp Emanuel Weidmann (pew@worldwidemann.com)  
Copyright © 2015-2016 RedHatter (timothy@idioticdev.com)

Final Term is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Final Term is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Final Term.  If not, see <http://www.gnu.org/licenses/>.
