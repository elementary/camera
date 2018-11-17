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
    public MainWindow? main_window = null;

    static construct {
        settings = new Settings ("io.elementary.camera.settings");
    }

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");
        application_id = "io.elementary.camera";

        var quit_action = new SimpleAction ("quit", null);

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});

        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.destroy ();
            }
        });

        const string DESKTOP_SCHEMA = "io.elementary.desktop";
        const string DARK_KEY = "prefer-dark";

        var lookup = SettingsSchemaSource.get_default ().lookup (DESKTOP_SCHEMA, false);

        if (lookup != null) {
            var desktop_settings = new Settings (DESKTOP_SCHEMA);
            var gtk_settings = Gtk.Settings.get_default ();
            desktop_settings.bind (DARK_KEY, gtk_settings, "gtk_application_prefer_dark_theme", SettingsBindFlags.DEFAULT);
        }
    }

    protected override void activate () {
        if (this.get_windows () == null) {
            main_window = new MainWindow (this);
            main_window.show_all ();
        } else {
            main_window.present ();
        }
    }

    public static int main (string[] args) {
        ClutterGst.init (ref args);

        var application = new Application ();

        return application.run (args);
    }
}
