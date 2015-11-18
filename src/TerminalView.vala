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

using Gtk;

// TODO: Clean up the relationship between TerminalView and TerminalOutputView
public class TerminalView : Fixed {

	private Terminal terminal;

	public TerminalOutputView terminal_output_view;

	private ProgressBar progress_bar;
	private Label progress_label;

	public TerminalView(Terminal terminal) {
		this.terminal = terminal;

		var box = new Box (Orientation.VERTICAL, 5);
		put (box, 0, 0);
		
		size_allocate.connect((alloc) => {
			var child = Gtk.Allocation ();
			child.x = 0;
			child.y = 0;
			child.width = alloc.width;
			child.height = alloc.height;
			box.size_allocate (child);
		});

		terminal_output_view = new TerminalOutputView(terminal);
		box.pack_start(terminal_output_view, true, true);

		progress_label = new Label("");
		progress_label.get_style_context ().add_class ("progress-label");
		box.add(progress_label);
		progress_bar = new ProgressBar();
		progress_bar.no_show_all = true;
		box.add(progress_bar);

		box.add(new StatusBar(terminal));
	}

	public void show_progress(int percentage, string label = "") {
		progress_bar.show();
		progress_label.show();
		progress_label.label = label;
		progress_bar.fraction = (double)percentage / 100.0;
	}

	public void hide_progress() {
		progress_bar.hide();
		progress_label.hide();
	}

	public bool window_has_focus() {
		return (get_toplevel() as Gtk.Window).has_toplevel_focus;
	}
}

public class TerminalOutputView : ScrolledWindow {

	public bool is_active { get; set; }

	private Terminal terminal;
	private TextView view;

	private MenuButton menu_button;
	private Label menu_button_label;
	private Label cursor;

	private Gee.Map<int,string> tooltips = new Gee.HashMap<int,string>();


	public TerminalOutputView(Terminal terminal) {
		this.terminal = terminal;

		view = new TextView.with_buffer (terminal.terminal_output);
		view.editable = false;
		view.cursor_visible = false;
		view.wrap_mode = WrapMode.CHAR;
		view.motion_notify_event.connect(on_motion_notify_event);
		view.button_press_event.connect(on_button_press_event);
		view.has_tooltip = true;
		view.query_tooltip.connect ((x, y, keyboard_tooltip, tooltip) => {
			if (keyboard_tooltip)
				return false;

			TextIter iter;
			view.window_to_buffer_coords(TextWindowType.TEXT, x, y, out x, out y);
			view.get_iter_at_position (out iter, null, x, y);
			var key = iter.get_offset();
			if (!tooltips.has_key(key))
				return false;

			tooltip.set_text(tooltips[key]);
			return true;
		});
		view.show();
		add(view);

		terminal.terminal_output.create_tag("invisible", "invisible", true);
		terminal.terminal_output.create_tag("error", "foreground", "#FF0000");
		terminal.terminal_output.changed.connect (() => {
			Utilities.schedule_execution(() =>
				scroll_to_position(), "scroll_to_position", 0, Priority.DEFAULT_IDLE);
		});
		terminal.terminal_output.command_finished.connect((cmd, code) => {
			if (code == 0)
				return;

			TextIter iter;
			var c = terminal.terminal_output.cursor_position;
			view.buffer.get_iter_at_line_offset(out iter, c.line, c.column);
			var tag = view.buffer.tag_table.lookup("prompt");
			iter.backward_to_tag_toggle(tag);
			var end = iter;
			iter.backward_char();
			var text = _("Return code") + ": " + code.to_string();
			while (iter.has_tag(tag)) {
				tooltips[iter.get_offset()] = text;
				if (!iter.backward_char())
					break;;
			}

			view.buffer.apply_tag_by_name("error", iter, end);
		});

		vadjustment.value_changed.connect(() => {
			var height = Settings.get_default().character_height;
			vadjustment.value = Math.round(vadjustment.value/height)*height;
			position_terminal_cursor(false);
		});

		menu_button = new MenuButton();
		menu_button.get_style_context().add_class("menu-button");
		menu_button.leave_notify_event.connect((event) => {
			menu_button.hide();
			return false;
		});
		menu_button.clicked.connect((e) => {
			menu_button.show ();
			ulong handler = 0;
			handler = menu_button.popup.deactivate.connect(() => {
				menu_button.hide ();
				menu_button.popup.disconnect (handler);
			});
		});

		menu_button_label = new Label("");
		menu_button_label.use_markup = true;
		menu_button.add(menu_button_label);

		cursor = new Gtk.Label ("");
		cursor.get_style_context ().add_class ("cursor");
		cursor.use_markup = true;
		cursor.set_size_request(Settings.get_default().character_width, Settings.get_default().character_height);

		// Cursor and menu button need to float above all other children of the TerminalOutputView
		// so they are added to the parent (TerminalView)
		parent_set.connect((old_parent) => {
			if (parent == null)
				return;

			var fixed = parent.parent as Fixed;
			if (fixed == null)
				return;

			fixed.put(cursor, 0, 0);
			fixed.put(menu_button, 0, 0);

			// TODO: Why doesn't this work?
			// menu_button.no_show_all = true;
			fixed.show.connect (() => menu_button.hide ());
		});

		notify["is-active"].connect(() => {
			if (is_active)
				render_terminal_cursor();
			else
				cursor.hide();
		});
	}

