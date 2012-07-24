// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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

/* TODO:
 * - Update statusbar
 */

namespace Snap {

    public class SnapWindow : Gtk.Window {

        public Snap.SnapApp snap_app;
        bool video_start = true;
        public Gtk.DrawingArea da;
        public Gtk.ActionGroup main_actions;
        Gtk.UIManager ui;

        public const string UI_STRING = """
            <ui>
                <popup name="Actions">
                    <menuitem name="Quit" action="Quit"/>
                </popup>

                <popup name="AppMenu">
                <menuitem action="Preferences" />
            </popup>
            </ui>
        """;

        Recorder recorder;

        Gtk.Toolbar toolbar;
        Granite.Widgets.ModeButton mode_button;
        Gtk.Button take_button;
        Snap.Widgets.MediaBin media_bin;
        Snap.Widgets.MediaViewer viewer;
        Gtk.Statusbar statusbar;
        Snap.Widgets.EffectPopOver effects_popover;
        Gtk.Button effects_button;

        public SnapWindow (Snap.SnapApp snap_app) {

            this.snap_app = snap_app;
            set_application (this.snap_app);

            this.title = "Snap";
            this.window_position = Gtk.WindowPosition.CENTER;
            this.resizable = true;

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

            // Load icon information
            Resources.load_icons ();

            setup_window ();
            
            recorder = new Recorder (media_bin);
            
            take_button.clicked.connect (() => on_record(mode_button, recorder));
        }

        void setup_window () {

            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            /**
             * Setup the toolbar
             */

            toolbar = new Gtk.Toolbar ();
            toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
            toolbar.set_icon_size (Gtk.IconSize.LARGE_TOOLBAR);
            toolbar.set_vexpand (false);
            toolbar.set_hexpand (true);
            toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);

            var effects_button = new Gtk.Button.with_label (_("Effects"));
            effects_button.get_style_context ().add_class ("raised");
            effects_button.margin_right = 12;
            effects_button.sensitive = false;

            var effects_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
    	    effects_button_box.set_layout (Gtk.ButtonBoxStyle.START);
            effects_button_box.margin_left = 6;
            effects_button_box.pack_start (effects_button, false, false, 0);

            var effects_button_bin = new Gtk.ToolItem ();
            effects_button_bin.add (effects_button_box);

            //toolbar.add (effects_button_bin);

            effects_button.clicked.connect ((effects_button) => show_effect_popover(effects_button));

            mode_button = new Granite.Widgets.ModeButton ();
            mode_button.valign = Gtk.Align.CENTER;
            mode_button.halign = Gtk.Align.CENTER;
            mode_button.append (Resources.PHOTO_ICON_SYMBOLIC.render_image(Gtk.IconSize.SMALL_TOOLBAR));
            mode_button.append (Resources.VIDEO_ICON_SYMBOLIC.render_image(Gtk.IconSize.SMALL_TOOLBAR));
            mode_button.mode_changed.connect (on_mode_changed);
            mode_button.set_active (0);

            var mode_tool = new Gtk.ToolItem ();
            mode_tool.add (mode_button);
            mode_tool.margin_left = 5;
            mode_tool.set_expand (false);

            toolbar.add (mode_tool);

            var spacer = new Gtk.ToolItem ();
            spacer.set_expand (true);

            toolbar.add (spacer);

            var take_button_style = new Gtk.CssProvider ();
            try {
                take_button_style.load_from_data (Resources.TAKE_BUTTON_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }

            take_button = new Gtk.Button ();
            take_button.get_style_context ().add_provider (take_button_style, Gtk.STYLE_PROVIDER_PRIORITY_THEME);
            take_button.get_style_context ().add_class ("take-button");
            take_button.get_style_context ().add_class ("noundo"); // egtk's red button
            take_button.get_style_context ().add_class ("raised");

            var take_button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            take_button_box.set_spacing (4);
    	    take_button_box.set_layout (Gtk.ButtonBoxStyle.START);
            take_button_box.pack_start (take_button, false, false, 0);

            // Make the take button wider
            take_button.set_size_request (54, -1);
            take_button.set_image (Resources.PHOTO_ICON_SYMBOLIC.render_image(Gtk.IconSize.SMALL_TOOLBAR));

            var take_tool = new Gtk.ToolItem ();
            take_tool.add (take_button_box);
            take_tool.set_expand (false);
            take_tool.margin_left = 7;
            take_button.set_relief (Gtk.ReliefStyle.NORMAL);

            toolbar.add (take_tool);

            spacer = new Gtk.ToolItem ();
            spacer.set_expand (true);

            spacer.margin_left = 0;
            spacer.margin_right = 0; // Value when using "Effects" button should be 72

            toolbar.add (spacer);

            var share_menu = new Gtk.Menu ();       
            var share_app_menu = new Granite.Widgets.ToolButtonWithMenu (Resources.EXPORT_ICON.render_image(Gtk.IconSize.LARGE_TOOLBAR), _("Share"), share_menu);
            share_app_menu.set_sensitive (false);
            toolbar.add (share_app_menu);

            //var menu = ui.get_widget ("ui/AppMenu") as Gtk.Menu;
            var app_menu = (this.get_application() as Granite.Application).create_appmenu (new Gtk.Menu ());
            app_menu.margin_right = 3;
            toolbar.add (app_menu);

            vbox.pack_start (toolbar, false, false, 0);

            // Setup preview area
            media_bin = new Snap.Widgets.MediaBin ();
            media_bin.set_size_request (500, 300);

            hbox.pack_start (media_bin, true, true, 12);
            vbox.pack_start (hbox, true, true, 12);

            // Setup the photo/video viewer
            var viewer_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            viewer = new Snap.Widgets.MediaViewer ();
            viewer.selection_changed.connect ((path, type) => {
                share_app_menu.set_sensitive (true);
                populate_with_contractor (share_menu, path, type);
            });
            
            viewer_box.margin_top = 6;
            viewer_box.margin_right = 12;
            viewer_box.margin_left = 12;
            viewer_box.pack_start (viewer, true, true, 0);

            statusbar = new Gtk.Statusbar ();
            statusbar.push (0, viewer.photos.to_string () + " "+_("photos and") + " " + viewer.videos.to_string () + " " + _("videos"));

            viewer_box.pack_start (statusbar, false, true, 0);

            vbox.pack_start (viewer_box, false, true, 0);

            add (vbox);
            show_all ();
        }

