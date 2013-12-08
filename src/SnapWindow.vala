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

                <popup name="AppMenu">
                    <menuitem action="Preferences" />
                </popup>
            </ui>
        """;

        private Snap.Widgets.Camera camera;
        private Gtk.HeaderBar toolbar;
        private Granite.Widgets.ModeButton mode_button;
        private Gtk.Button take_button;
        private Gtk.Stack viewer_notebook;
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

            setup_window ();
        }
        
        void setup_window () {
            // Load used icons
            Resources.load_icons ();
            
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Toolbar
            toolbar = new Gtk.HeaderBar ();
            toolbar.show_close_button = true;
            this.set_titlebar (toolbar);

            mode_button = new Granite.Widgets.ModeButton ();
            mode_button.valign = Gtk.Align.CENTER;
            mode_button.halign = Gtk.Align.CENTER;
            mode_button.append (Resources.PHOTO_ICON_SYMBOLIC.render_image (Gtk.IconSize.SMALL_TOOLBAR));
            mode_button.append (Resources.VIDEO_ICON_SYMBOLIC.render_image (Gtk.IconSize.SMALL_TOOLBAR));

            toolbar.pack_start (mode_button);

            var take_button_style = new Gtk.CssProvider ();
            try {
                take_button_style.load_from_data (Resources.TAKE_BUTTON_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }

            take_button = new Gtk.Button ();
            take_button.get_style_context ().add_provider (take_button_style, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            take_button.get_style_context ().add_class ("take-button");
            take_button.get_style_context ().add_class ("noundo"); // egtk's red button
            take_button.get_style_context ().add_class ("raised");

            var take_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            take_button_box.set_spacing (4);
    	    take_button_box.set_layout (Gtk.ButtonBoxStyle.START);
            take_button_box.pack_start (take_button, false, false, 0);

            // Make the take button wider
            take_button.set_size_request (54, -1);

            toolbar.set_custom_title (take_button_box);

            //var share_menu = new Gtk.Menu ();       
            //var share_app_menu = new Granite.Widgets.ToolButtonWithMenu (Resources.EXPORT_ICON.render_image(Gtk.IconSize.LARGE_TOOLBAR), _("Share"), share_menu);
            //share_app_menu.set_sensitive (false);
            //toolbar.add (share_app_menu);

            var menu = ui.get_widget ("ui/AppMenu") as Gtk.Menu;
            var app_menu = (this.get_application() as Granite.Application).create_appmenu (menu);
            app_menu.margin_right = 3;
            toolbar.pack_end (app_menu);

            // Setup preview area
            this.camera = new Snap.Widgets.Camera ();
            
            vbox.pack_start (camera, true, true, 0);
            
            // Setup the photo/video viewer
            viewer_notebook = new Gtk.Stack ();
            
            var viewer_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            viewer_box.pack_start (viewer_notebook, true, true, 0);
            
            // Statusbar
            statusbar = new Gtk.Statusbar ();
            //statusbar.push (0, viewer.n_photo.to_string () + " " +_("photos and") + " " + viewer.n_video.to_string () + " " + _("videos"));

            //viewer_box.pack_start (statusbar, false, true, 0);

            //vbox.pack_start (viewer_box, false, true, 0);
            
            // Some signals
            mode_button.mode_changed.connect (on_mode_changed);
            mode_button.set_active (0);
            
            this. add (vbox);
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
    
        void action_quit () {
            this.destroy ();
        }

        void action_preferences () {
            //var dialog = new Snap.Dialogs.Preferences (_("Preferences"), this);
            //dialog.run ();
            //dialog.destroy ();
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Quit", null,
          /* label, accelerator */       N_("Quit"), null,
          /* tooltip */                  N_("Quit"),
                                         action_quit },
           { "Preferences", null,
          /* label, accelerator */       N_("Preferences"), null,
          /* tooltip */                  N_("Change Snap settings"),
                                         action_preferences }
        };
    }
}
