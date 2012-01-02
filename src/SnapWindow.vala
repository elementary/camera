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

namespace Snap {
	
	public class SnapWindow : Gtk.Window {
		
		private const string TITLE = "Snap";
		public Snap.SnapApp snap_app;
		
		//widgets
		public DrawingArea drawing_area;	
        Gtk.Toolbar toolbar;
        Button take_button;
        StaticNotebook viewer;
        Statusbar statusbar;
        
        // CSS styling
        Gtk.StyleContext context;
        Gtk.CssProvider css;
        
        //gst objects
        public SnapPipelines pipeline;
		
		public SnapWindow (Snap.SnapApp snap_app) {
		    
		    this.snap_app = snap_app;
		    set_application (this.snap_app);
		    
		    this.title = TITLE;
		    
		    this.destroy.connect (Gtk.main_quit);
		    
		    css = new Gtk.CssProvider ();
            try {
                css.load_from_path ("Snap.css"); 
            } catch (Error e) {
                warning ("%s", e.message);
            }
            context = new Gtk.StyleContext ();
            context.add_provider_for_screen (get_screen (), css, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		    
		    setup_window ();
		    setup_pipeline ();
            
            take_button.clicked.connect (pipeline.take_photo);
            
		}
		
		void setup_window () {
		    
		    var vbox = new Box (Orientation.VERTICAL, 0);
		    var hbox = new Box (Orientation.HORIZONTAL, 0);
		    
		    // Setup toolbar
		    toolbar = new Gtk.Toolbar ();
		    toolbar.get_style_context ().add_class ("primary-toolbar");
		    
		    var mode_button = new ModeButton ();
            mode_button.valign = Gtk.Align.CENTER;
            mode_button.halign = Gtk.Align.CENTER;
            mode_button.append(new Gtk.Label("Photo"));
            mode_button.append(new Gtk.Label("Video"));
            var mode_tool = new ToolItem ();
            mode_tool.add (mode_button);
            mode_tool.set_expand (false);
            toolbar.add (mode_tool);
		    
		    var spacer = new ToolItem ();
			spacer.set_expand (true);
			toolbar.add (spacer);
		    
		    this.take_button = new Button.with_label ("Take a photo");
		    this.take_button.get_style_context ().add_provider (css, 600);
		    this.take_button.get_style_context ().add_class ("take-button");
		    var take_tool = new ToolItem ();
		    take_tool.add (take_button);
		    take_tool.set_expand (false);
		    toolbar.add (take_tool);
		    
		    spacer = new ToolItem ();
			spacer.set_expand (true);
			toolbar.add (spacer);
		    
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
            
            viewer.append_page (new VBox (false, 0), new Label ("All"));
            viewer.append_page (new VBox (false, 0), new Label ("Photo"));  
            viewer.append_page (new VBox (false, 0), new Label ("Video"));   
            
            box.pack_start (viewer, true, true, 0);
            
            statusbar = new Statusbar ();
            statusbar.push (0, "0 photos and 0 videos");
            
            box.pack_start (statusbar, true, true, 0);
            
            vbox.pack_start (box, false, true, 0);
            
		    add (vbox);
		    
		    show_all (); 
		    
		}

	    void setup_pipeline () {
            this.pipeline = new SnapPipelines (drawing_area);
            pipeline.play ();
        }

	}	
	
}