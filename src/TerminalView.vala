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
	private LineContainer line_container;
	private SelectionManager selection_manager;

	private MenuButton menu_button;
	private Label menu_button_label;
	private Label cursor;

	private Gee.Set<int> updated_lines = new Gee.HashSet<int>();

	public TerminalOutputView(Terminal terminal) {
		this.terminal = terminal;

		line_container = new LineContainer();
		line_container.size_allocate.connect ((box) => scroll_to_position());
		add(line_container);
		((Viewport)get_children().nth_data(0)).shadow_type = ShadowType.NONE;

		// Initial synchronization with model
		add_line_views();

		hadjustment.value_changed.connect(() => position_terminal_cursor(false));
		vadjustment.value_changed.connect(() => position_terminal_cursor(false));
		hadjustment.changed.connect(() => position_terminal_cursor(false));
		vadjustment.changed.connect(() => position_terminal_cursor(false));

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

	public void bind_selection(Widget events) {
		selection_manager = new SelectionManager (terminal, line_container, events,
									vadjustment, hadjustment);
	}

	public string get_selection() {
		return selection_manager.get_text();
	}

	// Expands the list of line views until it contains as many elements as the model
	public void add_line_views() {
		for (int i = line_container.get_line_count(); i < terminal.terminal_output.size; i++) {
			var line_view = new LineView(terminal.terminal_output[i], line_container);
			line_view.collapsed.connect(on_line_view_collapsed);
			line_view.expanded.connect(on_line_view_expanded);
			line_view.text_menu_element_hovered.connect(on_line_view_text_menu_element_hovered);

			line_container.add_line_view(line_view);
		}
	}

	private void on_line_view_collapsed(LineView line_view) {
		for (int i = line_container.get_line_view_index(line_view) + 1;
				i < line_container.get_line_count(); i++) {
			if (line_container.get_line_view(i).is_prompt_line)
				break;

			line_container.get_line_view(i).visible = false;
		}
	}

	private void on_line_view_expanded(LineView line_view) {
		for (int i = line_container.get_line_view_index(line_view) + 1;
				i < line_container.get_line_count(); i++) {
			if (line_container.get_line_view(i).is_prompt_line)
				break;

			line_container.get_line_view(i).visible = true;
		}
	}

	private void on_line_view_text_menu_element_hovered(LineView line_view, int x, int y, int width, int height,
			string text, TextMenu text_menu) {
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
		((Fixed) menu_button.parent).move (menu_button, x, y - (int) vadjustment.value);
		menu_button.show ();
	}

	public void mark_line_as_updated(int line_index) {
		updated_lines.add(line_index);
	}

	public void render_terminal_output() {
		render_terminal_text();
		render_terminal_cursor();
	}

	private void render_terminal_text() {
		terminal.terminal_output.print_transient_text();

		foreach (var i in updated_lines) {
			terminal.terminal_output[i].optimize();
			line_container.get_line_view(i).render_line();
		}

		updated_lines.clear();
	}

	public void get_cursor_coordinates (TerminalOutput.CursorPosition pos, out int x, out int y)
	{
		var line_view = line_container.get_line_view (pos.line);
		line_view.get_character_coordinates (pos.column, out x, out y);
		y -= (int) vadjustment.value;
	}

	private void render_terminal_cursor() {
		if (!position_terminal_cursor(true))
			return;

		TerminalOutput.CursorPosition cursor_position = terminal.terminal_output.cursor_position;
		var character_elements = terminal.terminal_output[cursor_position.line].explode();

		string cursor_character;
		TextAttributes cursor_attributes;
		if (cursor_position.column >= character_elements.size) {
			// Cursor is at the end of the line
			cursor_character = "";
			// Default attributes
			cursor_attributes = new CharacterAttributes().get_text_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);
		} else {
			cursor_character  = character_elements[cursor_position.column].text;
			cursor_attributes = character_elements[cursor_position.column].attributes
					.get_text_attributes(Settings.get_default().color_scheme, Settings.get_default().dark);
		}

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

		if (!is_active || cursor_position.line >= line_container.get_line_count()) {
			cursor.hide();
			return false;
		}

		cursor.show();

		int cursor_x;
		int cursor_y;
		get_cursor_coordinates (cursor_position, out cursor_x, out cursor_y);

		var child = Gtk.Allocation ();
		child.x = cursor_x;
		child.y = cursor_y;
		child.width = Settings.get_default().character_width;
		child.height = Settings.get_default().character_height;
		cursor.size_allocate (child);

		return true;
	}

	public void scroll_to_position(TerminalOutput.CursorPosition position = {-1, -1}) {
		if (position.line >= line_container.get_line_count())
			return;

		if (position.line == -1 && position.column == -1) 
			// Default: Scroll to end
			vadjustment.value = vadjustment.upper;
		else {
			Allocation box;
			line_container.get_line_view(position.line).get_allocation (out box);
			vadjustment.value = box.y + box.height;
		}
	}

	public void get_screen_position(TerminalOutput.CursorPosition position, out int? x, out int? y) {
		if (position.line >= line_container.get_line_count()) {
			x = null;
			y = null;
			return;
		}

		var line = line_container.get_line_view(position.line);

		int line_view_x;
		int line_view_y;
		line.get_window ().get_origin (out line_view_x, out line_view_y);

		int character_x;
		int character_y;
		line.get_character_coordinates(position.column, out character_x, out character_y);

		x = line_view_x + character_x;
		y = line_view_y + character_y;
	}

	public int get_horizontal_padding() {
		return
		// 	// Scrollbar width + padding (see style.css)
		// 	14 +
		// 	// LineView padding
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

// TODO: This is a hack, shoudn't be based on box.
public class LineContainer : Box {

	private Gee.List<LineView> line_views = new Gee.ArrayList<LineView>();

	public LineContainer () {
		orientation = Orientation.VERTICAL;
	}

	public void add_line_view(LineView line_view) {
		line_view.line_number = line_views.size;
		line_views.add(line_view);
		add (line_view);
		line_view.show_all ();
	}

	public LineView get_line_view(int index) {
		return line_views[index];
	}

	public int? get_line_index_by_y (int y) {
		for (var i = 0; i < line_views.size; i++) {
			Allocation box;
			line_views[i].get_allocation (out box);
			if (box.y < y && y < box.y + box.height)
				return i;
		}

		return -1;
	}

	public int get_line_view_index(LineView line_view) {
		return line_views.index_of(line_view);
	}

	public int get_line_count() {
		return line_views.size;
	}
}
