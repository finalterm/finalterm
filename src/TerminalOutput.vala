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

/*
 * Interprets a terminal stream, generating line-by-line formatted screen output
 *
 * The list elements of this class are mutable,
 * because the screen output can be retroactively
 * modified by control sequences.
 */
public class TerminalOutput : Gtk.TextBuffer {

	private Terminal terminal;

	public string terminal_title { get; set; default = "Final Term"; }

	public TerminalMode terminal_modes { get; set; }

	[Flags]
	public enum TerminalMode {
		CURSOR,  // Alternative sequences for array keys
		KBDLOCK, // Disable keyboard
		COLUMN,  // Selects the number of columns in a display line, 80 or 132.
		INSERT,  // Shift characters to the right when inserting
		ECHO,    // Print characters written to tty
		CRLF,    // LF infers CR
		KEYPAD,  // Keypad generates control functions
		NUMLOCK  // Currently unsupported
	}

	private CharacterAttributes current_attributes;

	// Number of lines the virtual "screen" is shifted down
	// with respect to the full terminal output
	public int screen_offset { get; set; }

	// The cursor's position within the full terminal output,
	// not its position on the screen
	public new CursorPosition cursor_position = CursorPosition();

	public struct CursorPosition {
		public int line;
		public int column;

		public int compare(CursorPosition position) {
			int line_difference = line - position.line;

			if (line_difference != 0)
				return line_difference;

			return column - position.column;
		}
	}

	private CursorSave? cursor_save = null;

	private struct CursorSave {
		public CursorPosition position;
		public CharacterAttributes attributes;
		public Encoder encoder;
	}

	// State variables for prompt capturing;
	private bool capturing_prompt = false;
	private string prompt;
	private string prompt_slice;
	private CharacterAttributes slice_attrs;

	private Encoder encoder;

	public string last_command = "";

	public bool command_mode = false;
	public CursorPosition command_start_position;

	public Gee.Map<TextMenu, Gtk.TextTag> tags_by_text_menu;
	private Gtk.TextTag text_menu_tag;
	private CursorPosition text_menu_start;

	private Gee.SortedSet<int> tab_stops;

	private Gee.Set<int> updated_lines;

	public TerminalOutput(Terminal terminal) {
		this.terminal = terminal;

		// Default attributes
		current_attributes = new CharacterAttributes();

		encoder = new Encoder();

		screen_offset = 0;
		move_cursor(0, 0);

		updated_lines = new Gee.HashSet<int>();
		line_updated.connect(on_line_updated);

		tab_stops = new Gee.TreeSet<int>();

		tags_by_text_menu = new Gee.HashMap<TextMenu, Gtk.TextTag>();
		foreach (var text_menu in FinalTerm.text_menus_by_pattern.values)
			tags_by_text_menu[text_menu] = create_tag(null);

		foreach (var text_menu in FinalTerm.text_menus_by_code.values)
			tags_by_text_menu[text_menu] = create_tag(null);

		create_tag("prompt");
	}

