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

public class Autocompletion : Object {

	private Window popup_window;

	private NotifyingList<AutocompletionEntry> entries;

	private ScrollableTreeView tree_view;

	private int selected_index;
	private string current_command = "";
	private int maximum_length = 0;

	public Autocompletion() {
		popup_window = new Window(WindowType.POPUP);

		entries = new NotifyingList<AutocompletionEntry>();

		tree_view = new ScrollableTreeView<AutocompletionEntry> (entries, new AutocompletionEntryView ());
		popup_window.add(tree_view);

		tree_view.set_filter_function<AutocompletionEntry>(filter_function);
		tree_view.set_sort_function<AutocompletionEntry>(sort_function);
	}

	public void save_entries_to_file(string filename) {
		Utilities.save_list_to_file<AutocompletionEntry>(entries, filename);
	}

	public void load_entries_from_file(string filename) {
		entries.add_all(Utilities.load_list_from_file<AutocompletionEntry>(
				typeof(AutocompletionEntry),
				filename));
	}

	// Ensures that only entries containing the current command are shown
	private bool filter_function(AutocompletionEntry item) {
		if (Settings.get_default().case_sensitive_autocompletion ?
				item.text.contains(current_command) :
				item.text.casefold().contains(current_command.casefold()))
		{
			maximum_length = int.max(maximum_length, item.text.length);
			return true;
		}

		return false;
	}

	// Ranks entries so that the most relevant ones are shown first
	private int sort_function(AutocompletionEntry item_1, AutocompletionEntry item_2) {
		int index_1 = item_1.text.index_of(current_command);
		int index_2 = item_2.text.index_of(current_command);

		if (index_1 == -1 || index_2 == -1) {
			// This condition actually occurs on each sort
			// (apparently, the filter function is not taken into consideration when sorting):
			//warning(_("Attempting to sort entries that do not both contain the current command: '%s' and '%s'"),
			//		item_1.text, item_2.text);
			return 0;
		}

		// Prefer an entry that starts with the current command
		// to an entry that does not
		if (index_1 == 0 && index_2 > 0)
			return -1;
		if (index_2 == 0 && index_1 > 0)
			return 1;

		// Prefer the more frequently used entry
		if (item_1.uses != item_2.uses)
			return item_2.uses - item_1.uses;

		// Prefer the more recently used entry
		return item_2.last_used - item_1.last_used;
	}

	public void add_command(string command) {
		foreach (var entry in entries) {
			if (entry.text == command) {
				entry.uses++;
				entry.last_used = (int)Time.local(time_t()).mktime();
				return;
			}
		}

		// Command not found in entry list
		var entry = new AutocompletionEntry();
		entry.text = command;
		entry.uses = 1;
		entry.last_used = (int)Time.local(time_t()).mktime();
		entries.add(entry);
	}

	public bool is_command_selected() {
		return tree_view.has_selection ();
	}

	public string? get_selected_command() {
		if (is_command_selected ())
			return ((AutocompletionEntry)tree_view.get_selection ()).text;

		return null;
	}

	public void select_previous_command() {
		if (selected_index-1 > 0)
			select_entry(selected_index - 1);
	}

	public void select_next_command() {
		// Note that this will select the first entry
		// if selected_entry is -1 (as desired)
		if (selected_index+1 < tree_view.filtered_length)
			select_entry(selected_index + 1);
	}

	private void select_entry(int index) {
		selected_index = index;

		tree_view.select_item(index);
	}

	public void show_popup(string command) {
		this.current_command = command;

		// TODO: Resort and test
		// Force refilter + resort
		maximum_length = 0;
		tree_view.resort ();
		tree_view.refilter ();

		try {
			AutocompletionEntryView.highlight_pattern = new Regex(Regex.escape_string(command),
					RegexCompileFlags.CASELESS | RegexCompileFlags.OPTIMIZE);
		} catch (Error e) { error(_("Highlight regex compilation error: %s"), e.message); }

		if (tree_view.filtered_length == 0) {
			hide_popup();
			return;
		}

		tree_view.clear_selection();

		// Determine optimal size for popup window

		// TODO: Move values into constants / settings
		int width  = 50 + (int.min(40, maximum_length) * Settings.get_default().character_width);
		// TODO: If line breaking is required, the height determined here may be too low
		//       to show even a single match completely
		int height = int.min(8, tree_view.filtered_length+1) * Settings.get_default().character_height;
		popup_window.resize(width, height);
		tree_view.set_size_request(width, height);

		popup_window.show_all();
	}

	public void move_popup(int x, int y) {
		popup_window.move(x, y);
	}

	public void hide_popup() {
		popup_window.hide();
	}

	public bool is_popup_visible() {
		return popup_window.visible;
	}

	private class AutocompletionEntry : Object {

		public string text { get; set; }
		public int uses { get; set; }
		// TODO: This should be a long value (timestamp), but
		//       Json.gobject_from_data fails to load it properly
		public int last_used { get; set; }

	}

	private class AutocompletionEntryView : CellRenderer {
		public Object data { get; set; }

		public static Regex highlight_pattern;

		public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area,
			out int x_offset, out int y_offset, out int width, out int height)
		{
			x_offset = 0;
			y_offset = 0;
			Utilities.get_text_size(Settings.get_default().terminal_font,
				((AutocompletionEntry) data).text, out width, out height);
		}

		public override void render (Cairo.Context ctx, Gtk.Widget widget,
			Gdk.Rectangle background_area, Gdk.Rectangle cell_area,
			Gtk.CellRendererState flags)
		{
			var entry = (AutocompletionEntry) data;
			
			// TODO: Doesn't work?
			// var color = Settings.get_default().foreground_color;
			// ctx.set_source_rgb (color.red, color.green, color.blue);
			// ctx.rectangle(background_area.x, background_area.y,
			// 	background_area.width, background_area.height);

			var color = Settings.get_default().background_color;
			ctx.set_source_rgb (color.red, color.green, color.blue);
			ctx.move_to (cell_area.x, cell_area.y);
			
			var layout = Pango.cairo_create_layout(ctx);
			layout.set_font_description(Settings.get_default().terminal_font);

			if (highlight_pattern == null) {
				layout.set_text(entry.text, -1);
			} else {
				// Highlight text in entry:
				// Step 1: Place markers around text to be highlighted
				var markup = "";
				try {
					markup = highlight_pattern.replace(entry.text, -1, 0, "{$$$}\\0{/$$$}");
				} catch (Error e) { error(_("Highlight regex error: %s"), e.message); }
				// Step 2: Replace reserved characters with markup entities
				markup = Markup.escape_text(markup);
				// Step 3: Replace markers with highlighting markup tags
				markup = markup.replace("{$$$}", "<b>");
				markup = markup.replace("{/$$$}", "</b>");
				layout.set_markup (markup, markup.length);
			}

			Pango.cairo_show_layout (ctx, layout);
		}
	}
}
