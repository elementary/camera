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

namespace Snap.Widgets {

    public class EffectPopOver : Granite.Widgets.PopOver {

        public EffectPopOver (Cheese.Camera camera, Cheese.EffectsManager effects_manager) {
            
            var effects_popover_style = new Gtk.CssProvider ();
            try {
                effects_popover_style.load_from_data (Resources.EFFECTS_POPOVER_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }
            this.get_style_context ().add_class ("snap-effects-popover");
            this.get_style_context ().add_provider (effects_popover_style,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var vbox_widget = new Gtk.VBox (false, 0);
	
			foreach (var effect in effects_manager.effects) {
		        var togglebutton = new Gtk.ToggleButton.with_label(effect.get_name ());
				togglebutton.toggled.connect (() => {
					camera.set_effect (effect);
				});
				
		        vbox_widget.pack_start (togglebutton, false, false, 0);

		        var vbox_window = get_content_area () as Gtk.Box;
		        vbox_window.pack_start (vbox_widget, false, false, 0);
		    }
        }
    }
}
