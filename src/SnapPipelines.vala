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
	
	public class SnapPipelines : GLib.Object {
		
		// Path to save photos and videos
		string dir = GLib.Environment.get_home_dir () + "/Snap";
		
		// Main elements
		DrawingArea drawing_area;	
        Element camerabin;
		
		public SnapPipelines (Gtk.DrawingArea area) {

		    this.drawing_area = area;
		    
		    // Create Snap dir
		    GLib.DirUtils.create (dir, 0755);
		    
		    // Main elements to show the webcam stream
		    this.camerabin = ElementFactory.make ("camerabin", "video");


		    var bus = this.camerabin.get_bus ();
            bus.set_sync_handler (on_bus_callback);
               
        }
        
        Gst.BusSyncReply on_bus_callback (Gst.Bus bus, Gst.Message message) {
            if (message.get_structure () != null && message.get_structure().has_name("prepare-xwindow-id")) {
                var xoverlay = message.src as XOverlay;
                xoverlay.set_xwindow_id (Gdk.X11Window.get_xid (this.drawing_area.get_window ()));
                return Gst.BusSyncReply.DROP;
            }
            return Gst.BusSyncReply.PASS;
        }
		
		public void switch_mode (int mode) {
		    this.camerabin.set_property ("mode", mode);
		}
		
		public void play () {
            this.camerabin.set_state (State.PLAYING);
        }
        
        public void pause () {
            this.camerabin.set_state (State.PAUSED);
        }
        
        public void stop () {
            this.camerabin.set_state (State.NULL);
        }
        
        public void take_photo () {
		    debug ("Taking a photo...");
            
            int n = 0;
            string filename = null;
            
            while (true) { 
                filename = dir + "/Snap_picture_" + n.to_string () + ".jpg";
                if (FileUtils.test (filename, FileTest.EXISTS)) n++;
                else break;
            }
            debug ("%s", filename);
            camerabin.set_property ("filename", filename);
            GLib.Signal.emit_by_name (camerabin, "capture-start");

        }
        
        public void take_video () {
            debug ("Taking a video...");
            
            int n = 0;
            string filename = null;
            
            while (true) { 
                filename = dir + "/Snap_video_" + n.to_string () + ".ogg";
                if (FileUtils.test (filename, FileTest.EXISTS)) n++;
                else break;
            }
            
            camerabin.set_property ("filename", filename);
            GLib.Signal.emit_by_name (camerabin, "capture-start");
            
        }
        
        public void take_video_stop () {
            debug ("Video taking finish...");            
            
            GLib.Signal.emit_by_name (camerabin, "capture-start");
            
        }
		
	}	
	
}