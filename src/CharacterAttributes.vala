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

// Parses Character Attributes (SGR) control sequences
public class CharacterAttributes : Object {

	// TODO: Can these be private?
	public int foreground_color { get; set; }
	public int background_color { get; set; }
	public Gdk.RGBA rgb_foreground_color { get; set; }
	public Gdk.RGBA rgb_background_color { get; set; }
	public bool use_rgb_foreground_color { get; set; }
	public bool use_rgb_background_color { get; set; }
	public bool bold { get; set; }
	public bool underlined { get; set; }
	public bool blink { get; set; }
	public bool inverse { get; set; }
	public bool invisible { get; set; }
	public bool erasable { get; set; default = true; }

	public bool equals(CharacterAttributes attributes) {
		return
			(foreground_color == attributes.foreground_color &&
			 background_color == attributes.background_color &&
			 rgb_foreground_color == attributes.rgb_foreground_color &&
			 rgb_background_color == attributes.rgb_background_color &&
			 use_rgb_foreground_color == attributes.use_rgb_foreground_color &&
			 use_rgb_background_color == attributes.use_rgb_background_color &&
			 bold == attributes.bold &&
			 underlined == attributes.underlined &&
			 blink == attributes.blink &&
			 inverse == attributes.inverse &&
			 invisible == attributes.invisible);
	}

	public void reset() {
		// Default attributes
		foreground_color = -1;
		background_color = -1;
		rgb_foreground_color = Gdk.RGBA();
		rgb_background_color = Gdk.RGBA();
		use_rgb_foreground_color = false;
		use_rgb_background_color = false;
		bold = false;
		underlined = false;
		blink = false;
		inverse = false;
		invisible = false;
	}

	private void copy_method(CharacterAttributes character_attributes) {
		foreground_color = character_attributes.foreground_color;
		background_color = character_attributes.background_color;
		rgb_foreground_color = character_attributes.rgb_foreground_color;
		rgb_background_color = character_attributes.rgb_background_color;
		use_rgb_foreground_color = character_attributes.use_rgb_foreground_color;
		use_rgb_background_color = character_attributes.use_rgb_background_color;
		bold = character_attributes.bold;
		underlined = character_attributes.underlined;
		blink = character_attributes.blink;
		inverse = character_attributes.inverse;
		invisible = character_attributes.invisible;
		erasable = character_attributes.erasable;
	}

	public CharacterAttributes() {
		reset();
	}

	public CharacterAttributes.copy(CharacterAttributes character_attributes) {
		copy_method(character_attributes);
	}