	// Retrieve and show text menus
	private bool on_motion_notify_event(Gdk.EventMotion e) {
		int x, y;
		TextIter iter;
		TextTag tag = null;
		TextMenu text_menu = null;
		view.window_to_buffer_coords(TextWindowType.TEXT, (int)e.x, (int)e.y, out x, out y);
		view.get_iter_at_position (out iter, null, x, y);
		foreach (var entry in terminal.terminal_output.tags_by_text_menu.entries)
			if (iter.has_tag(entry.value)) {
				text_menu = entry.key;
				tag = entry.value;
				break;
			}

		if(text_menu == null)
			return false;

		TextIter end = iter;
		if (!iter.begins_tag(tag))
			iter.backward_to_tag_toggle(tag);
		if (!end.ends_tag(tag))
			end.forward_to_tag_toggle(tag);
		var text = view.buffer.get_slice(iter, end, true);

		Gdk.Rectangle location;
		view.get_iter_location (iter, out location);
		view.buffer_to_window_coords(TextWindowType.TEXT, location.x, location.y, out x, out y);

		text_menu.text = text;
		menu_button.popup = text_menu.menu;

		menu_button_label.override_background_color(StateFlags.NORMAL,
			Settings.get_default().color_scheme.get_indexed_color(
				text_menu.color, Settings.get_default().dark));

		var arrow = Utilities.get_parsable_color_string(
						Settings.get_default().theme.menu_button_arrow_color);
		var label_font = Settings.get_default().label_font_name;
		var terminal_font = Settings.get_default().terminal_font_name;
		var label = Markup.escape_text(text_menu.label);
		var markup = Markup.escape_text(text);
		menu_button_label.label =
			@"<span font_desc=\"$label_font\">$label:  </span>" +
			@"<span font_desc=\"$terminal_font\">$markup</span>" +
			@"<span foreground=\"$arrow\">  ▼</span>";

		int descriptor_width;
		int descriptor_height;
		Utilities.get_text_size(Settings.get_default().label_font, text_menu.label + ":  ",
				out descriptor_width, out descriptor_height);

		x = x - descriptor_width > 0 ? x - descriptor_width : 0;
		((Fixed) menu_button.parent).move (menu_button, x, y);
		menu_button.show ();

		return false;
	}

	// Move command cursor on click
	private bool on_button_press_event(Gdk.EventButton e) {
		TextIter iter;
		int x, y;
		view.window_to_buffer_coords(TextWindowType.TEXT, (int)e.x, (int)e.y, out x, out y);
		view.get_iter_at_position (out iter, null, x, y);

		var mark = terminal.terminal_output.command_start_position;
		if (mark.line != iter.get_line()) {
			// Hide command output on prompt click
			var tag = view.buffer.tag_table.lookup("prompt");
			if (iter.has_tag(tag)) {
				iter.forward_to_line_end();
				var end = iter;
				end.forward_to_tag_toggle(tag);
				tag = view.buffer.tag_table.lookup("invisible");
				if (iter.has_tag(tag)) {
					view.buffer.remove_tag(tag, iter, end);
					iter.set_line_offset(1);
					end = iter;
					end.forward_char();
					view.buffer.delete(ref iter, ref end);
					view.buffer.insert(ref iter, " \u1433 ", 5);
				} else {
					view.buffer.apply_tag(tag, iter, end);
					iter.set_line_offset(1);
					end = iter;
					end.forward_chars(3);
					view.buffer.delete(ref iter, ref end);
					view.buffer.insert(ref iter, "\u2015", 3);
				}
			}

			return false;
		}

		var index = iter.get_line_offset();
		if (index < mark.column)
			index = mark.column;

		index -= terminal.terminal_output.cursor_position.column;

		if (index > 0)
			terminal.send_text (Utilities.repeat_string("\033[C", index));
		else
			terminal.send_text (Utilities.repeat_string("\033[D", index.abs()));

		return false;
	}

