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



namespace Gradio{

	public class StationProvider{

		public signal void finished();
		public signal void started();
		public signal void progress(double p);

		string address = "";
		string data = "";

		Json.Parser parser = new Json.Parser();
		StationModel model = null;

		private bool parser_thread_running = false;
		private Cancellable cancellable = new Cancellable();

		private int actual_id = 0;
		private int id = 0;


		public StationProvider(ref StationModel m) {
			model = m;
		}

		public void set_address(string a){
			id++;
			actual_id = id;

			// Wait for old thread to exit and reset cancellable
			cancellable.cancel();
			while(parser_thread_running){
				message("Cancelling earlier search...");
			}
			cancellable.reset();

			address = a;

			// Download the data and parse it
			message ("Downloading data from \"%s\" ...", address);

			Util.get_string_from_uri.begin(address, (obj, res) => {
				data = Util.get_string_from_uri.end(res);

				if(data != null && data != ""){
					message("Dowloaded data. Starting parsing...");

					model.clear();
					parse_data.begin (id);
				}
			});


		}

		private async void parse_data(int id){
			if(id != actual_id){
				return;
			}

			message ("Parsing data from \"%s\" ...", address);
			started();

			ThreadFunc<void*> run = () => {
				parser_thread_running = true;

				try{
					parser.load_from_data (data);
					var root = parser.get_root ();
					var radio_stations = root.get_array ();

					int items = (int)radio_stations.get_length();
					message("Items found: %i", items);

					for(int i = 0; i < items; i++){
						//Check if actual thread should be cancelled
						cancellable.set_error_if_cancelled ();

						double actual = i;
						double max = items-1;
						double p = actual/max;
						progress(p);

						message("Parsing station " + i.to_string() + "/" + (items-1).to_string() + ". " + (p*100).to_string() + " %");

						Thread.usleep(100000);

						var radio_station = radio_stations.get_element(i);
						var radio_station_data = radio_station.get_object ();

						var station = new RadioStation.from_json_data(radio_station_data);

						Idle.add(() => {
							model.add(station);
							return false;
						});
					}

				}catch(GLib.Error e){
					warning ("Aborted parsing! " + e.message);
					parser_thread_running = false;
				}

				parser_thread_running = false;
				Thread.exit (1.to_pointer ());
				return null;
			};

			new Thread<void*> ("parser_thread", run);

			yield;

			finished();
        	}

	}

}