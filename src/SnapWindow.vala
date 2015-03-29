// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
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

namespace Snap {

    public class SnapWindow : Gtk.Window {
        private const string VIDEO_ICON_SYMBOLIC = "view-list-video-symbolic";
        private const string PHOTO_ICON_SYMBOLIC = "view-list-images-symbolic";
        private const string STOP_ICON_SYMBOLIC = "media-playback-stop-symbolic";

        private Snap.SnapApp snap_app;

        private Snap.Widgets.Camera camera;
        private Snap.Widgets.Gallery gallery;
        private Snap.Widgets.NoCamera no_camera;
        private Gtk.HeaderBar toolbar;
        private Gtk.Stack stack;
        private Granite.Widgets.ModeButton mode_button;
        private Gtk.Button take_button;
        private Gtk.ButtonBox gallery_button_box;
        private Gtk.ToggleButton gallery_button;
        private Gtk.Statusbar statusbar;
        private File photo_path;
        private File video_path;

        private bool camera_detected;
        private string camera_uri;

        public SnapWindow (Snap.SnapApp snap_app) {
            this.snap_app = snap_app;
            this.set_application (this.snap_app);

            this.title = "Snap";
            this.icon_name = "snap-photobooth";
            this.set_size_request (640, 480);

            // Get paths
            photo_path = File.new_for_path (Resources.get_media_dir (Widgets.Camera.ActionType.PHOTO));
            video_path = File.new_for_path (Resources.get_media_dir (Widgets.Camera.ActionType.VIDEO));

            // camera
            camera_uri = this.detect_camera ();
            camera_detected = camera_uri != "";

            // Setup the camera
            this.camera = new Snap.Widgets.Camera (camera_uri);

            // Calculate thumbnail sizes
            var thumb_width = (camera.video_width - 19) / 4 - 18; // 19 = scrollbar_width + 2 * margin; 4 = row-count; 18 = 2 * item_padding + column_spacing
            var thumb_height = (int)(((float)thumb_width / camera.video_width) * camera.video_height);

            // Init thumbnail providers
            Resources.photo_thumb_provider = new Services.ThumbnailProvider (photo_path, thumb_width, thumb_height);
            Resources.video_thumb_provider = new Services.ThumbnailProvider (video_path, thumb_width, thumb_height);

            // Setup UI
            setup_window ();

            // Set the window position
            this.window_position = Gtk.WindowPosition.CENTER;
        }