	// TODO: Parsing should be performed only ONCE per stream element, not each time it is rendered!
	public CharacterAttributes.from_stream_element(TerminalStream.StreamElement stream_element, CharacterAttributes current_attributes) {
		if (!(stream_element.stream_element_type == TerminalStream.StreamElement.StreamElementType.CONTROL_SEQUENCE &&
			  stream_element.control_sequence_type == TerminalStream.StreamElement.ControlSequenceType.CHARACTER_ATTRIBUTES)) {
			critical(_("Cannot parse stream element into character attributes"));
			return;
		}

		if (stream_element.control_sequence_parameters.is_empty) {
			reset();
			return;
		}

		// Use current attributes as a baseline
		// TODO: We cannot chain up to CharacterAttributes.copy here because
		//       Vala's constructor chaining has bugs that prevent instance methods
		//       from being called from within a constructor if the constructor
		//       chains up to another one
		copy_method(current_attributes);

		// Change attributes according to stream element's specification
		var iterator = stream_element.control_sequence_parameters.list_iterator();
		while (iterator.next()) {
			// TODO: Use get_numeric_parameter here
			var parameter = iterator.get();
			var attribute_code = int.parse(parameter);

			switch (attribute_code) {
			// Text attributes (on)
			case 0:
				// Normal, i.e. reset
				reset();
				break;
			case 1:
				bold = true;
				break;
			case 4:
				underlined = true;
				break;
			case 5:
				blink = true;
				break;
			case 7:
				inverse = true;
				break;
			case 8:
				invisible = true;
				break;

			// Text attributes (off)
			case 22:
				bold = false;
				break;
			case 24:
				underlined = false;
				break;
			case 25:
				blink = false;
				break;
			case 27:
				inverse = false;
				break;
			case 28:
				invisible = false;
				break;

			// Normal foreground color (16 colors)
			case 30:
			case 31:
			case 32:
			case 33:
			case 34:
			case 35:
			case 36:
			case 37:
				foreground_color = attribute_code - 30;
				use_rgb_foreground_color = false;
				break;
			case 39:
				foreground_color = -1;
				use_rgb_foreground_color = false;
				break;

			// Normal background color (16 colors)
			case 40:
			case 41:
			case 42:
			case 43:
			case 44:
			case 45:
			case 46:
			case 47:
				background_color = attribute_code - 40;
				use_rgb_background_color = false;
				break;
			case 49:
				background_color = -1;
				use_rgb_background_color = false;
				break;

			// Bright foreground color (16 colors)
			case 90:
			case 91:
			case 92:
			case 93:
			case 94:
			case 95:
			case 96:
			case 97:
				foreground_color = attribute_code - 90 + 8;
				use_rgb_foreground_color = false;
				break;

			// Bright background color (16 colors)
			case 100:
			case 101:
			case 102:
			case 103:
			case 104:
			case 105:
			case 106:
			case 107:
				background_color = attribute_code - 100 + 8;
				use_rgb_background_color = false;
				break;

			case 38:
			case 48:
				if (iterator.next()) {
					switch (int.parse(iterator.get())) {
					// Indexed color (xterm 256 color mode)
					// See http://lucentbeing.com/blog/that-256-color-thing/
					case 5:
						if (iterator.next()) {
							var color_code = int.parse(iterator.get());
							if (attribute_code == 38) {
								foreground_color = color_code;
								use_rgb_foreground_color = false;
							} else if (attribute_code == 48) {
								background_color = color_code;
								use_rgb_background_color = false;
							}
						} else {
							TerminalOutput.print_interpretation_status(
									stream_element, TerminalOutput.InterpretationStatus.INVALID);
						}
						break;

					// RGB color (Konsole/ISO-8613-3 3-byte color mode)
					// See https://github.com/robertknight/konsole/blob/master/user-doc/README.moreColors
					case 2:
						if (iterator.next()) {
							var red = int.parse(iterator.get());
							if (iterator.next()) {
								var green = int.parse(iterator.get());
								if (iterator.next()) {
									var blue = int.parse(iterator.get());
									var color = Utilities.get_rgb_color(red, green, blue);
									if (attribute_code == 38) {
										rgb_foreground_color = color;
										use_rgb_foreground_color = true;
									} else if (attribute_code == 48) {
										rgb_background_color = color;
										use_rgb_background_color = true;
									}
								} else {
									TerminalOutput.print_interpretation_status(
											stream_element, TerminalOutput.InterpretationStatus.INVALID);
								}
							} else {
								TerminalOutput.print_interpretation_status(
										stream_element, TerminalOutput.InterpretationStatus.INVALID);
							}
						} else {
							TerminalOutput.print_interpretation_status(
									stream_element, TerminalOutput.InterpretationStatus.INVALID);
						}
						break;

					default:
						TerminalOutput.print_interpretation_status(
								stream_element, TerminalOutput.InterpretationStatus.INVALID);
						break;
					}
				} else {
					TerminalOutput.print_interpretation_status(
							stream_element, TerminalOutput.InterpretationStatus.INVALID);
				}
				break;

			default:
				TerminalOutput.print_interpretation_status(
						stream_element, TerminalOutput.InterpretationStatus.INVALID);
				break;
			}
		}
	}

