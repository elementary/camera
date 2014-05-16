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

        private Snap.SnapApp snap_app;

        public Gtk.ActionGroup main_actions;
        private Gtk.UIManager ui;        
        private const string UI_STRING = """
            <ui>
                <popup name="Actions">
                    <menuitem name="Quit" action="Quit"/>
                </popup>
            </ui>
        """;
        
        private Snap.Widgets.Camera camera;
        private Snap.Widgets.Gallery gallery;
        private Gtk.HeaderBar toolbar;
        private Gtk.Stack stack;
        private Granite.Widgets.ModeButton mode_button;
        private Gtk.Button take_button;
        private Gtk.Statusbar statusbar;

        public SnapWindow (Snap.SnapApp snap_app) {

            this.snap_app = snap_app;
            this.set_application (this.snap_app);
            
            this.title = "Snap";
            this.window_position = Gtk.WindowPosition.CENTER;
            this.icon_name = "snap-photobooth";
            this.set_size_request (640, 480);
            this.resizable = false;
            
            // Setup the actions
            main_actions = new Gtk.ActionGroup ("MainActionGroup"); /* Actions and UIManager */
            main_actions.set_translation_domain ("snap");
            main_actions.add_actions (main_entries, this);

            ui = new Gtk.UIManager ();

            try {
                ui.add_ui_from_string (UI_STRING, -1);
            }
            catch(Error e) {
                error ("Couldn't load the UI: %s", e.message);
            }

            Gtk.AccelGroup accel_group = ui.get_accel_group();
            add_accel_group (accel_group);

            ui.insert_action_group (main_actions, 0);
            ui.ensure_update ();
            
            // Init thumbnail providers
            var photo_path = File.new_for_path (Resources.get_media_dir (Widgets.Camera.ActionType.PHOTO));
            var video_path = File.new_for_path (Resources.get_media_dir (Widgets.Camera.ActionType.PHOTO));
            Resources.photo_thumb_provider = new Services.ThumbnailProvider (photo_path);
            Resources.video_thumb_provider = new Services.ThumbnailProvider (video_path);
            
            // Setup UI
            setup_window ();
        }
        
        void setup_window () {
            // Load used icons
            Resources.load_icons ();
            
            // Toolbar
            toolbar = new Gtk.HeaderBar ();
            toolbar.show_close_button = true;
            this.set_titlebar (toolbar);
            
            // Gallery button
            var gallery_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            gallery_button_box.set_spacing (4);
            gallery_button_box.set_layout (Gtk.ButtonBoxStyle.START);
            
            var gallery_button = new Gtk.ToggleButton.with_label (_("Gallery"));
            gallery_button.toggled.connect (() => {
                if (this.stack.get_visible_child () == this.camera) {
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
            mode_button.append (Resources.PHOTO_ICON_SYMBOLIC.render_image (Gtk.IconSize.SMALL_TOOLBAR));
            mode_button.append (Resources.VIDEO_ICON_SYMBOLIC.render_image (Gtk.IconSize.SMALL_TOOLBAR));

            toolbar.pack_end (mode_button);

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
            take_button.get_style_context ().add_class ("noundo"); // egtk's red button
            take_button.get_style_context ().add_class ("raised");
            take_button.clicked.connect (() => { 
                if (!this.camera.get_capturing ())
                    this.camera.take_start ();
                else
                    this.camera.take_stop (); 
            });
            
            var take_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            take_button_box.set_spacing (4);
            take_button_box.set_layout (Gtk.ButtonBoxStyle.START);
            take_button_box.pack_start (take_button, false, false, 0);

            // Make the take button wider
            take_button.set_size_request (54, -1);

            toolbar.set_custom_title (take_button_box);
            
            // Setup gallery widget
            this.gallery = new Snap.Widgets.Gallery ();
            
            // Setup preview area
            this.camera = new Snap.Widgets.Camera ();
            this.camera.capture_start.connect (() => {
                // Disable uneeded buttons
                gallery_button.sensitive = false;
                this.mode_button.sensitive = false;
            });
            this.camera.capture_end.connect (() => {
                // Enable extra buttons
                gallery_button.sensitive = true;
                this.mode_button.sensitive = true;
            });
            
            // Setup window main content area
            this.stack = new Gtk.Stack ();
            this.stack.transition_type = Gtk.StackTransitionType.SLIDE_UP_DOWN;
            this.stack.add_named (this.gallery, _("Gallery"));
            this.stack.add_named (this.camera, _("Camera"));
            this.stack.set_visible_child (this.camera); // Show camera on launch
            
            // Statusbar
            statusbar = new Gtk.Statusbar ();
            
            // Some signals
            mode_button.mode_changed.connect (on_mode_changed);
            this.key_press_event.connect (this.on_key_press_event);
            
            // Set camera mode by default
            mode_button.set_active (0);

            this.add (this.stack);
            this.show_all ();
            
        }
    
        private void on_mode_changed () {
            var type = (mode_button.selected == 0) ? 
                Snap.Widgets.Camera.ActionType.PHOTO : Snap.Widgets.Camera.ActionType.VIDEO; 
            
            this.camera.set_action_type (type);
        
            switch (type) {
                case Snap.Widgets.Camera.ActionType.PHOTO:
                    debug ("Photo mode");
                    take_button.set_image (Resources.PHOTO_ICON_SYMBOLIC.render_image_with_color (Gtk.IconSize.SMALL_TOOLBAR));
                break;
                case Snap.Widgets.Camera.ActionType.VIDEO:
                    debug ("Video mode");
                    take_button.set_image (Resources.VIDEO_ICON_SYMBOLIC.render_image_with_color (Gtk.IconSize.SMALL_TOOLBAR));
                break;
            }
        }
        
        private bool on_key_press_event (Gdk.EventKey ev) {
            // 32 is the ASCII value for spacebar
            if (ev.keyval == 32)
                this.take_button.clicked ();

            return false;
        }
        
        private void load_thumbnails () {
            Resources.photo_thumb_provider.parse_thumbs.begin ();
            Resources.video_thumb_provider.parse_thumbs.begin ();
        }
        
        private void show_gallery () {
            this.camera.stop ();
            this.stack.set_visible_child (this.gallery);
        }
        
        private void show_camera () {
            this.camera.play ();
            this.stack.set_visible_child (this.camera);
        }
        
        void action_quit () {
            this.destroy ();
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Quit", null,
          /* label, accelerator */       N_("Quit"), null,
          /* tooltip */                  N_("Quit"),
                                         action_quit }
        };
    }
}