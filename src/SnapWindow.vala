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
using Granite.Widgets;

using Snap.Widgets;

namespace Snap {
	
	public class SnapWindow : Gtk.Window {
		
		private const string TITLE = "Snap";
		public Snap.SnapApp snap_app;
		bool video_start = true;
		
		//widgets
		public DrawingArea drawing_area;	
        Gtk.Toolbar toolbar;
        ModeButton mode_button;
        Button take_button;
        StaticNotebook viewer;
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
		    
		    this.destroy.connect (Gtk.main_quit);
		    
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
                    pipeline.take_video_stop ();
                    video_start = true;
                }
            }});
            
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
		    
		    var share_app_menu = new ToolButtonWithMenu (new Image.from_icon_name ("document-export", IconSize.MENU), "Share", new Gtk.Menu ());
		    share_app_menu.set_sensitive (false);
		    toolbar.add (share_app_menu);
		    
		    var app_menu = (this.get_application() as Granite.Application).create_appmenu(new Gtk.Menu ());
		    toolbar.add (app_menu);
		    
		    vbox.pack_start (toolbar, false, false, 0);
		    
		    // Setup drawing area
		    drawing_area = new DrawingArea ();
		    drawing_area.set_size_request (450, 250);
		    hbox.pack_start (drawing_area, true, true, 30);
		    vbox.pack_start (hbox, true, true, 30);
            
            // Setup the photo/video viewer
            var box = new Box (Orientation.VERTICAL, 0);
            
            viewer = new StaticNotebook ();
            
            viewer.append_page (new VBox (false, 0), new Label (_("All")));
            viewer.append_page (new VBox (false, 0), new Label (_("Photo")));  
            viewer.append_page (new VBox (false, 0), new Label (_("Video")));   
            
            box.pack_start (viewer, true, true, 0);
            
            statusbar = new Statusbar ();
            statusbar.push (0, "0 photos and 0 videos");
            
            box.pack_start (statusbar, true, true, 0);
            
            vbox.pack_start (box, false, true, 0);
            
		    add (vbox);
		    
		    show_all (); 
		    
		}

	    void setup_pipeline () {
            this.pipeline = new Pipelines (drawing_area);
            pipeline.play ();
        }
        
        void on_mode_changed (Widget widget) {
            if (mode_button.selected == 0) take_button.set_image (new Gtk.Image.from_icon_name ("camera-photo-symbolic", IconSize.BUTTON));
            else take_button.set_image (new Gtk.Image.from_icon_name ("camera-video-symbolic", IconSize.BUTTON));
        }
        
	}	
	
}