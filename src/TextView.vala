/*
 * Copyright © 2013–2014 Philipp Emanuel Weidmann <pew@worldwidemann.com>
 * Copyright © 2015-2016 RedHatter <timothy@idioticdev.com>
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
using Pango;

/**
 *  Custom TextView to draw double-wide and double-high text.
 */
public class TextView : Gtk.TextView {
	public TextView.with_buffer (TextBuffer buffer) {
		set_buffer(buffer);
		editable = false;
		cursor_visible = false;
		wrap_mode = Gtk.WrapMode.CHAR;
	}

	public override void draw_layer (TextViewLayer layer, Cairo.Context cr) {
		// Draw after text has been rendered
		if (layer != TextViewLayer.BELOW)
			return;

		//TODO: Cache layout
		var line = create_pango_layout(null);
		TextIter iter;

		// For each of the three types obtain the text using
		// forward_to_tag_toggle, apply line styles, set clip, and draw with
		// Cairo transforms

		// Double-wide: scale x by a factor of 2
		buffer.get_iter_at_line(out iter, 0);
		var tag = buffer.tag_table.lookup("double-wide");
		if (tag != null) {
			while (next_segment(cr, tag, ref iter, line)) {
				cr.scale(2.0, 1.0);
				Pango.cairo_show_layout(cr, line);
				cr.scale(0.5, 1.0);
			}
		}

		// Double-high top half: scale both x and y by a factor of 2
		buffer.get_iter_at_line(out iter, 0);
		tag = buffer.tag_table.lookup("double-top");
		if (tag != null) {
			while (next_segment(cr, tag, ref iter, line)) {
				cr.scale(2.0, 2.0);
				Pango.cairo_show_layout(cr, line);
				cr.scale(0.5, 0.5);
			}
		}

		// Double-high bottom half: scale both x and y by a factor of 2 and
		// shift y up one line
		buffer.get_iter_at_line(out iter, 0);
		tag = buffer.tag_table.lookup("double-bottom");
		if (tag != null) {
			while (next_segment(cr, tag, ref iter, line)) {
				int line_height;
				get_line_yrange (iter, null, out line_height);
				cr.rel_move_to(0, -line_height);
				cr.scale(2.0, 2.0);
				Pango.cairo_show_layout(cr, line);
				cr.scale(0.5, 0.5);
			}
		}
	}

	private bool next_segment (Cairo.Context cr, TextTag tag, ref TextIter iter, Pango.Layout line) {
		if (!iter.forward_to_tag_toggle(tag))
			return false; // No more segments

		var start = iter;
		iter.forward_to_tag_toggle(tag);

		// Extract text
		var text = buffer.get_text(start, iter, true);
		line.set_text(text, -1);

		// TODO: Set all attribues from tags

		// Set color attribute
		var color = get_default_attributes().appearance.fg_color;
		var attr = Pango.attr_foreground_new(color.red, color.green, color.blue);
		attr.start_index = 0;
		attr.end_index = text.length;
		var attr_list = new AttrList();
		attr_list.change((owned) attr);
		line.set_attributes(attr_list);

		// Get position shifted by scroll
		Gdk.Rectangle pos_rect;
		get_cursor_locations(iter, out pos_rect, null);
		pos_rect.y -= (int) get_vadjustment().value;
		pos_rect.x -= (int) get_hadjustment().value;

		// clip and move Cairo
		int height;
		line.get_pixel_size(null, out height);
		cr.reset_clip();
		cr.rectangle(pos_rect.x, pos_rect.y, get_allocated_width(), height);
		cr.clip();
		cr.move_to(pos_rect.x, pos_rect.y);

		return true;
	}
}
