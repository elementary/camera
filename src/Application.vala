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
 * Authored by: Marcus Wichelmann <marcus.wichelmann@hotmail.de>
 */

public class Camera.Application : Gtk.Application {
    public static GLib.Settings settings;

    static construct {
        settings = new Settings ("io.elementary.camera.settings");
    }

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (GETTEXT_PACKAGE);

        application_id = "io.elementary.camera";

        var quit_action = new SimpleAction ("quit", null);

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});

        quit_action.activate.connect (() => {
            quit ();
        });
    }

    protected override void activate () {
        if (active_window != null) {
            active_window.present_with_time (Gdk.CURRENT_TIME);
            return;
        }

        var main_window = new MainWindow (this);
        main_window.present ();

        add_window (main_window);

        /*
        * This is very finicky. Bind size after present else set_titlebar gives us bad sizes
        * Set maximize after height/width else window is min size on unmaximize
        * Bind maximize as SET else get get bad sizes
        */
        var settings = new Settings ("io.elementary.music");
        settings.bind ("window-height", main_window, "default-height", SettingsBindFlags.DEFAULT);
        settings.bind ("window-width", main_window, "default-width", SettingsBindFlags.DEFAULT);

        if (settings.get_boolean ("window-maximized")) {
            main_window.maximize ();
        }

        settings.bind ("window-maximized", main_window, "maximized", SettingsBindFlags.SET);
    }

    public static int main (string[] args) {
        Gst.init (ref args);

        var application = new Application ();

        return application.run (args);
    }
}
