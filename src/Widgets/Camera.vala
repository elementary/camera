// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as
  published    by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses>

  END LICENSE
***/

namespace Snap.Widgets {
    public class Camera : Gtk.DrawingArea {
        public enum ActionType {
            PHOTO = 0,
            VIDEO,
            CAPTURING;
        }

        public uint video_width = 640;
        public uint video_height = 480;

        private ActionType type;

        private bool capturing = false;

        private Gst.Element? camerabin = null;
        private Gst.Element? videoflip = null;

        public signal void capture_start ();
        public signal void capture_stop ();

        public class Camera (string camera_uri) {
            this.videoflip = Gst.ElementFactory.make ("videoflip", "videoflip");
            this.videoflip.set_property ("method", 4);

            this.camerabin = Gst.ElementFactory.make ("camerabin","camera");
            this.camerabin.set_property ("viewfinder-filter", videoflip);

            this.camerabin.bus.add_watch (0,(bus,message) => {
                if (Gst.Video.is_video_overlay_prepare_window_handle_message (message))
                    (message.src as Gst.Video.Overlay).set_window_handle ((uint*) Gdk.X11Window.get_xid (this.get_window()));
                return true;
            });

            var preview_caps = Gst.Caps.from_string ("video/x-raw, format=\"rgb\"");
            this.camerabin.set_property ("preview-caps", preview_caps);

            // Workaround to fix a CSD releated bug.
            // See https://bugzilla.gnome.org/show_bug.cgi?id=721148
            // for more information
            Gdk.Visual visual = Gdk.Visual.get_system ();
            if (visual != null)
                this.set_visual (visual);
            // workaround END

            try {
                var info = new Gst.PbUtils.Discoverer (10 * Gst.SECOND).discover_uri (camera_uri);
                var video = info.get_video_streams ();

                if (video != null && video.data != null) {
                    var video_info = (Gst.PbUtils.DiscovererVideoInfo)video.data;

                    video_width = video_info.get_width ();
                    video_height = video_info.get_height ();
                }

                var current_screen = this.get_screen ();
                var screen_width = current_screen.get_width ();
                var screen_height = current_screen.get_height ();

                if (video_width >= screen_width * 0.8 || video_height >= screen_height * 0.8) {
                    if ((float)screen_width / video_width < (float)screen_height / video_height) {
                        var new_video_width = (int)(screen_width * 0.8);
                        video_height = (int)(((float)new_video_width / video_width) * video_height);
                        video_width = new_video_width;
                    } else {
                        var new_video_height = (int)(screen_height * 0.8);
                        video_width = (int)(((float)new_video_height / video_height) * video_width);
                        video_height = new_video_height;
                    }
                }
            } catch (Error e) {
                debug ("Getting the video-size failed: %s", e.message);
            }

            this.set_size_request ((int)video_width, (int)video_height);
            this.show_all ();
            this.play ();
        }

        /**
         * Change the camera recording type (switch between Video or Photo mode)
         */
        public void set_action_type (ActionType type) {
            debug ("mode changed");
            this.type = type;
        }

        /**
         * Starts Camera visualization
         */
        public void play () {
            this.camerabin.set_state (Gst.State.PLAYING);
        }

        /**
         * Stops Camera visualization
         */
        public void stop () {
            this.camerabin.set_state (Gst.State.NULL);
        }

        /**
         * Send to the Camera an acquire signal depending on its recording mode
         */
        public void take_start () {
            debug ("Recording...");

            this.capture_start ();

            string location = Resources.get_new_media_filename (this.type);
            // "(int) this.type + 1" is here because GST developers used mode 1 for photos
            // and mode 2 for videos (can't understand why not 0 and 1)
            this.camerabin.set_property ("mode", (int) this.type + 1);

            this.capturing = (this.type == ActionType.VIDEO);

            debug ("%s", location);

            camerabin.set_property ("location", location);
            GLib.Signal.emit_by_name (camerabin, "start-capture");

            if (this.type == ActionType.PHOTO)
                this.capture_stop ();
        }

        /**
         * Tells the camera to stop recording (to be used only in video mode)
         */
        public void take_stop () {
            debug ("Stopping video record...");

            this.capturing = false;

            GLib.Signal.emit_by_name (camerabin, "stop-capture");

            this.capture_stop ();
        }

        /**
         * @return the action Camera is supposed to do
         */
        public ActionType get_action_type () {
            return type;
        }

        /**
         * @return true if camera is recording a video, false otherwise
         */
        public bool get_capturing () {
            return capturing;
        }
    }
}
