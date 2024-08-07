/*
 * Copyright 2011-2024 elementary, Inc. (https://github.com/elementary/camera)
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

    public Delay delay;

    construct {
        delay = (Delay) Camera.Application.settings.get_enum ("delay");

        var label_widget = new Gtk.Label (delay.to_string ()) {
            margin_end = 3
        };

        var box = new Gtk.Box (HORIZONTAL, 3);
        box.append (new Gtk.Image.from_icon_name ("timer-symbolic"));
        box.append (label_widget);

        child = box;
        has_frame = false;
        tooltip_text = _("Delay before photo is taken");

        clicked.connect (() => {
            delay = delay.next ();
            Camera.Application.settings.set_enum ("delay", delay);
            label_widget.label = delay.to_string ();
        });
    }
}
