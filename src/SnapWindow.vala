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

using Gtk;
using Granite.Widgets;

using Snap.Widgets;
using Resources;

namespace Snap {

    public class SnapWindow : Gtk.Window {

        public Snap.SnapApp snap_app;
        bool video_start = true;
        public DrawingArea da;
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
        ModeButton mode_button;
        Button take_button;
        MediaBin media_bin;
        MediaViewer viewer;
        Statusbar statusbar;
        PopOver effects_popover;

        public SnapWindow (Snap.SnapApp snap_app) {

            this.snap_app = snap_app;
            set_application (this.snap_app);

            this.title = "Snap";
            this.window_position = WindowPosition.CENTER;
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

            this.destroy.connect (action_quit);

            // Load icon information
            load_icons ();

            setup_window ();
            
            recorder = new Recorder (media_bin);
            
            take_button.clicked.connect (() => {

                if (mode_button.selected == 0) {
                    recorder.start (MediaType.PHOTO);
                }
                else if (mode_button.selected == 1) {
                    if (video_start) {
                        take_button.set_image (MEDIA_STOP_ICON_SYMBOLIC.render_image(IconSize.MENU));
                        recorder.start (MediaType.VIDEO);
                        video_start = false;
                    }
                    else {
                        take_button.set_image (VIDEO_ICON_SYMBOLIC.render_image(IconSize.MENU));
                        recorder.stop ();
                        video_start = true;
                    }
                }
            });
        }

        void setup_window () {

            var vbox = new Box (Orientation.VERTICAL, 0);
            var hbox = new Box (Orientation.HORIZONTAL, 0);

            // Setup toolbar
            toolbar = new Gtk.Toolbar ();

            toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
            toolbar.set_icon_size (IconSize.LARGE_TOOLBAR);
            toolbar.set_vexpand (false);
            toolbar.set_hexpand (true);

            toolbar.get_style_context ().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);

            var effects_button = new Button.with_label (_("Effects"));
            effects_button.get_style_context ().add_class ("raised");

            effects_button.margin_right = 12;

            var effects_button_box = new ButtonBox (Orientation.HORIZONTAL);
    	    effects_button_box.set_layout (ButtonBoxStyle.START);
            effects_button_box.margin_left = 6;

            effects_button_box.pack_start (effects_button, false, false, 0);

            var effects_button_bin = new ToolItem ();
            effects_button_bin.add (effects_button_box);

