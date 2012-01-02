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
		Pipeline pipeline;
        Element src;
        Element sink;
		
		public SnapPipelines (Gtk.DrawingArea area) {

		    this.drawing_area = area;
		    
		    // Create Snap dir
		    GLib.DirUtils.create (dir, 0755);
		    
		    // Main elements to show the webcam stream
		    this.pipeline = new Pipeline ("snap-pipeline");
		    this.src = ElementFactory.make ("v4l2src", "video");
            this.sink = ElementFactory.make ("xvimagesink", "sink");
            this.pipeline.add_many (this.src, this.sink);
            this.src.link (this.sink);

		    var bus = this.pipeline.get_bus ();
            bus.set_sync_handler (on_bus_callback);
               
        }
        
        Gst.BusSyncReply on_bus_callback (Gst.Bus bus, Gst.Message message) {
            if (message.get_structure () != null && message.get_structure().has_name("prepare-xwindow-id")) {
                var xoverlay = this.sink as XOverlay;
                xoverlay.set_xwindow_id (Gdk.X11Window.get_xid (this.drawing_area.get_window ()));
                return Gst.BusSyncReply.DROP;
            }
            return Gst.BusSyncReply.PASS;
        }
		
		public void play () {
            this.pipeline.set_state (State.PLAYING);
        }

        public void stop () {
            this.pipeline.set_state (State.READY);
        }
        
        public void take_photo () {
		    debug ("Taking a photo...");

            this.src.set_state (State.NULL);

            var pip = new Pipeline ("pip");
            var v4l2 = ElementFactory.make ("v4l2src", "v");
            var ffmpeg = ElementFactory.make ("ffmpegcolorspace", "ffmpeg");
            var png = ElementFactory.make ("pngenc", "png");
            var file = ElementFactory.make ("filesink", "file");
            file.set_property ("location", dir + "/foo.png");
            pip.add_many (v4l2, ffmpeg, png, file);
            v4l2.link_many (ffmpeg, png, file);
            pip.set_state (State.PLAYING);
            
            //this.src.set_state (State.PLAYING);
            //play ();

        }
        
        public void take_video () {
            debug ("Taking a video...");
            
            this.src.set_state (State.NULL);

            var pip = new Pipeline ("pip");
            var v4l2 = ElementFactory.make ("v4l2src", "v");
            var tee = ElementFactory.make ("tee", "t");
		    var queue = ElementFactory.make ("queue", "q");
		    var videorate = ElementFactory.make ("videorate", "vi");
		    var theoraenc = ElementFactory.make ("theoraenc", "t");
		    var audioconvert = ElementFactory.make ("audioconvert", "a");
		    var vorbisenc = ElementFactory.make ("vorbisenc", "vo");
		    var oggmux = ElementFactory.make ("oggmux", "o");
		    var file = ElementFactory.make ("filesink", "file");
            file.set_property ("location", dir + "/foo.ogg");
            
            pip.add_many (v4l2, tee, queue, videorate, theoraenc, audioconvert, vorbisenc, oggmux, file);
            
        }
        
        public void take_video_stop () {
        }
		
	}	
	
}