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
    private Gee.ArrayList<int> all_time;
    private int index = 0;

    private const string DISABLED = _("Disabled");

    public int time {
        get { return all_time[index]; }
    }

    construct {
        var timer_image = new Gtk.Image.from_icon_name ("timer-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

        var timer_label = new Gtk.Label (DISABLED);

        all_time = new Gee.ArrayList<int> ();
        all_time.add (0);   // disabled
        all_time.add (3);   // 3 Sec
        all_time.add (5);   // 5 Sec
        all_time.add (10);  // 10 Sec

        this.clicked.connect (() => {
            index++;

            if (index > 3) {
                index = 0;
            }

            if (index <= -1) {
                index = 3;
            }

            if (index == 0) {
                timer_label.label = DISABLED;
            } else {
                ///TRANSLATORS: Seconds in a timer
                timer_label.label = ngettext ("%d Sec", "%d Sec", all_time[index]).printf (all_time[index]);
            }
        });

        var main_grid = new Gtk.Grid ();
        main_grid.add (timer_image);
        main_grid.add (timer_label);

        sensitive = false;
        tooltip_text = _("Delay time before taking a photo");
        get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        add (main_grid);
    }
}