        void show_effect_popover (Gtk.Widget widget) {
                effects_popover = new Snap.Widgets.EffectPopOver ();
                effects_popover.togglebutton.toggled.connect (on_mirror_screen);
                effects_popover.move_to_widget (widget);
                effects_popover.show_all ();
	            effects_popover.run ();
                effects_popover.destroy ();
        }

        void on_record (Granite.Widgets.ModeButton mode_button, Recorder recorder) {
            if (mode_button.selected == 0) {
                recorder.media_saved.connect(() => on_media_saved (MediaType.PHOTO));
                recorder.start (MediaType.PHOTO);
            }
            else if (mode_button.selected == 1) {
                recorder.media_saved.connect(() => on_media_saved (MediaType.VIDEO));
                if (video_start) {
                    take_button.set_image (Resources.MEDIA_STOP_ICON_SYMBOLIC.render_image(Gtk.IconSize.MENU));
                    recorder.start (MediaType.VIDEO);
                    video_start = false;
                }
                else {
                    take_button.set_image (Resources.VIDEO_ICON_SYMBOLIC.render_image(Gtk.IconSize.MENU));
                    recorder.stop ();
                    video_start = true;
                }
            }
        }

        void populate_with_contractor (Gtk.Menu menu, string path, MediaType? media_type) {
            /**
             *  Free the menu
             */
            var list  = menu.get_children ();
            foreach (var item in list)           
                item.destroy ();
            
            /*
             * Add contracts for image files
             */
            if (media_type == MediaType.PHOTO || media_type == null) {
                foreach (var contract in Granite.Services.Contractor.get_contract("file://" + path, "image/*")) {
                    var menuitem = new Gtk.MenuItem.with_label (contract["Description"]);
                    string exec = contract["Exec"];
                    menuitem.activate.connect( () => {
                        try {
                            GLib.Process.spawn_command_line_async(exec);
                        } catch (SpawnError e) {
                            stderr.printf ("error spawn command line %s: %s", exec, e.message);
                        }
                    });
                    menu.append (menuitem);
                    menu.show_all ();
                }
            }
            
            /*
             * Add contracts for videos
             */ 
            if (media_type == MediaType.VIDEO || media_type == null) {
                foreach (var contract in Granite.Services.Contractor.get_contract ("file:///" + path, "video/*")) {
                    var menuitem = new Gtk.MenuItem.with_label (contract["Description"]);
                    string exec = contract["Exec"];
                    menuitem.activate.connect( () => {
                        try {
                            GLib.Process.spawn_command_line_async(exec);
                        } catch (SpawnError e) {
                            stderr.printf ("error spawn command line %s: %s", exec, e.message);
                        }
                    });
                    menu.append (menuitem);
                    menu.show_all ();
                }
            }
        }

        void on_mirror_screen () {
            // TODO : Implement this feature
        }

        void on_mode_changed (Gtk.Widget widget) {
            if (take_button == null)
                return;

            if (mode_button.selected == 0)
                take_button.set_image (Resources.PHOTO_ICON_SYMBOLIC.render_image(Gtk.IconSize.SMALL_TOOLBAR));
            else
                take_button.set_image (Resources.VIDEO_ICON_SYMBOLIC.render_image(Gtk.IconSize.SMALL_TOOLBAR));
        }
        
        protected override bool delete_event (Gdk.EventAny event) {

            action_quit ();
            return false;

        }

        void on_media_saved (MediaType mediatype) {
            warning("saved");
            viewer.update_items(mediatype);
            viewer.update_items(null);
        }

        void action_quit () {
            recorder.pipeline.stop ();
        }

        void action_preferences () {
            var dialog = new Snap.Dialogs.Preferences (_("Preferences"), this);
            dialog.run ();
            dialog.destroy ();
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Quit", Gtk.Stock.QUIT,
          /* label, accelerator */       N_("Quit"), null,
          /* tooltip */                  N_("Quit"),
                                         action_quit },
           { "Preferences", Gtk.Stock.PREFERENCES,
          /* label, accelerator */       N_("Preferences"), null,
          /* tooltip */                  N_("Change Scratch settings"),
                                         action_preferences }
        };
    }
}
