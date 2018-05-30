/*
 * Copyright (c) 2011-2018 elementary LLC. (https://github.com/elementary/camera)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Alain M. <alain23@protonmail.com>
 */

public class Camera.Widgets.TimerButton : Gtk.Button {
    public enum Delay {
        DISABLED = 0,
        3_SEC = 3,
        5_SEC = 5,
        10_SEC = 10;
        public Delay next () {
            switch (this) {
                case 3_SEC:
                    return 5_SEC;
                case 5_SEC:
                    return 10_SEC;
                case 10_SEC:
                    return DISABLED;
                default:
                    return 3_SEC;
            }
        }
        public string to_string () {
            if (this == Delay.DISABLED) {
                return _("Disabled");
            } else {
                ///TRANSLATORS: Seconds in a timer
                return ngettext ("%d Sec", "%d Sec", this).printf (this);
            }
        }
    }

    public Delay delay = Delay.DISABLED;

    construct {
        var timer_image = new Gtk.Image.from_icon_name ("timer-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        var timer_label = new Gtk.Label (delay.to_string ());

        this.clicked.connect (() => {
            delay = delay.next ();
            timer_label.label = delay.to_string ();
        });

        var main_grid = new Gtk.Grid ();
        main_grid.add (timer_image);
        main_grid.add (timer_label);

        sensitive = false;
        tooltip_text = _("Delay before photo is taken");
        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        add (main_grid);
    }
}
