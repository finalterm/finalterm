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
public class SelectionManager : Object {
	private Selection selection;
	private Terminal terminal;
	private LineContainer line_container;
	private Gtk.Widget events;
	private Gtk.Adjustment voffset;
	private Gtk.Adjustment hoffset;

	private bool drag;

	public SelectionManager(Terminal terminal, LineContainer line_container, Gtk.Widget events,
						Gtk.Adjustment voffset, Gtk.Adjustment hoffset) {
		this.terminal = terminal;
		this.line_container = line_container;
		this.events = events;
		this.voffset = voffset;
		this.hoffset = hoffset;
		events.button_press_event.connect(on_button_press_event);
		events.motion_notify_event.connect(on_motion_notify_event);
		events.button_release_event.connect(on_button_release_event);
	}

	public string get_text()
	{
		if (selection != null)
			return selection.get_text();

		return "";
	}

	private bool on_button_press_event(Gdk.EventButton event) {
		if (event.button != 1)
			return false;

		if (selection != null)
			selection.clear ();

		var x = (int) (event.x + hoffset.value);
		var y = (int) (event.y + voffset.value);

		var line_number = line_container.get_line_index_by_y(y);
		if (line_number < 0)
			return false;

		drag = false;
		selection = new Selection ();
		if (event.state == Gdk.ModifierType.SHIFT_MASK)
			selection.type = Selection.SelectionType.COLUMN;

		var line = line_container.get_line_view(line_number);
		line_container.translate_coordinates (line, x, y, out x, out y);

		switch (event.type) {
			case Gdk.EventType.BUTTON_PRESS:
				selection.start = line.get_index_by_xy (x, y);
				selection.lines.add(line);
				break;
			case Gdk.EventType.2BUTTON_PRESS:
				var index = line.get_index_by_xy (x, y);
				var text = line.get_text();
				selection.lines.add(line);
				selection.start = text[0:index].last_index_of(" ")+1;
				selection.end = text.index_of(" ", index);
				selection.done = true;
				selection.highlight();
				break;
			case Gdk.EventType.3BUTTON_PRESS:
				selection.start = 0;
				selection.lines.add(line);
				selection.end = line.get_text().length;
				selection.done = true;
				selection.highlight();
				break;
		}

		return false;
	}

	private bool on_motion_notify_event(Gdk.EventMotion event) {
		drag = true;
		var x = (int) (event.x + hoffset.value);
		var y = (int) (event.y + voffset.value);
		
		var end_line = line_container.get_line_index_by_y(y);
		if (end_line < 0)
			return false;

		if (selection == null || selection.done)
			return line_container.get_line_view(end_line)
					.on_parent_motion_event (events, event);

		var line = selection.lines[0];
		selection.clear();
		selection.lines.add(line);

		var start_line = selection.lines[0].line_number;
		var small = start_line < end_line ? start_line + 1 : end_line + 1;
		var large = start_line < end_line ? end_line : start_line;
		for (var i = small; i < large; i++)
		{
			line = line_container.get_line_view(i);
			selection.lines.add(line);
		}

		line = line_container.get_line_view(end_line);
		line_container.translate_coordinates (line, x, y, out x, out y);
		selection.end = line.get_index_by_xy (x, y);
		selection.lines.add(line);

		selection.highlight();

		return false;
	}

	private bool on_button_release_event(Gdk.EventButton event) {
		if (selection != null)
			selection.done = true;

		if (drag)
			return false;

		// Move cursor with mouse
		var mark = terminal.terminal_output.command_start_position;
		if (mark.line != selection.lines[0].line_number)
			return false;

		var index = selection.start;
		if (index < mark.column)
			index = mark.column;

		index -= terminal.terminal_output.cursor_position.column;

		if (index > 0)
			terminal.send_text (Utilities.repeat_string("\033[C", index));
		else
			terminal.send_text (Utilities.repeat_string("\033[D", index.abs()));

		return false;
	}

	private class Selection {
		public int start;
		public int end;
		public Gee.AbstractList<LineView> lines = new Gee.LinkedList<LineView>();
		public SelectionType type = SelectionType.LINE;
		public bool done = false;

		public enum SelectionType {
			LINE,
			COLUMN
		}

		public void clear () {
			foreach (var line in lines)
				line.clear_selection();

			lines.clear();
		}

		public string get_text () {
			var text = "";
			switch(type) {
				case SelectionType.LINE:
					var first = lines[0];
					var last = lines[lines.size-1];
					string last_text = "";
					if (first.line_number < last.line_number) {
						text += first.get_text()[start:-1]+"\n";
						last_text = last.get_text()[0:end];
					} else if (first.line_number > last.line_number) {
						text += first.get_text()[0:start]+"\n";
						last_text = last.get_text()[end:-1];
					} else
						text += first.get_text()[start:end]+"\n";

					for (var i = 1; i < lines.size-1; i++)
						text += lines[i].get_text ()+"\n";

					text += last_text;
					break;

				case SelectionType.COLUMN:
					for (var i = 0; i < lines.size; i++)
						text += lines[i].get_text()[start:end]+"\n";
					break;
			}

			return text;
		}

		public void highlight () {
			switch(type) {
				case SelectionType.LINE:
					var first = lines[0];
					var last = lines[lines.size-1];
					if (first.line_number < last.line_number) {
						first.set_selection(start, -1);
						last.set_selection(0, end);
					} else if (first.line_number > last.line_number) {
						first.set_selection(0, start);
						last.set_selection(end, -1);
					} else
						first.set_selection(start, end);

					for (var i = 1; i < lines.size-1; i++)
						lines[i].set_selection(0, -1);
					break;

				case SelectionType.COLUMN:
					for (var i = 0; i < lines.size; i++)
						lines[i].set_selection(start, end);
					break;
			}
		}
	}
}