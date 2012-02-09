// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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
using Granite.Widgets;

using Snap.Widgets;

namespace Snap {
	
	public class SnapWindow : Gtk.Window {
		
		private const string TITLE = "Snap";
		public Snap.SnapApp snap_app;
		bool video_start = true;
		
		const string ui_string = """
            <ui>
            <popup name="Actions">
                <menuitem name="Quit" action="Quit"/>
            </popup>

            <popup name="AppMenu">
                <menuitem action="Preferences" />
            </popup>
            </ui>
        """;

        public Gtk.ActionGroup main_actions;
        Gtk.UIManager ui;
		
		//widgets
		public DrawingArea drawing_area;	
        Gtk.Toolbar toolbar;
        ModeButton mode_button;
        Button take_button;
        MediaViewer viewer;
        Statusbar statusbar;
        
        // CSS styling
        Gtk.StyleContext context;
        Gtk.CssProvider css;
        
        //gst objects
        public Pipelines pipeline;
		
		public SnapWindow (Snap.SnapApp snap_app) {
		    
		    this.snap_app = snap_app;
		    set_application (this.snap_app);
		    
		    this.title = TITLE;
		    this.window_position = WindowPosition.CENTER;
		    this.resizable = false;
		    
		    // Setup the actions
		    main_actions = new Gtk.ActionGroup ("MainActionGroup"); /* Actions and UIManager */
            main_actions.set_translation_domain ("snap");
            main_actions.add_actions (main_entries, this);
            
            ui = new Gtk.UIManager ();

            try {
                ui.add_ui_from_string (ui_string, -1);
            }
            catch(Error e) {
                error ("Couldn't load the UI: %s", e.message);
            }

            Gtk.AccelGroup accel_group = ui.get_accel_group();
            add_accel_group (accel_group);

            ui.insert_action_group (main_actions, 0);
            ui.ensure_update ();
		    
		    this.destroy.connect (action_quit);
		    
		    css = new Gtk.CssProvider ();
            try {
                css.load_from_path (Constants.DATADIR + "/snap/Snap.css"); 
            } catch (Error e) {
                warning ("%s", e.message);
            }
            context = new Gtk.StyleContext ();
            context.add_provider_for_screen (get_screen (), css, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		    
		    setup_window ();
		    setup_pipeline ();
            
            take_button.clicked.connect (() => {
                var count = new Snap.Widgets.Countdown (this, pipeline);
                
                if (mode_button.selected == 0) { 
                    count.start (CountdownAction.PHOTO);
                }
                
                else if (mode_button.selected == 1) { 
                    if (video_start) {
                        take_button.set_image (new Gtk.Image.from_icon_name ("media-playback-stop-symbolic", IconSize.BUTTON));
                        count.start (CountdownAction.VIDEO);
                        video_start = false;
                    }
                    else {
                        take_button.set_image (new Gtk.Image.from_icon_name ("camera-video-symbolic", IconSize.BUTTON));
                        count.destroy ();
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
  		    toolbar.get_style_context ().add_class ("primary-toolbar");
	        
	        var effects_button = new Button.with_label (_("Effects"));
	        effects_button.set_sensitive (false);
		    var effects_tool = new ToolItem ();
		    effects_tool.add (effects_button);
		    effects_tool.set_expand (false);
		    effects_button.set_relief (ReliefStyle.NORMAL);
		    toolbar.add (effects_tool);        
	        	    
		    this.mode_button = new ModeButton ();
            mode_button.valign = Gtk.Align.CENTER;
            mode_button.halign = Gtk.Align.CENTER;
            mode_button.append(new Gtk.Image.from_icon_name ("camera-photo-symbolic", IconSize.BUTTON));
            mode_button.append(new Gtk.Image.from_icon_name ("camera-video-symbolic", IconSize.BUTTON));
            mode_button.mode_changed.connect (on_mode_changed);
            mode_button.set_active (0);
            var mode_tool = new ToolItem ();
            mode_tool.add (mode_button);
            mode_tool.set_expand (false);
            toolbar.add (mode_tool);
		    
		    var spacer = new ToolItem ();
			spacer.set_expand (true);
			toolbar.add (spacer);
		    
		    this.take_button = new Button ();
		    this.take_button.get_style_context ().add_provider (css, 600);
		    this.take_button.get_style_context ().add_class ("take-button");
		    take_button.set_image (new Gtk.Image.from_icon_name ("camera-photo-symbolic", IconSize.BUTTON));
		    var take_tool = new ToolItem ();
		    take_tool.add (take_button);
		    take_tool.set_expand (false);
		    take_button.set_relief (ReliefStyle.NORMAL);
		    toolbar.add (take_tool);
		    
		    spacer = new ToolItem ();
			spacer.set_expand (true);
			toolbar.add (spacer);
		    
		    var share_menu = new Gtk.Menu ();
		    populate_with_contractor (share_menu);
		    var share_app_menu = new ToolButtonWithMenu (new Image.from_icon_name ("document-export", IconSize.MENU), "Share", share_menu);
		    toolbar.add (share_app_menu);
		    
		    var menu = ui.get_widget ("ui/AppMenu") as Gtk.Menu;
		    var app_menu = (this.get_application() as Granite.Application).create_appmenu (menu);
		    toolbar.add (app_menu);
		    
		    vbox.pack_start (toolbar, false, false, 0);
		    
		    // Setup drawing area
		    drawing_area = new DrawingArea ();
		    drawing_area.set_size_request (450, 250);
		    hbox.pack_start (drawing_area, true, true, 30);
		    vbox.pack_start (hbox, true, true, 30);
            
            // Setup the photo/video viewer
            var box = new Box (Orientation.VERTICAL, 0);
            
            viewer = new MediaViewer (GLib.Environment.get_home_dir () + "/Snap/");

            box.pack_start (viewer, true, true, 0);
            
            statusbar = new Statusbar ();
            statusbar.push (0, "0 photos and 0 videos");
            
            box.pack_start (statusbar, true, true, 0);
            
            vbox.pack_start (box, false, true, 0);
            
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
        
	    void setup_pipeline () {
            this.pipeline = new Pipelines (drawing_area);
            pipeline.play ();
        }
        
        void on_mode_changed (Widget widget) {
            if (mode_button.selected == 0) take_button.set_image (new Gtk.Image.from_icon_name ("camera-photo-symbolic", IconSize.BUTTON));
            else take_button.set_image (new Gtk.Image.from_icon_name ("camera-video-symbolic", IconSize.BUTTON));
        }
        
        void action_quit () {
            Gtk.main_quit ();        
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
