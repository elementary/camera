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

using Snap.Widgets;

namespace Snap {
	
	public class SnapWindow : Gtk.Window {
		
		private const string TITLE = "Snap";
		public Snap.SnapApp snap_app;
		
		//widgets
		DrawingArea drawing_area;	
        SnapToolbar toolbar;
        SnapStatic staticn;
        SnapStatusbar statusbar;
        
        //gst objects
	    Pipeline pipeline;
        Element src;
        Element sink;
		
		public SnapWindow (Snap.SnapApp snap_app) {
		    
		    this.snap_app = snap_app;
		    set_application (this.snap_app);
		    
		    this.title = TITLE;
		    
		    setup_window ();
		    setup_gst_pipeline ();
		    
		    on_play ();
		        
		}
		
		void setup_window () {
		    
		    var vbox = new Box (Orientation.VERTICAL, 0);
		    var hbox = new Box (Orientation.HORIZONTAL, 0);
		    
		    toolbar = new SnapToolbar (this);
		    vbox.pack_start (toolbar, false, false, 0);
		    
		    drawing_area = new DrawingArea ();
		    drawing_area.set_size_request (450, 250);
		    hbox.pack_start (drawing_area, true, true, 30);
		    vbox.pack_start (hbox, true, true, 30);
            
            staticn = new SnapStatic ();
            vbox.pack_start (staticn, false, true, 0);
            
            statusbar = new SnapStatusbar ();
            vbox.pack_start (statusbar, false, false, 0);
            
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