	public Gtk.TextTag[] get_text_tags(Gtk.TextBuffer buffer, ColorScheme color_scheme, bool dark) {
		Gdk.RGBA foreground;
		if (use_rgb_foreground_color) {
			foreground = rgb_foreground_color;
		} else {
			if (foreground_color == -1) {
				foreground = color_scheme.get_foreground_color(dark);
			} else {
				foreground = color_scheme.get_indexed_color(foreground_color, dark);
				if (bold) {
					foreground.red = (foreground.red + 0.1).clamp(0.0, 1.0);
					foreground.green = (foreground.green + 0.1).clamp(0.0, 1.0);
					foreground.blue = (foreground.blue + 0.1).clamp(0.0, 1.0);
				}

			}
		}

		Gdk.RGBA background;
		if (use_rgb_background_color) {
			background = rgb_background_color;
		} else {
			if (background_color == -1) {
				background = color_scheme.get_background_color(dark);
			} else {
				background = color_scheme.get_indexed_color(background_color, dark);
			}
		}

		if (inverse) {
			var temp = background;
			background = foreground;
			foreground = temp;
		}

		var tags = new Gee.ArrayList<Gtk.TextTag>();

		if (background != color_scheme.get_background_color(dark))
			tags.add(buffer.tag_table.lookup(background.to_string()) ??
				buffer.create_tag(background.to_string(), "background_rgba", background));

		if (foreground != color_scheme.get_foreground_color(dark))
			tags.add(buffer.tag_table.lookup(foreground.to_string()) ??
				buffer.create_tag(foreground.to_string(), "foreground_rgba", foreground));

		// Blink appears as Bold according to xterm specification
		if (bold || blink)
			tags.add(buffer.tag_table.lookup("bold") ?? buffer.create_tag("bold", "weight", Pango.Weight.BOLD));

		if (underlined)
			tags.add(buffer.tag_table.lookup("underline") ?? buffer.create_tag("underline", "underline", Pango.Underline.SINGLE));

		if (invisible)
			tags.add(buffer.tag_table.lookup("invisible"));

		if (!erasable)
			tags.add(buffer.tag_table.lookup("non-erasable") ?? buffer.create_tag("non-erasable"));

		return tags.to_array();
	}

	// Translates SGR into Clutter attributes using the specified color scheme
	public TextAttributes get_text_attributes(ColorScheme color_scheme, bool dark) {
		var text_attributes = new TextAttributes();

		if (invisible) {
			// TODO: A vala/bindings bug prevents static colors from being used (GCC error)
			text_attributes.foreground_color = Gdk.RGBA ();
			text_attributes.foreground_color.parse("#00000000");
			text_attributes.background_color = Gdk.RGBA ();
			text_attributes.background_color.parse("#00000000");
			//text_attributes.foreground_color = Gdk.RGBA.get_static(Clutter.StaticColor.TRANSPARENT);
			//text_attributes.background_color = Gdk.RGBA.get_static(Clutter.StaticColor.TRANSPARENT);

		} else {
			Gdk.RGBA color1;
			if (use_rgb_foreground_color) {
				color1 = rgb_foreground_color;
			} else {
				if (foreground_color == -1) {
					color1 = color_scheme.get_foreground_color(dark);
				} else {
					color1 = color_scheme.get_indexed_color(foreground_color, dark);
					if (bold) {
						color1.red = (color1.red + 0.1).clamp(0.0, 1.0);
						color1.green = (color1.green + 0.1).clamp(0.0, 1.0);
						color1.blue = (color1.blue + 0.1).clamp(0.0, 1.0);
					}

				}
			}

			Gdk.RGBA color2;
			if (use_rgb_background_color) {
				color2 = rgb_background_color;
			} else {
				if (background_color == -1) {
					color2 = color_scheme.get_background_color(dark);
				} else {
					color2 = color_scheme.get_indexed_color(background_color, dark);
				}
			}

			if (inverse) {
				text_attributes.foreground_color = color2;
				text_attributes.background_color = color1;
			} else {
				text_attributes.foreground_color = color1;
				text_attributes.background_color = color2;
			}
		}

		// Blink appears as Bold according to xterm specification
		text_attributes.bold = (bold || blink);

		text_attributes.underlined = underlined;

		return text_attributes;
	}

	public string get_markup_attributes(ColorScheme color_scheme, bool dark) {
		return get_text_attributes(color_scheme, dark).get_markup_attributes(color_scheme, dark);
	}
}


public class TextAttributes : Object {

	public Gdk.RGBA foreground_color { get; set; }
	public Gdk.RGBA background_color { get; set; }
	public bool bold { get; set; }
	public bool underlined { get; set; }

	public string get_markup_attributes(ColorScheme color_scheme, bool dark) {
		var attribute_builder = new StringBuilder();

		if (foreground_color != color_scheme.get_foreground_color(dark))
			attribute_builder.append(" foreground='" + Utilities.get_parsable_color_string(foreground_color) + "'");

		if (background_color != color_scheme.get_background_color(dark))
			attribute_builder.append(" background='" + Utilities.get_parsable_color_string(background_color) + "'");

		if (bold)
			attribute_builder.append(" font_weight='bold'");

		if (underlined)
			attribute_builder.append(" underline='single'");

		return attribute_builder.str;
	}

}
