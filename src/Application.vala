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
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Marcus Wichelmann <marcus.wichelmann@hotmail.de>
 */

public class Camera.Application : Granite.Application {
    public static int main (string[] args) {
        ClutterGst.init (ref args);

        var application = new Application ();

        return application.run (args);
    }

    public MainWindow? main_window = null;

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");

        build_data_dir = Config.DATADIR;
        build_pkg_data_dir = Config.PKGDATADIR;
        build_release_name = Config.RELEASE_NAME;
        build_version = Config.VERSION;
        build_version_info = Config.VERSION_INFO;

        program_name = _(Config.APP_NAME);
        exec_name = "pantheon-camera";
        app_years = "2011-2016";
        app_icon = "accessories-camera";
        app_launcher = "com.github.elementary.camera.desktop";
        application_id = "com.github.elementary.camera";
        main_url = "https://github.com/elementary/camera";
        bug_url = "https://github.com/elementary/camera/issues";
        help_url = "http://elementaryos.stackexchange.com/questions/tagged/camera";
        translate_url = "https://translations.launchpad.net/pantheon-camera";
        about_authors = { "Marcus Wichelmann <marcus.wichelmann@hotmail.de>", "Mario Guerriero <mario@elementaryos.org>", null };
        about_artists = { "Daniel Foré <daniel@elementary.io>", "Harvey Cabaguio <harveycabaguio@gmail.com>", null };
        about_translators = _("translator-credits");
        about_license_type = Gtk.License.GPL_3_0;

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.destroy ();
            }
        });

        add_action (quit_action);
        add_accelerator ("<Control>q", "app.quit", null);
    }

    public Application () {
        /* TODO */
    }

    protected override void activate () {
        if (this.get_windows () == null) {
            main_window = new MainWindow (this);
            main_window.show_all ();
        } else {
            main_window.present ();
        }
    }
}
