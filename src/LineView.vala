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

public class LineView : Box {

	private TerminalOutput.OutputLine original_output_line;
	private TerminalOutput.OutputLine output_line;
	
	private LineContainer line_container;

	private ToggleButton collapse_button = null;
	private Label text_container;

	public bool is_prompt_line { get {return original_output_line.is_prompt_line;}}

	public LineView(TerminalOutput.OutputLine output_line, LineContainer line_container) {
		original_output_line = output_line;
		this.line_container = line_container;

		text_container = new Label ("");
		text_container.wrap = true;
		text_container.wrap_mode = Pango.WrapMode.CHAR;

		var events = new EventBox ();
		events.visible_window = false;
		events.add (text_container);
		events.set_events(Gdk.EventMask.POINTER_MOTION_MASK);
		events.motion_notify_event.connect(on_text_container_motion_event);
		pack_start(events, false, false);

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	public void get_character_coordinates(int index, out int x, out int y) {
		var layout = text_container.get_layout ();
		var length = layout.get_character_count ();
		Pango.Rectangle graph;
		if (index > length) {
			graph = layout.index_to_pos (length);
			graph.x += Settings.get_default ().character_width*Pango.SCALE;
		} else
			graph = layout.index_to_pos (index);

		Allocation box;
		text_container.get_allocation (out box);
		x = graph.x/Pango.SCALE + box.x;
		y = graph.y/Pango.SCALE + box.y;
	}

	private bool on_text_container_motion_event(Gdk.EventMotion event) {
		int byte_index;
		int trailing;
		if (text_container.get_layout().xy_to_index(
				(int) (event.x - text_container.margin_left) * Pango.SCALE,
				(int) event.y * Pango.SCALE,
				out byte_index, out trailing)) {

			var character_index = Utilities.byte_index_to_character_index(
					output_line.get_text(), byte_index);

			TerminalOutput.TextElement text_element;
			int position;
			output_line.get_text_element_from_index(character_index, out text_element, out position);

			if (text_element.attributes.text_menu != null) {
				int character_x;
				int character_y;
				get_character_coordinates(position, out character_x, out character_y);

				text_menu_element_hovered(
						this,
						character_x,
						character_y,
						text_element.get_length() * Settings.get_default().character_width,
						Settings.get_default().character_height,
						text_element.text,
						text_element.attributes.text_menu);
			}
		}

		return false;
	}

	public void render_line() {
		output_line = original_output_line.generate_text_menu_elements();

		if (is_prompt_line && collapse_button == null) {
			// Collapse button has not been created yet
			collapse_button = new ToggleButton.with_label("●");

			collapse_button.get_style_context ().add_class ("collapse-button");
			collapse_button.clicked.connect(on_collapse_button_clicked);

			update_collapse_button();

			pack_start (collapse_button, false, false);
			reorder_child (collapse_button, 0);
			collapse_button.show ();

		} else if (collapse_button != null) {
			if (is_prompt_line)
				collapse_button.show ();
			else
				collapse_button.hide ();

			if (is_collapsible()) {
				if (collapse_button.active) {
					collapse_button.set_label("▶");
				} else {
					collapse_button.set_label("▼");
				}
			}
		}

		if (is_prompt_line) {
			if (output_line.return_code == 0) {
				collapse_button.get_style_context ().remove_class ("error");
				collapse_button.tooltip_text = null;
			} else {
				collapse_button.get_style_context ().add_class ("error");
				collapse_button.tooltip_text = _("Return code") + ": " + output_line.return_code.to_string();
			}
		}

		// If the collapse button is visible, the text container will
		// already be pushed to the left, so we need to subtract that
		text_container.margin_left = Settings.get_default().theme.margin_left +
				(is_prompt_line ?
				 Settings.get_default().theme.gutter_size -
				 	Settings.get_default().theme.collapse_button_width -
				 	Settings.get_default().theme.collapse_button_x :
				 Settings.get_default().theme.gutter_size);

		text_container.set_markup(get_markup(output_line));
	}

	private void update_collapse_button() {
		collapse_button.set_size_request (
			Settings.get_default().theme.collapse_button_width,
			Settings.get_default().theme.collapse_button_height
		);
	}

	private string get_markup(TerminalOutput.OutputLine output_line) {
		var markup_builder = new StringBuilder();

		foreach (var text_element in output_line) {
			var text_attributes = text_element.attributes.get_text_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);
			var markup_attributes = text_attributes.get_markup_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);

			if (markup_attributes.length > 0) {
				markup_builder.append(
						"<span" + markup_attributes + ">" +
						Markup.escape_text(text_element.text) +
						"</span>");
			} else {
				markup_builder.append(Markup.escape_text(text_element.text));
			}
		}

		return markup_builder.str;
	}

	private void on_settings_changed(string? key) {
		if (collapse_button != null)
			update_collapse_button();

		render_line();
	}

	private void on_collapse_button_clicked() {
		if (is_collapsible()) {
			if (collapse_button.active) {
				collapse_button.set_label("▶");
				collapsed(this);
			} else {
				collapse_button.set_label("▼");
				expanded(this);
			}
		}
	}

	private bool is_collapsible() {
		if (!is_prompt_line)
			return false;
		int index = line_container.get_line_view_index(this) + 1;
		if (index >= line_container.get_line_count()) {
			return false;
		} else {
			return (!line_container.get_line_view(index).is_prompt_line);
		}
	}

	public signal void text_menu_element_hovered(LineView line_view, int x, int y, int width, int height,
			string text, TextMenu text_menu);

	public signal void collapsed(LineView line_view);

	public signal void expanded(LineView line_view);

}
