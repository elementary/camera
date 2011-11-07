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

namespace Snap.Widgets {
    
    public class SnapToolbar : Gtk.Toolbar {
        
        SnapWindow window;
OffscreenWindow offw; // offw.add (widgets); var pix = offew.get_pixbuf ()
        Button effects;
        ModeButton mode_button;
        Button take;
        
        SnapAppMenu menu;
        AppMenu app_menu;
        
        public SnapToolbar (SnapWindow window) {
            this.window = window;
            
            setup_toolbar ();
        }
        
        void setup_toolbar () {
            effects = new Button.with_label ("Effects");
            add (toolitem (effects, false));
            
            mode_button = new ModeButton ();
            mode_button.valign = Gtk.Align.CENTER;
            mode_button.halign = Gtk.Align.CENTER;
            mode_button.append(new Gtk.Label("Photo"));
            mode_button.append(new Gtk.Label("Video"));
            add (toolitem (mode_button, false));
            
            add_spacer ();
            
            take = new Button.with_label ("Take a photo");
            take.override_background_color (Gtk.StateFlags.FOCUSED, {1.0, 0.0, 0.0, 1.0});
            add (toolitem (take, false));
            
            add_spacer ();
            
            menu = new SnapAppMenu ();
            app_menu = (window.get_application() as Granite.Application).create_appmenu(menu);
            
            add (app_menu);
            
            show_all ();
        }  
        
        ToolItem toolitem (Widget widget, bool expand = true, int border_width = 0) {
		
		    var new_tool_item = new ToolItem ();
		    new_tool_item.add (widget);

		    if (border_width > 0) {
		        new_tool_item.set_border_width (border_width);
		    }
            new_tool_item.set_expand (expand);

		    return new_tool_item;
        } 
        
        void add_spacer () {
			
			var spacer = new ToolItem ();
			spacer.set_expand (true);
			
			add (spacer);
			
		}
        
    }
    
}