// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com>
  This program is free software: you can redistribute it and/or modify it	
  under the terms of the GNU Lesser General Public License version 3, as
  published	by the Free Software Foundation.
	
  This program is distributed in the hope that it will be useful, but	
  WITHOUT ANY WARRANTY; without even the implied warranties of	
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR	
  PURPOSE.  See the GNU General Public License for more details.
	
  You should have received a copy of the GNU General Public License along	
  with this program.  If not, see <http://www.gnu.org/licenses>
  
  END LICENSE	
***/

using Gtk;
using Gst;

namespace Snap {
	
	public class SnapWindow : Gtk.Window {
		
		private const string TITLE = "Snap";
		public Snap.SnapApp snap_app;
		
		//widgets and instruments for windo and gstreamer
		DrawingArea drawing_area;	

	    Pipeline pipeline;
        Element src;
        Element sink;
		
		public SnapWindow (Snap.SnapApp snap_app) {
		    
		    this.snap_app = snap_app;
		    set_application (this.snap_app);
		    
		    this.title = TITLE;
		    
		    setup_window ();
		    setup_gst_pipeline ();
		        
		}
		
		void setup_window () {
		
			var vbox = new Box (Orientation.VERTICAL, 0);
		    this.drawing_area = new DrawingArea ();
		    this.drawing_area.set_size_request (450, 250);
		    vbox.pack_start (this.drawing_area, true, true, 0);

		    var play_button = new Button.from_stock (Stock.MEDIA_PLAY);
		    play_button.clicked.connect (on_play);
		    var stop_button = new Button.from_stock (Stock.MEDIA_STOP);
		    stop_button.clicked.connect (on_stop);
		    var quit_button = new Button.from_stock (Stock.QUIT);
		    quit_button.clicked.connect (Gtk.main_quit);

		    var bb = new ButtonBox (Orientation.HORIZONTAL);
		    bb.add (play_button);
		    bb.add (stop_button);
		    bb.add (quit_button);
		    vbox.pack_start (bb, false, true, 0);

		    add (vbox);
		    
		    show_all ();
		
		}
		
		private void on_play () {
            var xoverlay = this.sink as XOverlay;
            xoverlay.set_xwindow_id (Gdk.X11Window.get_xid (this.drawing_area.get_window ()));
            this.pipeline.set_state (State.PLAYING);
        }

        private void on_stop () {
            this.pipeline.set_state (State.READY);
        }
	
	    void setup_gst_pipeline () {
            this.pipeline = new Pipeline ("mypipeline");
		    this.src = ElementFactory.make ("v4l2src", "video");
            this.sink = ElementFactory.make ("xvimagesink", "sink");
            this.pipeline.add_many (this.src, this.sink);
            this.src.link (this.sink);
        }	
		
	}	
	
}