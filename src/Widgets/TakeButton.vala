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

public class Camera.Widgets.TakeButton : Gtk.Button {
    private Gtk.Label timer_label;
    private Gtk.Image take_image;

    private bool timer_active = false;

    public const string TAKE_BUTTON_STYLESHEET = """
        .take-button {
            border-radius: 400px;
        }
    """;

    public string icon_name {
        set { take_image.icon_name = value; }
    }

    public TakeButton () {
        Object (
            sensitive: false,
            width_request: 54
        );
    }

    construct {
        take_image = new Gtk.Image ();

        timer_label = new Gtk.Label ("00:00");
        timer_label.no_show_all = true;

        Gtk.CssProvider take_button_style_provider = new Gtk.CssProvider ();

        try {
            take_button_style_provider.load_from_data (TAKE_BUTTON_STYLESHEET, -1);
        } catch (Error e) {
            warning ("Styling take button failed: %s", e.message);
        }

        var take_button_style_context = this.get_style_context ();
        take_button_style_context.add_provider (take_button_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        take_button_style_context.add_class ("take-button");
        take_button_style_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var main_grid = new Gtk.Grid ();
        main_grid.halign = Gtk.Align.CENTER;
        main_grid.margin_left = 6;
        main_grid.margin_right = 6;

        main_grid.add (take_image);
        main_grid.add (timer_label);

        add (main_grid);
    }

    public void start_timer () {
        timer_label.visible = true;
        timer_label.label = "00:00";
        timer_active = true;

        int minute = 0;
        int seconds = 0;

        string minute_string = "00";
        string seconds_string = "00";

        Timeout.add_seconds (1, () => {
            seconds = seconds + 1;
            if (seconds > 59) {
                seconds = 0;
                minute = minute + 1;
            }

            seconds_string = seconds.to_string ();
            minute_string = minute.to_string ();

            if (seconds_string.length <= 1) {
                seconds_string = "0" + seconds_string;
            }

            if (minute_string.length <= 1) {
                minute_string = "0" + minute_string;
            }

            timer_label.label = "%s:%s".printf(minute_string, seconds_string);
            return timer_active;
        });
    }

    public void stop_timer () {
        timer_active = false;
        timer_label.visible = false;
    }
}
