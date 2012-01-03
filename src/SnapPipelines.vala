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
            
            Timeout.add (500, () => { pip.set_state (State.NULL);
                this.src.set_state (State.PLAYING);
                this.src.link (this.sink);
                play ();
                var xoverlay = this.sink as XOverlay;
                xoverlay.set_xwindow_id (Gdk.X11Window.get_xid (this.drawing_area.get_window ()));
            return false;});
        }
        
        public void take_video () {
            debug ("Taking a video...");
            
            this.src.set_state (State.NULL);
            this.sink.set_state (State.NULL);
            
            var pip = new Pipeline ("pip");
            var cb = ElementFactory.make ("camerabin", "c");
            pip.add_many (cb);
            pip.set_state (State.PLAYING);        
/*           
            var pip = new Pipeline ("pip");
            var v4l2 = ElementFactory.make ("v4l2src", "v");
            var vcaps = new Caps.simple ("video/x-raw-yuv,width=640,height=480,framerate=30/1", "c");
            var cfilt = ElementFactory.make ("capsfilter", "cf");
            cfilt.set_property ("caps", vcaps);
            var tee = ElementFactory.make ("tee", "t");
            tee.set_property ("name", "t_vid");
		    var queue = ElementFactory.make ("queue", "q");
		    var xv = ElementFactory.make ("xvimagesink", "x");
		    var tq = ElementFactory.make ("queue", "tq");
		    var videorate = ElementFactory.make ("videorate", "vi");
		    var vicaps = new Caps.simple ("video/x-raw-yuv,framerate=30/1", "c");
            var vifilt = ElementFactory.make ("capsfilter", "vifilt");
            vifilt.set_property ("caps", vicaps);
		    var theoraenc = ElementFactory.make ("theoraenc", "t");
		    var queue1 = ElementFactory.make ("queue", "q1");
		    var asrc = ElementFactory.make ("alsasrc", "asrc");
		    asrc.set_property ("device", "hw:1,0");
		    var acaps = new Caps.simple ("video/x-raw-yuv,framerate=30/1", "c");
            var afilt = ElementFactory.make ("capsfilter", "afilt");
            afilt.set_property ("caps", acaps);
            var queue2 = ElementFactory.make ("queue", "q2");
		    var audioconvert = ElementFactory.make ("audioconvert", "a");
		    var queue3 = ElementFactory.make ("queue", "q3");
		    var vorbisenc = ElementFactory.make ("vorbisenc", "vo");
		    var queue4 = ElementFactory.make ("queue", "q4");
		    var oggmux = ElementFactory.make ("oggmux", "o");
		    oggmux.set_property ("name", "mux");
		    var file = ElementFactory.make ("filesink", "file");
            file.set_property ("location", dir + "/foo.ogg");
            
            pip.add_many (v4l2, cfilt, tee, queue, xv, videorate, tq, vifilt, theoraenc, queue1, asrc, afilt, queue2, audioconvert, queue3, vorbisenc, queue4, oggmux, file);
            v4l2.link_many (cfilt, queue, xv);
            tee.link_many (tq, videorate, vifilt, theoraenc, queue1, oggmux, file);
            asrc.link_many (afilt, queue2, audioconvert, vorbisenc, queue4, oggmux);
            pip.set_state (State.PLAYING);           
          GLib.Process.spawn_command_line_async ("gst-launch oggmux name=mux ! filesink location=output.ogg { v4l2src ! tee name=t ! {queue ! ffmpegcolorspace ! theoraenc ! queue ! mux. }");  
*/
        }
        
        public void take_video_stop () {
        }
		
	}	
	
}