        void setup_window () {
            // Toolbar
            toolbar = new Gtk.HeaderBar ();
            toolbar.show_close_button = true;
            this.set_titlebar (toolbar);

            // Gallery button
            gallery_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            gallery_button_box.set_spacing (4);
            gallery_button_box.set_layout (Gtk.ButtonBoxStyle.START);

            gallery_button = new Gtk.ToggleButton.with_label (_("Gallery"));
            gallery_button.sensitive = gallery_files_exists ();
            gallery_button.toggled.connect (() => {
                if (this.stack.get_visible_child () != this.gallery) {
                    this.show_gallery ();
                    this.load_thumbnails ();
                }
                else {
                    this.show_camera ();
                }
            });
            gallery_button_box.pack_start (gallery_button, true, true, 0);

            toolbar.pack_start (gallery_button_box);

            // Mode switcher
            mode_button = new Granite.Widgets.ModeButton ();
            mode_button.valign = Gtk.Align.CENTER;
            mode_button.halign = Gtk.Align.CENTER;

            mode_button.append (load_toolbar_icon (PHOTO_ICON_SYMBOLIC));
            mode_button.append (load_toolbar_icon (VIDEO_ICON_SYMBOLIC));

            // Hide video mode until fixed https://bugs.launchpad.net/snap-elementary/+bug/1374072
            //toolbar.pack_end (mode_button);

            var take_button_style = new Gtk.CssProvider ();
            try {
                take_button_style.load_from_data (Resources.TAKE_BUTTON_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }

            // Take button
            take_button = new Gtk.Button ();
            take_button.get_style_context ().add_provider (take_button_style, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            take_button.get_style_context ().add_class ("take-button");
            take_button.get_style_context ().add_class ("destructive-action");
            take_button.get_style_context ().add_class ("raised");
            take_button.clicked.connect (() => {
                if (this.stack.get_visible_child () != this.camera) {
                    gallery_button.set_active (false);
                    return;
                }
                if (!this.camera.get_capturing ()) {
                    this.camera.take_start ();
                    if (this.camera.get_action_type() == Widgets.Camera.ActionType.VIDEO) {
                        set_take_button_icon (Snap.Widgets.Camera.ActionType.CAPTURING);
                    }

                } else {
                    this.camera.take_stop ();
                    if (this.camera.get_action_type() == Widgets.Camera.ActionType.VIDEO) {
                        set_take_button_icon (Snap.Widgets.Camera.ActionType.VIDEO);
                    }
                }
            });
            take_button.set_sensitive (camera_detected);

            var take_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            take_button_box.set_spacing (4);
            take_button_box.set_layout (Gtk.ButtonBoxStyle.START);
            take_button_box.pack_start (take_button, false, false, 0);

            // Make the take button wider
            take_button.set_size_request (54, -1);

            toolbar.set_custom_title (take_button_box);

            // Setup NoCamera widget
            this.no_camera = new Snap.Widgets.NoCamera ();

            // Setup gallery widget
            this.gallery = new Snap.Widgets.Gallery ();

            // Setup preview area
            this.camera.capture_start.connect (() => {
                // Disable uneeded buttons
                gallery_button.sensitive = false;
                this.mode_button.sensitive = false;
                this.set_take_button_icon (Snap.Widgets.Camera.ActionType.CAPTURING);
            });
            this.camera.capture_stop.connect (() => {
                // Enable extra buttons
                gallery_button.sensitive = gallery_files_exists ();
                this.mode_button.sensitive = true;
                this.set_take_button_icon (this.camera.get_action_type ());
            });

            // Setup window main content area
            this.stack = new Gtk.Stack ();
            this.stack.transition_type = Gtk.StackTransitionType.SLIDE_UP_DOWN;
            this.stack.add_named (this.gallery, "Gallery");
            this.stack.add_named (this.camera, "Camera");
            this.stack.add_named (this.no_camera, "NoCamera");
            if (camera_detected)
                this.stack.set_visible_child (this.camera); // Show camera on launch
            else
                this.stack.set_visible_child (this.no_camera); // Show no_camera on launch

            // Statusbar
            statusbar = new Gtk.Statusbar ();

            // Some signals
            mode_button.mode_changed.connect (on_mode_changed);
            this.key_press_event.connect (this.on_key_press_event);

            mode_button.set_active (Snap.settings.mode);

            this.add (this.stack);
            this.show_all ();
        }

        private string detect_camera () {
            try {
                var video_devices = File.new_for_path ("/dev/.");
                FileEnumerator enumerator = video_devices.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileInfo info;
                while ((info = enumerator.next_file (null)) != null) {
                    if (info.get_name ().has_prefix ("video")){
                        debug ("camera found: %s", info.get_name ());
                        return "v4l2:///dev/%s".printf (info.get_name ());
                    }
                }
            } catch (Error err) {
                debug ("camera detection failed: %s", err.message);
            }

            debug ("no camera");
            return "";
        }

        protected override bool delete_event (Gdk.EventAny event) {
            Resources.photo_thumb_provider.clear_cache ();
            Resources.video_thumb_provider.clear_cache ();
            return false;
        }

        private void on_mode_changed () {
            var type = (mode_button.selected == 0) ?
                Snap.Widgets.Camera.ActionType.PHOTO : Snap.Widgets.Camera.ActionType.VIDEO;

            Snap.settings.mode = type;

            this.camera.set_action_type (type);
            this.set_take_button_icon (type);
        }

        private void set_take_button_icon (Snap.Widgets.Camera.ActionType? type) {
            string icon_name;

            if (type == Snap.Widgets.Camera.ActionType.PHOTO)
                icon_name = PHOTO_ICON_SYMBOLIC;
            else if (type == Snap.Widgets.Camera.ActionType.VIDEO)
                icon_name = VIDEO_ICON_SYMBOLIC;
            else if (type == Snap.Widgets.Camera.ActionType.CAPTURING)
                icon_name = STOP_ICON_SYMBOLIC;
            else
                assert_not_reached();

            take_button.set_image (load_toolbar_icon (icon_name));
        }

        private Gtk.Image load_toolbar_icon (string icon_name) {
            var icon = new ThemedIcon.with_default_fallbacks (icon_name);
            return new Gtk.Image.from_gicon (icon, Gtk.IconSize.SMALL_TOOLBAR);
        }

        private bool on_key_press_event (Gdk.EventKey ev) {
            // 32 is the ASCII value for spacebar
            if (ev.keyval == 32)
                this.take_button.clicked ();

            return false;
        }

        private void lock_camera_actions () {
            this.mode_button.set_sensitive (false);
        }

        private void unlock_camera_actions () {
            this.mode_button.set_sensitive (true);
        }

        private void load_thumbnails () {
            this.gallery.clear_view ();
            Resources.photo_thumb_provider.parse_thumbs.begin ();
            Resources.video_thumb_provider.parse_thumbs.begin ();
        }

        private void show_gallery () {
            if (camera_detected) {
                this.camera.stop ();
            }
            this.lock_camera_actions ();
            this.stack.set_visible_child (this.gallery);
        }

        private void show_camera () {
            if (camera_detected) {
                this.stack.set_visible_child (this.camera); // Show camera on launch
                this.camera.play ();
                this.unlock_camera_actions ();
            }
            else {
                this.stack.set_visible_child (this.no_camera); // Show no_camera on launch
            }
        }

        private bool gallery_files_exists () {
            FileInfo file_info;

            try {
                FileEnumerator enumerator_photo = photo_path.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileEnumerator enumerator_video = video_path.enumerate_children (FileAttribute.STANDARD_NAME, 0);

                if ((file_info = enumerator_photo.next_file ()) != null ||
                    (file_info = enumerator_video.next_file ()) != null) {
                    // Gallery is not empty
                    return true;
                }
            } catch (Error perr) {
                    warning ("Error: check_gallery_files photo failed: %s", perr.message);
            }

            // Gallery is empty, button may be disabled
            return false;
        }
    }
}
