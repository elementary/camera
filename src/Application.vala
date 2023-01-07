/*
 * Copyright 2011-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-2.0-or-later
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
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (GETTEXT_PACKAGE);

        application_id = "io.elementary.camera";

        var quit_action = new SimpleAction ("quit", null);

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});

        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.destroy ();
            }
        });
    }

    protected override void activate () {
        if (get_windows () == null) {
            main_window = new MainWindow (this);

            int width, height;
            settings.get ("window-size", "(ii)", out width, out height);

            var hints = Gdk.Geometry ();
            hints.min_aspect = 1.0;
            hints.max_aspect = -1.0;
            hints.min_width = 436;
            hints.min_height = 352;

            main_window.set_geometry_hints (null, hints, Gdk.WindowHints.ASPECT | Gdk.WindowHints.MIN_SIZE);
            main_window.resize (width, height);

            if (settings.get_boolean ("window-maximized")) {
                main_window.maximize ();
            }

            main_window.window_position = Gtk.WindowPosition.CENTER;
            main_window.show_all ();
        } else {
            main_window.present ();
        }
    }

    public static int main (string[] args) {
        Gst.init (ref args);

        var application = new Application ();

        return application.run (args);
    }
}
