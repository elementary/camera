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
    }

    public override void startup () {
        base.startup ();
        Granite.init ();

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (quit);
        add_action (quit_action);

        set_accels_for_action ("app.quit", {"<Control>q"});

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme =
            granite_settings.prefers_color_scheme == DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme =
                granite_settings.prefers_color_scheme == DARK;
        });
    }

    protected override void activate () {
        if (active_window == null) {
            var main_window = new MainWindow (this);

            /*
            * This is very finicky. Bind size after present else set_titlebar gives us bad sizes
            * Set maximize after height/width else window is min size on unmaximize
            * Bind maximize as SET else get get bad sizes
            */
            settings.bind ("window-height", main_window, "default-height", DEFAULT);
            settings.bind ("window-width", main_window, "default-width", DEFAULT);

            if (settings.get_boolean ("window-maximized")) {
                main_window.maximize ();
            }

            settings.bind ("window-maximized", main_window, "maximized", SET);
        }

        active_window.present ();
    }

    public static int main (string[] args) {
        return new Application ().run (args);
    }
}
