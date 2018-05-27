/*
* Copyright (c) 2011-2016 elementary LLC. (https://github.com/elementary/camera)
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
    private Gtk.Label timer_label;
    private Gee.ArrayList<int> all_time;
    private int index = 0;
    private string disabled = _("Disable");

    public const string TIMER_BUTTON_STYLESHEET = """
        .timer-button {
            border-radius: 100px;
        }
    """;

    public int time {
        get { return all_time[index]; }
    }

    public TimerButton () {
        Object (
            sensitive: false,
            tooltip_text: _("Delay time before taking a photo")
        );
    }

    construct {
        var main_grid = new Gtk.Grid ();

        var timer_image = new Gtk.Image.from_icon_name ("document-open-recent-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

        timer_label = new Gtk.Label (disabled);

        all_time = new Gee.ArrayList<int> ();
        all_time.add (0); // disabled
        all_time.add (3);
        all_time.add (5);
        all_time.add (10);

        Gtk.CssProvider timer_button_style_provider = new Gtk.CssProvider ();
        try {
            timer_button_style_provider.load_from_data (TIMER_BUTTON_STYLESHEET, -1);
        } catch (Error e) {
            warning ("Styling take button failed: %s", e.message);
        }

        var timer_button_style_context = this.get_style_context ();
        timer_button_style_context.add_provider (timer_button_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        timer_button_style_context.add_class ("timer-button");
        timer_button_style_context.add_class (Gtk.STYLE_CLASS_FLAT);

        this.clicked.connect ( () => {
            string val = "";
            index = index + 1;

            if (index > 3) {
                index = 0;
            }

            if (index <= -1) {
                index = 3;
            }

            if (index == 0) {
                val = disabled;
            } else {
                val = "%s Sec".printf(all_time[index].to_string ());
            }
            timer_label.label = val;
        });

        main_grid.add (timer_image);
        main_grid.add (timer_label);

        add (main_grid);
    }
}