	public void get_cursor_coordinates (TerminalOutput.CursorPosition pos, out int x, out int y) {
		TextIter iter;
		Gdk.Rectangle location;
		terminal.terminal_output.get_iter_at_line(out iter, pos.line);
		if (pos.column > iter.get_chars_in_line())
			iter.forward_to_line_end();
		else
			iter.set_line_offset(pos.column);

		view.get_iter_location(iter, out location);
		view.buffer_to_window_coords(TextWindowType.TEXT, location.x, location.y, out x, out y);
	}

	public void render_terminal_cursor() {
		if (!position_terminal_cursor(true))
			return;

		TerminalOutput.CursorPosition cursor_position = terminal.terminal_output.cursor_position;
		TerminalOutput.CursorPosition next = { cursor_position.line, cursor_position.column+1 };

		string cursor_character = terminal.terminal_output.get_range(cursor_position, next);

		TextAttributes cursor_attributes = new CharacterAttributes().get_text_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);

		// Switch foreground and background colors for cursor
		cursor_attributes.foreground_color = cursor_attributes.background_color;
		// Set attributes' background color to default to leave background color rendering
		// to the actor rather than Pango (more reliable and consistent)
		cursor_attributes.background_color = Settings.get_default().background_color;

		var markup_attributes = cursor_attributes.get_markup_attributes(
				Settings.get_default().color_scheme, Settings.get_default().dark);

		cursor.label =
				"<span" + markup_attributes + ">" +
				Markup.escape_text(cursor_character) +
				"</span>";
	}

	private bool position_terminal_cursor(bool animate) {
		TerminalOutput.CursorPosition cursor_position = terminal.terminal_output.cursor_position;

		if (!is_active) {
			cursor.hide();
			return false;
		}

		cursor.show();

		int cursor_x;
		int cursor_y;
		get_cursor_coordinates (cursor_position, out cursor_x, out cursor_y);
		((Fixed)parent.parent).move(cursor, cursor_x, cursor_y);

		return true;
	}

	public void scroll_to_position(TerminalOutput.CursorPosition position = {-1, -1}) {
		if (position.line == -1 && position.column == -1) 
			// Default: Scroll to end
			vadjustment.value = vadjustment.upper;
		else {
			TextIter iter;
			view.buffer.get_iter_at_line_offset(out iter, position.line, position.column);
			view.scroll_to_iter(iter, 0, false, 0, 0) ;
		}
	}

	public void get_screen_position(TerminalOutput.CursorPosition position, out int x, out int y) {
		if (position.line >= view.buffer.get_line_count()) {
			x = -1;
			y = -1;
			return;
		}

		int origin_x, origin_y;
		get_cursor_coordinates(position, out x, out y);
		view.get_window(TextWindowType.TEXT).get_origin(out origin_x, out origin_y);

		x += origin_x;
		y += origin_y;
	}

	public int get_horizontal_padding() {
		return
		// 	// Scrollbar width + padding (see style.css)
		// 	14 +
				Settings.get_default().theme.margin_left +
				Settings.get_default().theme.margin_right +
				Settings.get_default().character_width;
	}

	public int get_vertical_padding() {
		return 0;
	}

	public override void size_allocate (Allocation box) {
		base.size_allocate (box);
		int lines = (box.height - get_vertical_padding()) /
				Settings.get_default().character_height;
		int columns = (box.width - get_horizontal_padding()) /
				Settings.get_default().character_width;

		if (lines <= 0 || columns <= 0)
			// Invalid size
			return;

		if (terminal.lines == lines && terminal.columns == columns)
			// No change in size
			return;

		// Notify terminal of size change
		terminal.lines   = lines;
		terminal.columns = columns;
		// TODO: Use Utilities.schedule_execution here?
		terminal.update_size();
	}
}