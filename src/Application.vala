/*
 * Copyright 2011-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * Authored by: Marcus Wichelmann <marcus.wichelmann@hotmail.de>
 */

public class Camera.Application : Gtk.Application {
    public static Settings settings;

    public Application () {
        Object (
            application_id: "io.elementary.camera",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    construct {
        settings = new Settings ("io.elementary.camera.settings");

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        add_option_group (Gst.init_get_option_group ());

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (quit);
        add_action (quit_action);

        set_accels_for_action ("app.quit", {"<Control>q"});

    }

    protected override void activate () {
        if (active_window == null) {
            var main_window = new MainWindow (this);

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
        }

        active_window.present ();
    }

    public static int main (string[] args) {
        return new Application ().run (args);
    }
}