            var effects_popover_style = new Gtk.CssProvider ();
            try {
                effects_popover_style.load_from_data (EFFECTS_POPOVER_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }

            effects_popover = new PopOver ();
            effects_popover.get_style_context ().add_class ("snap-effects-popover");
            effects_popover.get_style_context ().add_provider (effects_popover_style,
                                                 STYLE_PROVIDER_PRIORITY_APPLICATION);

            toolbar.add (effects_button_bin);

            effects_button.clicked.connect ( () => {
                // Show effects popover
                effects_popover.move_to_widget (effects_button);
                effects_popover.show ();
            });

            this.mode_button = new ModeButton ();
            mode_button.valign = Gtk.Align.CENTER;
            mode_button.halign = Gtk.Align.CENTER;
            mode_button.append (PHOTO_ICON_SYMBOLIC.render_image(IconSize.SMALL_TOOLBAR));
            mode_button.append (VIDEO_ICON_SYMBOLIC.render_image(IconSize.SMALL_TOOLBAR));
            mode_button.mode_changed.connect (on_mode_changed);
            mode_button.set_active (0);
            var mode_tool = new ToolItem ();
            mode_tool.add (mode_button);
            mode_tool.set_expand (false);
            toolbar.add (mode_tool);

            var spacer = new ToolItem ();
            spacer.set_expand (true);
            toolbar.add (spacer);

            var take_button_style = new Gtk.CssProvider ();
            try {
                take_button_style.load_from_data (TAKE_BUTTON_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }

            take_button = new Button ();
            take_button.get_style_context ().add_provider (take_button_style, STYLE_PROVIDER_PRIORITY_THEME);
            take_button.get_style_context ().add_class ("take-button");
            take_button.get_style_context ().add_class ("noundo"); // egtk's red button
            take_button.get_style_context ().add_class ("raised");

            var take_button_box = new ButtonBox (Orientation.HORIZONTAL);
            take_button_box.set_spacing (4);
    	    take_button_box.set_layout (ButtonBoxStyle.START);

            take_button_box.pack_start (take_button, false, false, 0);

            // Make the take button wider
            take_button.set_size_request (54, -1);

            take_button.set_image (PHOTO_ICON_SYMBOLIC.render_image(IconSize.SMALL_TOOLBAR));
            var take_tool = new ToolItem ();
            take_tool.add (take_button_box);
            take_tool.set_expand (false);
            take_button.set_relief (ReliefStyle.NORMAL);

            toolbar.add (take_tool);

            spacer = new ToolItem ();
            spacer.set_expand (true);
            toolbar.add (spacer);
            spacer.margin_left = 0;
            spacer.margin_right = 72;

            var share_menu = new Gtk.Menu ();
            populate_with_contractor (share_menu);
            var share_app_menu = new ToolButtonWithMenu (EXPORT_ICON.render_image(IconSize.LARGE_TOOLBAR), "Share", share_menu);
            toolbar.add (share_app_menu);

            var menu = ui.get_widget ("ui/AppMenu") as Gtk.Menu;
            var app_menu = (this.get_application() as Granite.Application).create_appmenu (menu);
            app_menu.margin_right = 3;
            toolbar.add (app_menu);

            vbox.pack_start (toolbar, false, false, 0);

            // Setup preview area
            media_bin = new MediaBin ();
            media_bin.set_size_request (500, 300);

            hbox.pack_start (media_bin, true, true, 12);
            vbox.pack_start (hbox, true, true, 12);

            // Setup the photo/video viewer
            var viewer_box = new Box (Orientation.VERTICAL, 0);

            viewer = new MediaViewer ();

            viewer_box.margin_top = 6;
            viewer_box.margin_right = 12;
            viewer_box.margin_left = 12;
            viewer_box.pack_start (viewer, true, true, 0);

            statusbar = new Statusbar ();
            statusbar.push (0, "0 photos and 0 videos");

            viewer_box.pack_start (statusbar, false, true, 0);

            vbox.pack_start (viewer_box, false, true, 0);

            add (vbox);
            show_all ();
        }

        void populate_with_contractor (Gtk.Menu menu) {
            var list  = new List<Gtk.MenuItem>();

            foreach (var contract in Granite.Services.Contractor.get_contract("file://" + "", "image/*")) {
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
                list.append(menuitem);
            }

            foreach (var contract in Granite.Services.Contractor.get_contract ("file:///" + "", "video/*")) {
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
                list.append(menuitem);
            }

        }

        void on_mode_changed (Widget widget) {
            if (take_button == null)
                return;

            if (mode_button.selected == 0)
                take_button.set_image (PHOTO_ICON_SYMBOLIC.render_image(IconSize.SMALL_TOOLBAR));
            else
                take_button.set_image (VIDEO_ICON_SYMBOLIC.render_image(IconSize.SMALL_TOOLBAR));
        }

        void action_quit () {
            Gtk.main_quit ();
            recorder.pipeline.stop ();
        }

        void action_preferences () {
            var dialog = new Snap.Dialogs.Preferences (_("Preferences"), this);
            dialog.run ();
            dialog.destroy ();
        }

        static const Gtk.ActionEntry[] main_entries = {
           { "Quit", Gtk.Stock.QUIT,
          /* label, accelerator */       N_("Quit"), "<Control>q",
          /* tooltip */                  N_("Quit"),
                                         action_quit },
           { "Preferences", Gtk.Stock.PREFERENCES,
          /* label, accelerator */       N_("Preferences"), null,
          /* tooltip */                  N_("Change Scratch settings"),
                                         action_preferences }
        };
    }
}