	public void interpret_stream_element(TerminalStream.StreamElement stream_element) {
		switch (stream_element.stream_element_type) {
		case TerminalStream.StreamElement.StreamElementType.TEXT:
			//message(_("Text sequence received: '%s'"), stream_element.text);

			print_text(stream_element.text, (terminal_modes & TerminalMode.INSERT) == 0);
			line_updated(cursor_position.line);
			break;

		case TerminalStream.StreamElement.StreamElementType.CONTROL_SEQUENCE:
			//message(_("Control sequence received: '%s' = '%s'"), stream_element.text, stream_element.control_sequence_type.to_string());

			// Descriptions of control sequence effects are taken from
			// http://vt100.net/docs/vt100-ug/chapter3.html,
			// which is more detailed than xterm's specification at
			// http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
			switch (stream_element.control_sequence_type) {

			/* Control sequences for VT102 */

			case TerminalStream.StreamElement.ControlSequenceType.BELL:
				// TODO: Beep on the terminal window rather than the default display
				Gdk.beep();
				break;

			case TerminalStream.StreamElement.ControlSequenceType.BACKSPACE:
				// Move the cursor to the left one character position,
				// unless it is at the left margin, in which case no action occurs
				move_cursor(cursor_position.line, cursor_position.column - 1);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.HORIZONTAL_TAB:
				// VT100 specifies:
				// Moves cursor to next tab stop, or to right margin if there are
				// no more tab stops, but xterm inserts a printable tab instead
				// of moving to the right margin?
				var column = tab_stops.higher(cursor_position.column);
				if (column == 0) {
					Gtk.TextIter iter;
					get_iter_at_line(out iter, cursor_position.line);
					column = iter.get_chars_in_line();
				}

				move_cursor(cursor_position.line, column);

				// print_text("\t");
				line_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.LINE_FEED:
			case TerminalStream.StreamElement.ControlSequenceType.VERTICAL_TAB:
			case TerminalStream.StreamElement.ControlSequenceType.FORM_FEED:
				// Causes a line feed or a new line operation
				if ((terminal_modes & TerminalMode.CRLF) == TerminalMode.CRLF)
					move_cursor(cursor_position.line + 1, 0);
				else
					move_cursor(cursor_position.line + 1, cursor_position.column);
				line_added();
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CARRIAGE_RETURN:
				// Moves cursor to left margin on current line.

				// Wrap long command lines
				if (command_mode && cursor_position.column-1 == terminal.columns)
					move_cursor(cursor_position.line+1, 0); // Move to next line
				else
					move_cursor(cursor_position.line, 0);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SHIFT_OUT:
				// Selects G1 character set designated by a select character set sequence.
				encoder.gl = 1;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SHIFT_IN:
				// Selects G0 character set designated by a select character set sequence.
				encoder.gl = 0;
				break;

			// TODO: Implement unified system for setting and resetting flags
			case TerminalStream.StreamElement.ControlSequenceType.SET_MODE:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 2:
						terminal_modes |= TerminalMode.KBDLOCK;
						break;
					case 4:
						terminal_modes |= TerminalMode.INSERT;
						break;
					case 12:
						terminal_modes &= ~TerminalMode.ECHO;
						break;
					case 20:
						terminal_modes |= TerminalMode.CRLF;
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.RESET_MODE:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 2:
						terminal_modes &= ~TerminalMode.KBDLOCK;
						break;
					case 4:
						terminal_modes &= ~TerminalMode.INSERT;
						break;
					case 12:
						terminal_modes |= TerminalMode.ECHO;
						break;
					case 20:
						terminal_modes &= ~TerminalMode.CRLF;
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEC_PRIVATE_MODE_SET:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 1:
						if ((terminal_modes & TerminalMode.KEYPAD) == TerminalMode.KEYPAD)
							terminal_modes |= TerminalMode.CURSOR;

						break;
					case 3:
						terminal_modes |= TerminalMode.COLUMN;
						terminal.columns = 132;
						terminal.lines = 24;
						move_screen(get_line_count());
						move_cursor_screen(1, 1);
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEC_PRIVATE_MODE_RESET:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 1:
						// Normal Cursor Keys
						terminal_modes &= ~TerminalMode.CURSOR;
						break;
					case 3:
						terminal_modes &= ~TerminalMode.COLUMN;
						terminal.columns = 80;
						terminal.lines = 24;
						move_screen(get_line_count());
						move_cursor_screen(1, 1);
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_UP:
				// Moves cursor up Pn lines in same column. Cursor stops at top margin.
				int line = int.max(stream_element.get_numeric_parameter(0, 1), 1);
				line = int.max(get_screen_position(cursor_position).line - line, 1);
				move_cursor_screen(line, cursor_position.column + 1);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_DOWN:
				// Moves cursor down Pn lines in same column. Cursor stops at bottom margin.
				int line = int.max(stream_element.get_numeric_parameter(0, 1), 1);
				line = int.min(get_screen_position(cursor_position).line + line, terminal.lines);
				move_cursor_screen(line, cursor_position.column + 1);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_FORWARD:
				// Moves cursor one column to right. Cursor stops at right margin.
				int column = int.max(stream_element.get_numeric_parameter(0, 1), 1);
				column = int.min(cursor_position.column + column, terminal.columns);
				move_cursor(cursor_position.line, column);

				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_BACKWARD:
				// Moves cursor one column to left. Cursor stops at left margin.
				int column = int.max(stream_element.get_numeric_parameter(0, 1), 1);
				column = int.max(cursor_position.column - column, 0);
				move_cursor(cursor_position.line, column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.HORIZONTAL_AND_VERTICAL_POSITION:
			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_POSITION:
				int line   = stream_element.get_numeric_parameter(0, 1);
				int column = stream_element.get_numeric_parameter(1, 1);
				move_cursor_screen(line, column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.INDEX:
				// Moves cursor down one line in same column. If cursor is at bottom margin, screen performs a scroll-up.
				if (get_screen_position(cursor_position).line == terminal.lines) move_screen(screen_offset+1);
				move_cursor(cursor_position.line + 1, cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.REVERSE_INDEX:
				// Moves the active position upward without altering the column position.
				if (get_screen_position(cursor_position).line == 1) move_screen(screen_offset-1);
				move_cursor(cursor_position.line - 1, cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.NEXT_LINE:
				if (get_screen_position(cursor_position).line == terminal.lines) move_screen(screen_offset+1);
				move_cursor(cursor_position.line + 1, 0);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SAVE_CURSOR:
			case TerminalStream.StreamElement.ControlSequenceType.SAVE_CURSOR_ANSI_SYS:
				cursor_save = CursorSave () {
					position = cursor_position,
					attributes = new CharacterAttributes.copy(current_attributes),
					encoder = new Encoder.copy(encoder)
				};
				break;

			case TerminalStream.StreamElement.ControlSequenceType.RESTORE_CURSOR:
			case TerminalStream.StreamElement.ControlSequenceType.RESTORE_CURSOR_ANSI_SYS:
				if (cursor_save == null)
					break;

				move_cursor(cursor_save.position.line, cursor_save.position.column);
				current_attributes = cursor_save.attributes;
				encoder = cursor_save.encoder;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.APPLICATION_KEYPAD:
				terminal_modes |= TerminalMode.KEYPAD;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.NORMAL_KEYPAD:
				terminal_modes &= ~TerminalMode.KEYPAD;
				terminal_modes &= ~TerminalMode.CURSOR;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G0_CHARACTER_SET_VT100:
				encoder.setCharset(0, stream_element.get_text_parameter(0, "B"));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G1_CHARACTER_SET_VT100:
			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G1_CHARACTER_SET_VT300:
				encoder.setCharset(1, stream_element.get_text_parameter(0, "B"));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SINGLE_SHIFT_G2_CHARACTER_SET:
				encoder.single_shift = 2;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SINGLE_SHIFT_G3_CHARACTER_SET:
				encoder.single_shift = 3;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CHARACTER_ATTRIBUTES:
				current_attributes = new CharacterAttributes.from_stream_element(stream_element, current_attributes);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.TAB_SET:
				tab_stops.add(cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.TAB_CLEAR:
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					tab_stops.remove(cursor_position.column);
					break;
				case 3:
					tab_stops.clear();
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEC_DOUBLE_HEIGHT_LINE_TOP_HALF:
				Gtk.TextIter start, end;
				get_iter_at_line(out start, cursor_position.line);
				get_iter_at_line(out end, cursor_position.line);
				end.forward_to_line_end();

				// Add tag to entire line. Text drawn in TextView.draw_layer
				apply_tag(tag_table.lookup("double-top") ?? create_tag("double-top", "invisible", true), start, end);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEC_DOUBLE_HEIGHT_LINE_BOTTOM_HALF:
				Gtk.TextIter start, end;
				get_iter_at_line(out start, cursor_position.line);
				get_iter_at_line(out end, cursor_position.line);
				end.forward_to_line_end();

				// Add tag to entire line. Text drawn in TextView.draw_layer
				apply_tag(tag_table.lookup("double-bottom") ?? create_tag("double-bottom", "invisible", true), start, end);
				break;


			case TerminalStream.StreamElement.ControlSequenceType.DEC_DOUBLE_WIDTH_LINE:
				Gtk.TextIter start, end;
				get_iter_at_line(out start, cursor_position.line);
				get_iter_at_line(out end, cursor_position.line);
				end.forward_to_line_end();

				// Add tag to entire line. Text drawn in TextView.draw_layer
				apply_tag(tag_table.lookup("double-wide") ?? create_tag("double-wide", "invisible", true), start, end);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_IN_LINE_EL:
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					// Erase from the active position to the end of the line, inclusive (default)
					erase_line_range(cursor_position.line, cursor_position.column);
					break;
				case 1:
					// Erase from the start of the screen to the active position, inclusive
					// TODO: Is this "inclusive"?
					// TODO: Should this erase from the start of the LINE instead (as implemented here)?
					erase_line_range(cursor_position.line, 0, cursor_position.column);
					break;
				case 2:
					// Erase all of the line, inclusive
					erase_line_range(cursor_position.line);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_IN_LINE_DECSEL:
				// Same as above but will skip text with the non-erasable tag.
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					erase_line_range(cursor_position.line, cursor_position.column, -1, true);
					break;
				case 1:
					erase_line_range(cursor_position.line, 0, cursor_position.column, true);
					break;
				case 2:
					erase_line_range(cursor_position.line, 0, -1, true);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_IN_DISPLAY_ED:
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					// Erase from the active position to the end of the screen, inclusive (default)
					erase_range_screen(get_screen_position(cursor_position));
					break;
				case 1:
					// Erase from start of the screen to the active position, inclusive
					erase_range_screen({1, 1}, get_screen_position(cursor_position));
					break;
				case 2:
					// Erase all of the display - all lines are erased, changed to single-width,
					// and the cursor does not move
					//erase_range_screen();

					/*
					 * THE SECRET OF MODERN TERMINAL SCROLLING
					 *
					 * The text terminal that xterm emulates (VT100) is based on a
					 * single-screen model, i.e. output that is deleted from the screen
					 * or scrolled above the first line disappears forever.
					 * Today, users expect their graphical terminal emulators to
					 * preserve past output and make it accessible by scrolling back up
					 * even when that output is "deleted" with the "Erase in Display"
					 * control sequence.
					 *
					 * The recipe for the proper behavior (which seems to be the one
					 * followed by other graphical terminal emulators as well) is to
					 * replace the action of the "Erase All" subcommand as specified
					 * for VT100 (i.e. wipe the current screen) with the following:
					 *
					 * - Scroll the view down as many lines as are visible (used)
					 *   on the current virtual screen
					 * - Shift the virtual screen as many lines downward
					 * - Move the cursor as many lines downward
					 *
					 * Actually, the behavior implemented by GNOME Terminal is slightly
					 * different, but this recipe gives better results.
					 */
					int visible_lines = get_line_count() - screen_offset;
					move_screen(screen_offset + visible_lines - 1);
					move_cursor(cursor_position.line + visible_lines, cursor_position.column);
					break;

				case 3:
					// Erase Saved Lines (xterm)
					print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_IN_DISPLAY_DECSED:
				// Same as above but will skip text with the non-erasable tag.
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					erase_range_screen(get_screen_position(cursor_position), {-1, -1}, true);
					break;
				case 1:
					erase_range_screen({1, 1}, get_screen_position(cursor_position), true);
					break;
				case 2:
					erase_range_screen({1, 1}, {terminal.lines, terminal.columns}, true);
					break;

				case 3:
					print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DELETE_CHARACTERS:
				// This control function deletes one or more characters from the cursor position to the right
				Gtk.TextIter start, end;
				get_iter_at_line_offset(out start, cursor_position.line, cursor_position.column);
				get_iter_at_line_offset(out end, cursor_position.line,
					cursor_position.column + stream_element.get_numeric_parameter(0, 1));
				this.delete(ref start, ref end);

				line_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.INSERT_LINES:
				var n = stream_element.get_numeric_parameter(0, 1);
				Gtk.TextIter iter;
				get_iter_at_line(out iter, cursor_position.line);
				insert(ref iter, string.nfill(n, '\n'), -1);
				move_screen(screen_offset);
				move_cursor(cursor_position.line, 0);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DELETE_LINES:
				var n = stream_element.get_numeric_parameter(0, 1);
				Gtk.TextIter iter;
				get_iter_at_line(out iter, cursor_position.line);
				iter.backward_char();
				var end = iter;
				end.forward_lines(n);
				end.forward_to_line_end();
				this.delete(ref iter, ref end);
				move_cursor(cursor_position.line, 0);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEVICE_STATUS_REPORT:
				switch (stream_element.get_numeric_parameter(0, 0)) {
					// Request a status report
					case 5:
						// Ready, no malfunctions detected
						terminal.send_text("\033[0n");
						break;

					// Request a cursor position report
					case 6:
						terminal.send_text("\033[%d;%dR".printf(cursor_position.line, cursor_position.column));
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEVICE_STATUS_REPORT_DEC:
				switch (stream_element.get_numeric_parameter(0, 0)) {
					// Request a printer status report
					case 15:
						// Printer not connected
						terminal.send_text("\033[?13n");
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SEND_DEVICE_ATTRIBUTES_PRIMARY:
			case TerminalStream.StreamElement.ControlSequenceType.IDENTIFY_TERMINAL:
				// Identify as VT102 (for now)
				terminal.send_text("\033[?6c");
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FULL_RESET:
				// Resets the terminal to its initial state.
				current_attributes.reset();
				encoder.reset();
				terminal_modes = 0;
				tab_stops.clear();
				cursor_save = null;
				cursor_position = CursorPosition () {
					line = 0,
					column = 0
				};
				screen_offset = 0;
				set_text("");

				cursor_position_changed(cursor_position);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEC_SCREEN_ALIGNMENT_TEST:
				// Fill screen with uppercase E's.
				var lines = new string[terminal.lines];
				for (var i = 0; i < terminal.lines; i++)
					lines[i] = string.nfill(terminal.columns - 1, 'E');

				var text = string.joinv("\n", lines);

				move_cursor_screen(1, 1);
				begin_user_action();
				Gtk.TextIter iter, end;
				get_iter_at_line(out iter, cursor_position.line);
				get_iter_at_line(out end, cursor_position.line + terminal.lines);
				this.delete(ref iter, ref end);
				insert(ref iter, text, text.length);
				end_user_action();

				break;


			/* Control sequences for VT220 and above */

			case TerminalStream.StreamElement.ControlSequenceType.LINE_POSITION_RELATIVE:
				if (get_screen_position(cursor_position).line == terminal.lines) move_screen(screen_offset+1);
				move_cursor(cursor_position.line + stream_element.get_numeric_parameter(0, 1), cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FORWARD_INDEX:
				move_cursor(cursor_position.line, cursor_position.column + 1);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.BACK_INDEX:
				move_cursor(cursor_position.line, cursor_position.column - 1);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.INSERT_CHARACTERS:
				var restore = cursor_position;
				print_text(string.nfill(stream_element.get_numeric_parameter(0, 1), ' '), false);

				// Shouldn't move cursor
				move_cursor(restore.line, restore.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_BACKWARD_TABULATION:
				var count = stream_element.get_numeric_parameter(0, 1);
				var column = tab_stops.lower(cursor_position.column);
				for (var i = 1; i < count; i++)
					column = tab_stops.lower(column);

				move_cursor (cursor_position.line, column);

				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_FORWARD_TABULATION:
				var count = stream_element.get_numeric_parameter(0, 1);
				var column = tab_stops.higher(cursor_position.column);
				for (var i = 1; i < count && column != 0; i++)
					column = tab_stops.higher(column);

				if (column == 0) {
					Gtk.TextIter iter;
					get_iter_at_line(out iter, cursor_position.line);
					column = iter.get_chars_in_line();
				}

				move_cursor (cursor_position.line, column);

				break;

			case TerminalStream.StreamElement.ControlSequenceType.CHARACTER_POSITION_RELATIVE:
				// The CUF sequence moves the active position to the right.
				// The distance moved is determined by the parameter (default: 1)
				move_cursor(cursor_position.line, cursor_position.column + stream_element.get_numeric_parameter(0, 1));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_NEXT_LINE:
				// The CNL sequence moves the active position to down n lines.
				// n is determined by the parameter (default: 1)
				move_cursor(cursor_position.line + stream_element.get_numeric_parameter(0, 1), 0);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_PRECEDING_LINE:
				// The CNL sequence moves the active position to up n lines.
				// n is determined by the parameter (default: 1)
				move_cursor(cursor_position.line - stream_element.get_numeric_parameter(0, 1), 0);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.REPEAT_PRECEDING_GRAPHIC_CHARACTER:
				var n = stream_element.get_numeric_parameter(0, 1);
				Gtk.TextIter start, end;
				get_iter_at_line_offset(out start, cursor_position.line, cursor_position.column - 1);
				get_iter_at_line_offset(out end, cursor_position.line, cursor_position.column);
				char c = get_text(start, end, true)[0];
				insert(ref end, string.nfill(n, c), -1);
				move_cursor(cursor_position.line, cursor_position.column + n);

				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_CHARACTERS:
				// "Erase" means "clear" in this case (i.e. fill with whitespace)
				print_text(string.nfill(stream_element.get_numeric_parameter(0, 1), ' '));

				line_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SCROLL_UP_LINES:
				var n = stream_element.get_numeric_parameter(0, 1);
				move_screen(screen_offset-n);
				move_cursor(cursor_position.line-n, cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SCROLL_DOWN_LINES:
				var n = stream_element.get_numeric_parameter(0, 1);
				move_screen(screen_offset+n);
				move_cursor(cursor_position.line+n, cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.LINE_POSITION_ABSOLUTE:
				move_cursor_screen(stream_element.get_numeric_parameter(0, 1),
						get_screen_position(cursor_position).column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_CHARACTER_ABSOLUTE:
			case TerminalStream.StreamElement.ControlSequenceType.CHARACTER_POSITION_ABSOLUTE:
				move_cursor_screen(get_screen_position(cursor_position).line,
						stream_element.get_numeric_parameter(0, 1));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SELECT_CHARACTER_PROTECTION_ATTRIBUTE:
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
				case 1:
					current_attributes.erasable = false;
					break;
				case 2:
					current_attributes.erasable = true;
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FILL_RECTANGULAR_AREA:
				var fill = (char) stream_element.get_numeric_parameter(0, (int)' ');
				CursorPosition tl = {stream_element.get_numeric_parameter(1, 0),
									stream_element.get_numeric_parameter(2, 0)};
				CursorPosition br = {stream_element.get_numeric_parameter(3, 0),
									stream_element.get_numeric_parameter(4, 0)};
				fill_rect_screen(tl, br, fill);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_RECTANGULAR_AREA:
				CursorPosition tl = {stream_element.get_numeric_parameter(0, 0),
									stream_element.get_numeric_parameter(1, 0)};
				CursorPosition br = {stream_element.get_numeric_parameter(2, 0),
									stream_element.get_numeric_parameter(3, 0)};
				erase_rect_screen(tl, br);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SELECTIVE_ERASE_RECTANGULAR_AREA:
				CursorPosition tl = {stream_element.get_numeric_parameter(0, 0),
									stream_element.get_numeric_parameter(1, 0)};
				CursorPosition br = {stream_element.get_numeric_parameter(2, 0),
									stream_element.get_numeric_parameter(3, 0)};
				erase_rect_screen(tl, br, true);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.INVOKE_G2_CHARACTER_SET_AS_GL:
				encoder.gl = 2;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.INVOKE_G3_CHARACTER_SET_AS_GL:
				encoder.gl = 3;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G2_CHARACTER_SET_VT220:
			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G2_CHARACTER_SET_VT300:
				encoder.setCharset(2, stream_element.get_text_parameter(0, "B"));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G3_CHARACTER_SET_VT220:
			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G3_CHARACTER_SET_VT300:
				encoder.setCharset(3, stream_element.get_text_parameter(0, "B"));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.INSERT_COLUMNS:
				var n = stream_element.get_numeric_parameter(0, 1);
				Gtk.TextIter iter, end;
				for (int i = screen_offset; i <= terminal.lines; i++) {
					validate_position({i, cursor_position.column});

					get_iter_at_line_offset(out iter, i, cursor_position.column);
					insert(ref iter, string.nfill(n, ' '), -1);

					if (iter.get_chars_in_line() > terminal.columns) {
						iter.set_line_offset(terminal.columns);
						get_iter_at_line_offset(out end, i, get_line_length(i));
						this.delete(ref iter, ref end);
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DELETE_COLUMNS:
				var n = stream_element.get_numeric_parameter(0, 1);
				Gtk.TextIter start, end;
				for (int i = screen_offset; i <= terminal.lines; i++) {
					get_iter_at_line(out start, i);
					if (start.get_chars_in_line() <= cursor_position.column + n)
						continue;

					start.set_line_offset(cursor_position.column);
					end = start;
					end.forward_chars(n);
					this.delete(ref start, ref end);
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SET_TEXT_PARAMETERS:
				switch (stream_element.get_numeric_parameter(0, -1)) {
				case 0:
					// Change Icon Name and Window Title
					terminal_title = stream_element.get_text_parameter(1, "Final Term");
					// TODO: Change icon name(?)
					print_interpretation_status(stream_element, InterpretationStatus.PARTIALLY_SUPPORTED);
					break;
				case 2:
					// Change Window Title
					terminal_title = stream_element.get_text_parameter(1, "Final Term");
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_PROMPT:
				if (capturing_prompt) {
					var attrs = slice_attrs.get_markup_attributes(Settings.get_default().color_scheme, Settings.get_default().dark);
					if (attrs == "")
						prompt += prompt_slice;
					else
						prompt += @"<span$attrs>$prompt_slice</span>";

					set_prompt(prompt);
				} else {
					prompt = "";
					prompt_slice = "";
					slice_attrs = current_attributes;
				}

				capturing_prompt = !capturing_prompt;
				break;
			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_START:
				Gtk.TextIter start, end;
				get_iter_at_line(out start, cursor_position.line);
				get_iter_at_line_offset(out end, cursor_position.line, cursor_position.column);
				apply_tag_by_name("prompt", start, end);

				if (command_mode)
					// TODO: This can happen with malformed multi-line commands
					warning(_("Command start control sequence received while already in command mode"));
				command_mode = true;
				move_cursor(cursor_position.line, cursor_position.column);
				command_start_position = cursor_position;
				message(_("Command mode entered"));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_EXECUTED:
				command_mode = false;
				last_command = stream_element.get_text_parameter(0, "");
				command_executed(last_command);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_FINISHED:
				var return_code = stream_element.get_numeric_parameter(0, 0);

				if (last_command != "") {
					command_finished(last_command, return_code);
					progress_finished();
				}

				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_TEXT_MENU_START:
				text_menu_start = cursor_position;
				text_menu_tag = tags_by_text_menu[FinalTerm.text_menus_by_code.get(stream_element.get_numeric_parameter(0, -1))];
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_TEXT_MENU_END:
				Gtk.TextIter start, end;
				get_iter_at_line_offset(out start, text_menu_start.line, text_menu_start.column);
				get_iter_at_line_offset(out end, cursor_position.line, cursor_position.column);
				apply_tag(text_menu_tag, start, end);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_PROGRESS:
				var percentage = stream_element.get_numeric_parameter(0, -1);
				if (percentage == -1) {
					progress_finished();
				} else {
					var operation = stream_element.get_text_parameter(1, "");
					progress_updated(percentage, operation);
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_EXECUTE_COMMANDS:
				var commands = new Gee.ArrayList<Command>();
				var arguments = new Gee.ArrayList<string>();

				var is_argument = false;
				foreach (var parameter in stream_element.control_sequence_parameters) {
					// The "#" character acts as a separator between commands and arguments
					if (parameter == "#" && !is_argument) {
						is_argument = true;
						continue;
					}

					parameter = parameter.strip();

					if (parameter != "") {
						if (is_argument) {
							arguments.add(parameter);
						} else {
							commands.add(new Command.from_command_specification(parameter));
						}
					}
				}

				foreach (var command in commands) {
					command.execute(arguments);
				}

				break;

			case TerminalStream.StreamElement.ControlSequenceType.UNKNOWN:
				print_interpretation_status(stream_element, InterpretationStatus.UNRECOGNIZED);
				break;

			default:
				print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
				break;
			}
			break;
		}
	}

	public enum InterpretationStatus {
		INVALID,
		UNRECOGNIZED,
		UNSUPPORTED,
		PARTIALLY_SUPPORTED,
		SUPPORTED
	}

	public static void print_interpretation_status(TerminalStream.StreamElement stream_element,
													InterpretationStatus interpretation_status) {
		if (stream_element.stream_element_type != TerminalStream.StreamElement.StreamElementType.CONTROL_SEQUENCE) {
			critical(_("print_interpretation_status should only be called on control sequence elements"));
			return;
		}

		switch (interpretation_status) {
		case InterpretationStatus.INVALID:
			warning(_("Invalid control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.UNRECOGNIZED:
			warning(_("Unrecognized control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.UNSUPPORTED:
			warning(_("Unsupported control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.PARTIALLY_SUPPORTED:
			message(_("Partially supported control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.SUPPORTED:
			debug(_("Supported control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		default:
			critical(_("Unrecognized interpretation status value"));
			break;
		}
	}

	public string get_command() {
		// TODO: Revisit this check (condition should never fail)
		if (command_start_position.compare(cursor_position) < 0) {
			return get_range(command_start_position, cursor_position);
		} else {
			return "";
		}
	}

	public void mark_text_menus() {
		foreach(var line in updated_lines)
		{
			Gtk.TextIter start_iter;
			get_iter_at_line(out start_iter, line);
			var end_iter = start_iter;
			end_iter.forward_to_line_end();
			var text = get_slice(start_iter, end_iter, true);
			foreach (var entry in FinalTerm.text_menus_by_pattern.entries) {
				MatchInfo info;
				int start, end;
				if (!entry.key.match(text, 0, out info))
					continue;

				do {
					info.fetch_pos(0, out start, out end);
					start_iter.set_line_index(start);
					end_iter.set_line_index(end);
					apply_tag(tags_by_text_menu[entry.value], start_iter, end_iter);
				} while (info.next());
			}
		}
		updated_lines.clear();
	}

	private void print_text(string text, bool overwrite = true) {
		var encoded = encoder.encode(text);

		if (capturing_prompt) {
			if (slice_attrs != current_attributes) {
				var attrs = slice_attrs.get_markup_attributes(Settings.get_default().color_scheme, Settings.get_default().dark);
				if (attrs == "")
					prompt += prompt_slice;
				else
					prompt += @"<span$attrs>$prompt_slice</span>";

				prompt_slice = "";
				slice_attrs = current_attributes;
			}
			prompt_slice += encoded;
		} else {
			begin_user_action();
			Gtk.TextIter iter, start;
			get_iter_at_line_offset(out iter, cursor_position.line, cursor_position.column);

			insert(ref iter, encoded, encoded.length);

			get_iter_at_line_offset(out start, cursor_position.line, cursor_position.column);
			var tags = current_attributes.get_text_tags(this, Settings.get_default().color_scheme, Settings.get_default().dark);
			foreach (var tag in tags)
				apply_tag(tag, start, iter);

			// If this is a double-wide or double-high line expand tag to the new line end
			if (!start.ends_line())
			{
				var end = start;
				end.forward_to_line_end();

				var tag = tag_table.lookup("double-wide");
				if (tag != null && start.ends_tag(tag))
					apply_tag(tag, start, end);

				tag = tag_table.lookup("double-top");
				if (tag != null && start.ends_tag(tag))
					apply_tag(tag, start, end);

				tag = tag_table.lookup("double-bottom");
				if (tag != null && start.ends_tag(tag))
					apply_tag(tag, start, end);
			}

			start = iter;

			// Printed text should overwrite previous content on the line
			if (overwrite && iter.get_chars_in_line()-1 > 0) {
				iter.set_line_offset(int.min (iter.get_line_offset() + encoded.char_count(), iter.get_chars_in_line() - 1));
				if (iter.get_offset() > start.get_offset())
					this.delete(ref start, ref iter);
			}

			end_user_action();

			// TODO: Handle double-width unicode characters and tabs
			move_cursor(cursor_position.line, cursor_position.column + encoded.char_count());
		}
	}

	private void on_line_updated(int line_index) {
		if (command_mode) {
			command_updated(get_command());
			return;
		}

		updated_lines.add(line_index);

		Utilities.schedule_execution(() =>
			mark_text_menus(), "mark_text_menus", 0, Priority.DEFAULT_IDLE);
	}

	private CursorPosition get_screen_position(CursorPosition position) {
		// Screen coordinates are 1-based (see http://vt100.net/docs/vt100-ug/chapter3.html)
		return {position.line - screen_offset + 1, position.column + 1};
	}

	private CursorPosition get_absolute_position(CursorPosition position) {
		return {position.line + screen_offset - 1, position.column - 1};
	}

	private void move_screen(int to) {
		screen_offset = to;

		// Validate bottom of screen
		validate_position({screen_offset + terminal.lines, 0});

		// Remove extra lines below screen
		int delete = get_line_count() - screen_offset - terminal.lines - 1;
		if (delete < 1)
			return;

		Gtk.TextIter iter;
		get_end_iter(out iter);
		var end = iter;
		iter.backward_lines(delete);
		this.delete (ref iter, ref end);
	}

	private void move_cursor(int line, int column) {
		// TODO: Use uint as a parameter type to ensure positivity here
		cursor_position.line   = int.max(line, 0);
		cursor_position.column = int.max(column, 0);

		// Ensure that the virtual screen contains the cursor
		var new_offset = cursor_position.line - terminal.lines + 1;
		if (new_offset > screen_offset)
			move_screen(new_offset);

		validate_position(cursor_position);
	}

	private void validate_position(CursorPosition position) {
		// Add enough lines to make the line index valid
		int lines_to_add = position.line - get_line_count() + 1;
		if (lines_to_add > 0) {
			Gtk.TextIter end;
			get_end_iter(out end);
			insert(ref end, string.nfill(lines_to_add, '\n'), -1);
		}

		// Add enough whitespace to make the column index valid
		Gtk.TextIter iter;
		get_iter_at_line_offset(out iter, position.line, get_line_length(position.line));
		int columns_to_add = position.column - iter.get_line_offset();
		if (columns_to_add > 0)
			insert(ref iter, string.nfill(columns_to_add, ' '), -1);

		cursor_position_changed(cursor_position);
	}

	private void move_cursor_screen(int line, int column) {
		// TODO: Coordinates of (0, 0) should act like (1, 1) according to specification
		move_cursor(line + screen_offset - 1, column - 1);
	}

	// Returns the text contained in the specified range
	public string get_range(CursorPosition start_position = {-1, -1},
							 CursorPosition end_position   = {-1, -1}) {
		Gtk.TextIter start;
		Gtk.TextIter end;
		if (start_position.line == -1)
			get_start_iter(out start);
		else {
			get_iter_at_line(out start, start_position.line);
			if (start.get_chars_in_line() > start_position.column)
				start.forward_chars(start_position.column);
			else
				start.forward_to_line_end();
		}

		if (end_position.line == -1)
			get_start_iter(out end);
		else {
			get_iter_at_line(out end, end_position.line);
			if (end.get_chars_in_line() > end_position.column)
				end.forward_chars(end_position.column);
			else
				end.forward_to_line_end();
		}

		return get_slice(start, end, false);
	}

	private void erase_range(CursorPosition start_position, CursorPosition end_position,
							bool only_erasables = false) {
		if (start_position.line == end_position.line) {
			erase_line_range(start_position.line, start_position.column, end_position.column, only_erasables);
			return;
		}

		// Works because start and end position are on different lines
		erase_line_range(start_position.line, start_position.column, -1, only_erasables);

		for (int i = start_position.line + 1; i < end_position.line; i++) {
			erase_line_range(i, 0, -1, only_erasables);
		}

		erase_line_range(end_position.line, 0, end_position.column, only_erasables);
	}

	private void erase_range_screen(CursorPosition start_position = {1, 1},
									CursorPosition end_position   = {terminal.lines, terminal.columns + 1},
									bool only_erasables = false) {
		var absolute_start_position = get_absolute_position(start_position);
		var absolute_end_position   = get_absolute_position(end_position);

		erase_range(absolute_start_position, absolute_end_position, only_erasables);
	}

	private void erase_line_range(int line, int start_position = 0, int end_position = -1,
									bool only_erasables = false) {
		Gtk.TextIter start, end;
		get_iter_at_line(out start, line);
		var end_offset = end_position < 0 ? get_line_length(line) : end_position;
		if (end_offset <= start_position)
			return;

		validate_position({line, end_offset});
		get_iter_at_line_offset(out start, line, start_position);
		get_iter_at_line_offset(out end, line, end_offset);

		var tag = tag_table.lookup("non-erasable");
		if (only_erasables && tag != null) {
			do {
				if (start.has_tag(tag))
					start.forward_to_tag_toggle(tag);

				if (start.get_line() != line || start.get_line_offset() >= end_offset)
					break;

				end = start;
				end.forward_to_tag_toggle(tag);
				if (end.get_line() != line || end.get_line_offset() > end_offset)
					get_iter_at_line_offset(out end, line, end_offset);

				var fill = string.nfill(end.get_offset()-start.get_offset(), ' ');
				this.delete(ref start, ref end);
				insert(ref end, fill, fill.length);
			} while (end.get_line_offset() < end_offset);
		}
		else {
			var fill = string.nfill(end.get_offset()-start.get_offset(), ' ');
			this.delete(ref start, ref end);
			insert(ref start, fill, fill.length);
		}

		line_updated(line);
	}

	private void erase_rect (CursorPosition tl, CursorPosition br,
								bool only_erasables = false) {
		for(var i = tl.line; i <= br.line; i++){
			erase_line_range(i, tl.column, br.column, only_erasables);
		}

	}

	private void erase_rect_screen (CursorPosition tl, CursorPosition br,
							bool only_erasables = false) {
		erase_rect(get_absolute_position(tl),
					get_absolute_position(br), only_erasables);
	}

	private void fill_rect(CursorPosition tl, CursorPosition br,
							char fill = ' ') {
		for(var i = tl.line; i <= br.line; i++) {
			validate_position({i, br.column});

			Gtk.TextIter start, end;
			get_iter_at_line_offset(out start, i, tl.column);
			get_iter_at_line_offset(out end, i, br.column);
			this.delete(ref start, ref end);
			insert(ref start, string.nfill(br.column - tl.column, fill), -1);

			line_updated(i);
		}
	}

	private void fill_rect_screen(CursorPosition tl, CursorPosition br,
							char fill = ' ') {
		fill_rect(get_absolute_position(tl),
					get_absolute_position(br), fill);
	}

	private int get_line_length(int line) {
		Gtk.TextIter iter;
		get_iter_at_line(out iter, line);
		var length = iter.get_chars_in_line();
		return get_line_count()-1 > line && length > 0 ? length - 1 : length;
	}

	public signal void set_prompt(string prompt);

	public signal void line_added();

	public signal void line_updated(int line_index);

	public signal void command_updated(string command);

	public signal void command_executed(string command);

	public signal void command_finished(string command, int return_code);

	public signal void progress_updated(int percentage, string operation);

	public signal void progress_finished();

	public signal void cursor_position_changed(CursorPosition new_position);
}
