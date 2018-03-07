/*
 * Copyright © 2013–2014 Tom Beckmann <tomjonabc@gmail.com>
 * Copyright © 2015 RedHatter <timothy@idioticdev.com>
 *
 * Nemo vir est qui mundum non reddat meliorem.
 *
 *
 * This file is part of Final Term.
 *
 * Final Term is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Final Term is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Final Term.  If not, see <http://www.gnu.org/licenses/>.
 */

[GtkTemplate (ui = "/org/gnome/finalterm/ui/preferences.ui")]
public class SettingsWindow : Gtk.Dialog {

	[GtkChild (name = "columns")]
	private Gtk.SpinButton d_columns;

	[GtkChild (name = "rows")]
	private Gtk.SpinButton d_rows;

	[GtkChild (name = "left")]
	private Gtk.Entry d_left;

	[GtkChild (name = "middle" )]
	private Gtk.Entry d_middle;

	[GtkChild (name = "right")]
	private Gtk.Entry d_right;

	[GtkChild (name = "terminal_font" )]
	private Gtk.FontButton d_terminal_font;

	[GtkChild (name = "label_font")]
	private Gtk.FontButton d_label_font;

	[GtkChild (name = "dark_look" )]
	private Gtk.Switch d_dark_look;

	[GtkChild (name = "color_scheme")]
	private Gtk.ComboBoxText d_color_scheme;

	[GtkChild (name = "theme" )]
	private Gtk.ComboBoxText d_theme;

	[GtkChild (name = "opacity")]
	private Gtk.Scale d_opacity;


	construct {
		d_rows.value = Settings.get_default().terminal_lines;
		d_rows.value_changed.connect(() => {
			Settings.get_default().terminal_lines = (int)d_rows.value;
		});

		d_columns.value = Settings.get_default().terminal_columns;
		d_columns.value_changed.connect(() => {
			Settings.get_default().terminal_columns = (int)d_columns.value;
		});

		d_left.text = Settings.get_default().status_bar_left;
		d_left.changed.connect(() => {
			Settings.get_default().status_bar_left = d_left.text;
		});

		d_middle.text = Settings.get_default().status_bar_middle;
		d_middle.changed.connect(() => {
			Settings.get_default().status_bar_middle = d_middle.text;
		});

		d_right.text = Settings.get_default().status_bar_right;
		d_right.changed.connect(() => {
			Settings.get_default().status_bar_right = d_right.text;
		});

		// Restrict selection to monospaced fonts
		d_terminal_font.set_filter_func((family, face) => {
			return family.is_monospace();
		});
		d_terminal_font.font_name = Settings.get_default().terminal_font_name;
		d_terminal_font.font_set.connect(() => {
			Settings.get_default().terminal_font_name = d_terminal_font.font_name;
		});

		d_label_font.font_name = Settings.get_default().label_font_name;
		d_label_font.font_set.connect(() => {
			Settings.get_default().label_font_name = d_label_font.font_name;
		});

		d_dark_look.active = Settings.get_default().dark;
		d_dark_look.notify["active"].connect(() => {
			Settings.get_default().dark = d_dark_look.active;
		});

		foreach (var color_scheme_name in FinalTerm.color_schemes.keys) {
			d_color_scheme.append(color_scheme_name, color_scheme_name);
		}
		d_color_scheme.active_id = Settings.get_default().color_scheme_name;
		d_color_scheme.changed.connect(() => {
			Settings.get_default().color_scheme_name = d_color_scheme.active_id;
		});

		foreach (var theme_name in FinalTerm.themes.keys) {
			d_theme.append(theme_name, theme_name);
		}
		d_theme.active_id = Settings.get_default().theme_name;
		d_theme.changed.connect(() => {
			Settings.get_default().theme_name = d_theme.active_id;
		});

		d_opacity.set_value(Settings.get_default().opacity * 100.0);
		d_opacity.value_changed.connect(() => {
			Settings.get_default().opacity = d_opacity.get_value() / 100.0;
		});
	}
}
