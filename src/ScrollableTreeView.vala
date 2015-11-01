using Gtk;

public class ScrollableTreeView<T> : ScrolledWindow {
	public delegate bool FilterFunction<G>(G item);
	public delegate int SortFunction<G>(G a, G b);

	public int filtered_length { private set; get; }

	private TreeView list;
	private Gtk.ListStore model;
	private Gtk.TreeModelFilter filter;

	private int _cell_height = -1;
	private int cell_height {
		get {
			if (_cell_height > 0) {
				return _cell_height;
			}

			int offset_x;
			int offset_y;
			int cell_width;
			var rectangle = Gdk.Rectangle ();
			var column = list.get_column (0);

			// Getting dimensions from TreeViewColumn
			column.cell_get_size(rectangle, out offset_x, out offset_y, 
				out cell_width, out _cell_height);

			return _cell_height;
		}
	}

	public ScrollableTreeView (NotifyingList<T> items, CellRenderer view) {
		model = new Gtk.ListStore (1, typeof(Object));
		filter = new TreeModelFilter (model, null);
		list = new TreeView.with_model (filter);
		list.headers_visible = false;
		add (list);
		list.insert_column_with_attributes (0, "Command", view, "data", 0);

		foreach (var item in items)
		{
			TreeIter iter;
			model.append (out iter);
			model.set_value (iter, 0, (Object) item);
		}

		items.item_inserted.connect((index, item) => {
			TreeIter iter;
			model.insert_with_values (out iter, index, 0, (Object) item, -1);
		});

		items.item_removed.connect((index, item) => {
			TreeIter iter;
			model.get_iter (out iter, new TreePath.from_indices (index, -1));
			model.remove (iter);
		});

		items.item_modified.connect ((index, item) => {
			TreeIter iter;
			var path = new TreePath.from_indices (index, -1);
			model.get_iter (out iter, path);
			model.row_changed(path, iter);
		});
	}

	public void set_sort_function<T>(SortFunction<T> sort_function) {
		model.set_sort_func(0, (model, iter_a, iter_b) => {
			Object a, b;
			model.get(iter_a, 0, out a, -1);
			model.get(iter_b, 0, out b, -1);
			return sort_function((T) a, (T) b);
		});
	}

	public void set_filter_function<T>(FilterFunction<T> filter_function) {
		_filtered_length = 0;
		filter.set_visible_func((model, iter) => {
			Object item;
			model.get(iter, 0, out item, -1);
			if (filter_function((T) item)) {
				_filtered_length++;
				return true;
			}

			return false;
		});
	}

	public void refilter ()
	{
		_filtered_length = 0;
		filter.refilter ();
	}

	public void resort ()
	{
		model.set_sort_column_id (0, SortType.DESCENDING);
	}

	public void select_item (int index)
	{
		list.get_selection ().select_path (new TreePath.from_indices (index, -1));
		vadjustment.value = cell_height * index;
	}

	public void clear_selection ()
	{
		list.get_selection ().unselect_all ();
		vadjustment.value = 0;
	}

	public Object get_selection ()
	{
		TreeModel model;
		TreeIter iter;
		Object val;
		list.get_selection ().get_selected (out model, out iter);
		model.get(iter, 0, out val, -1);
		return val;
	}

	public bool has_selection ()
	{
		return list.get_selection ().count_selected_rows () > 0;
	}

	public Object get_item (int index)
	{
		TreeIter iter;
		Object val;
		var path = filter.convert_path_to_child_path (
						new TreePath.from_indices (index, -1));
		model.get_iter (out iter, path);
		model.get(iter, 0, out val, -1);

		return val;
	}
}