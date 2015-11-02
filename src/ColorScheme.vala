/*
 * Copyright © 2013–2014 Philipp Emanuel Weidmann <pew@worldwidemann.com>
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

public class ColorScheme : Object {

	public string name { get; set; }
	public string author { get; set; }

	private Gdk.RGBA dark_cursor_color = Gdk.RGBA();
	private Gdk.RGBA light_cursor_color = Gdk.RGBA();
	private Gdk.RGBA dark_foreground_color = Gdk.RGBA();
	private Gdk.RGBA light_foreground_color = Gdk.RGBA();
	private Gdk.RGBA dark_background_color = Gdk.RGBA();
	private Gdk.RGBA light_background_color = Gdk.RGBA();
	private Gee.Map<int, Gdk.RGBA?> dark_indexed_colors = new Gee.HashMap<int, Gdk.RGBA?> ();
	private Gee.Map<int, Gdk.RGBA?> light_indexed_colors = new Gee.HashMap<int, Gdk.RGBA?> ();

	public ColorScheme.load_from_file(string filename) {
		// Set default color values
		dark_cursor_color.parse("#ffffff");
		light_cursor_color.parse("#000000");
		dark_foreground_color.parse("#ffffff");
		light_foreground_color.parse("#000000");
		dark_background_color.parse("#000000");
		light_background_color.parse("#ffffff");

		dark_indexed_colors  = new Gee.HashMap<int, Gdk.RGBA?>();
		light_indexed_colors = new Gee.HashMap<int, Gdk.RGBA?>();

		// Logic taken from https://github.com/trapd00r/Convert-Color-XTerm

		// Color cube
		for (int red = 0; red < 6; red++) {
			for (int green = 0; green < 6; green++) {
				for (int blue = 0; blue < 6; blue++) {
					int index = 16 + (red * 36) + (green * 6) + blue;
					var color = Utilities.get_rgb_color(red * 51, green * 51, blue * 51);
					dark_indexed_colors.set(index, color);
					light_indexed_colors.set(index, color);
				}
			}
		}

		// Grayscale ramp
		for (int gray = 0; gray < 24; gray++) {
			int index = 232 + gray;
			var color = Utilities.get_rgb_color(8 + (gray * 10), 8 + (gray * 10), 8 + (gray * 10));
			dark_indexed_colors.set(index, color);
			light_indexed_colors.set(index, color);
		}

		// Load color values from file, overriding default colors if necessary
		var colors_file = new KeyFile();
		try {
			colors_file.load_from_file(filename, KeyFileFlags.NONE);
		} catch (Error e) { error(_("Failed to load color scheme %s: %s"), filename, e.message); }

		try {
			name   = colors_file.get_string("About", "name");
			author = colors_file.get_string("About", "author");

			foreach (var key in colors_file.get_keys("Dark")) {
				var color = Gdk.RGBA ();
				color.parse(colors_file.get_string("Dark", key));
				switch (key) {
				case "cursor":
					dark_cursor_color = color;
					break;
				case "foreground":
					dark_foreground_color = color;
					break;
				case "background":
					dark_background_color = color;
					break;
				default:
					dark_indexed_colors.set(int.parse(key), color);
					break;
				}
			}

			foreach (var key in colors_file.get_keys("Light")) {
				var color = Gdk.RGBA ();
				color.parse(colors_file.get_string("Dark", key));
				switch (key) {
				case "cursor":
					light_cursor_color = color;
					break;
				case "foreground":
					light_foreground_color = color;
					break;
				case "background":
					light_background_color = color;
					break;
				default:
					light_indexed_colors.set(int.parse(key), color);
					break;
				}
			}
		} catch (Error e) { warning(_("Error in color scheme %s: %s"), filename, e.message); }
	}

	public Gdk.RGBA get_cursor_color(bool dark) {
		return (dark ? dark_cursor_color : light_cursor_color);
	}

	public Gdk.RGBA get_foreground_color(bool dark) {
		return (dark ? dark_foreground_color : light_foreground_color);
	}

	public Gdk.RGBA get_background_color(bool dark) {
		return (dark ? dark_background_color : light_background_color);
	}

	public Gdk.RGBA get_indexed_color(int index, bool dark) {
		if (dark ? dark_indexed_colors.has_key(index) : light_indexed_colors.has_key(index)) {
			return (dark ? dark_indexed_colors.get(index) : light_indexed_colors.get(index));
		} else {
			critical(_("Invalid color index: %i"), index);
			var color = Gdk.RGBA ();
			color.parse ("#00000000");
			return color;
		}
	}

}
