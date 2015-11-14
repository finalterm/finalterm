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

public class StatusBar : Box {
	private Terminal terminal;

	private Label left;
	private Label middle;
	private Label right;

	private string middle_separator = ":middle:";
	private string right_separator = ":right:";

	private Gee.List<string> dirstack;
	private Gtk.Menu menu;
	private string? cwd;

	public StatusBar(Terminal terminal) {
		get_style_context().add_class("status-bar");
		this.terminal = terminal;
		homogeneous = true;

		dirstack = new Gee.ArrayList<string>();
		menu = new Gtk.Menu ();
		menu.halign = Align.END;
		var button = new MenuButton ();
		pack_start(button, true, true);
		button.direction = ArrowType.UP;
		button.popup = menu;

		left = new Label ("");
		left.use_markup = true;
		left.halign = Align.START;
		button.add(left);

		middle = new Label ("");
		middle.use_markup = true;
		middle.halign = Align.CENTER;
		pack_start(middle, true, true);

		right = new Label ("");
		right.use_markup = true;
		right.halign = Align.END;
		pack_start(right, true, true);

		terminal.terminal_output.set_prompt.connect(render);
	}

	private void render (string prompt) {
		var cwd = terminal.get_cwd ();
		if (this.cwd != null && this.cwd != cwd) {
			var item = new Gtk.MenuItem.with_label(this.cwd);
			menu.add(item);
			var dir = this.cwd;
			item.activate.connect(() => terminal.send_text(dir));
			item.show_all();
			this.cwd = null;
		}

		if (cwd != "" && dirstack.index_of(cwd) == -1) {
			this.cwd = cwd;
			dirstack.add(cwd);
		}

		left.label = prompt[0:prompt.index_of(middle_separator)];
		middle.label = prompt[prompt.index_of(middle_separator)+middle_separator.length:prompt.index_of(right_separator)];
		right.label = prompt[prompt.index_of(right_separator)+right_separator.length:prompt.length];
	}
}