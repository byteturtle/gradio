/* This file is part of Gradio.
 *
 * Gradio is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Gradio is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Gradio.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Gd;

namespace Gradio{

	[GtkTemplate (ui = "/de/haecker-felix/gradio/ui/organize-collection-dialog.ui")]
	public class OrganizeCollectionDialog : Gtk.Window{

		[GtkChild] private Stack WindowStack;
		[GtkChild] private ListBox CollectionsListBox;
		[GtkChild] private Button DoneButton;
		[GtkChild] private Popover AddPopover;

		// second screen
		[GtkChild] private Entry AddEntry;
		[GtkChild] private Button AddButton;

		// first screen
		[GtkChild] private Entry NewEntry;
		[GtkChild] private Button NewButton;

		public OrganizeCollectionDialog(){
			CollectionsListBox.set_header_func(header_func);

			if(Library.collection_model.get_n_items() == 0)
				WindowStack.set_visible_child_name("empty");
			else
				WindowStack.set_visible_child_name("collections");

			connect_signals();
		}

		private void connect_signals(){
			NewEntry.notify["text"].connect(() => {
				string text = NewEntry.get_text();

				if(text.length > 2)
					NewButton.set_sensitive(true);
				else
					NewButton.set_sensitive(false);
			});

			AddEntry.notify["text"].connect(() => {
				string text = AddEntry.get_text();

				// Don't add a collection with a same name, so we check it, before you can click the "+" button.
				// The ID is not needful here, so just ""
				Collection coll = new Collection(text, "");

				if(text.length > 2 && !(Library.collection_model.contains_collection(coll)))
					AddButton.set_sensitive(true);
				else
					AddButton.set_sensitive(false);
			});

			CollectionsListBox.bind_model(Library.collection_model, (item) => {
				Collection coll = (Collection) item;
				Label label = new Label (coll.name);
				label.halign = Align.START;
				label.height_request = 44;
				label.margin_start = 12;
				return label;
			});

			CollectionsListBox.row_activated.connect(() => {
				DoneButton.set_sensitive(true);
			});
		}

		private void create_collection(string name){
			Collection c = new Collection(name, Random.int_range(1000000, 9999999).to_string()); 	// TODO: this should not be the right way to generate a id
			App.library.add_new_collection(c);
		}

		private void header_func(ListBoxRow row, ListBoxRow? row_before){
			if(row_before == null){
				row.set_header(null);
				return;
			}

			Gtk.Widget current = row.get_header();

			if(current == null){
				current = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
				current.show();
				row.set_header(current);
			}
		}

		[GtkCallback]
		private void NewButton_clicked(Button button){
			WindowStack.set_visible_child_name("collections");
			create_collection(NewEntry.get_text());
		}

		[GtkCallback]
		private void AddButton_clicked(Button button){
			create_collection(AddEntry.get_text());
			AddEntry.set_text("");
			AddPopover.hide();
		}

		[GtkCallback]
		private void CancelButton_clicked(Button button){
			this.destroy();
		}

		[GtkCallback]
		private void DoneButton_clicked(Button button){
			StationModel model = App.window.get_station_selection();
			App.window.disable_selection_mode();

			ListBoxRow row = CollectionsListBox.get_selected_row();
			Label label = (Label)row.get_child();

			string n = label.get_text();

			message("Adding station(s) to collection \""+n+"\"");
			string id = Library.collection_model.get_id_by_name(n);

			for(int i = 0; i < model.get_n_items(); i++){
				RadioStation station = (RadioStation)model.get_item(i);
				App.library.add_station_to_collection(id, station);

			}

			this.destroy();
		}
	}
}
