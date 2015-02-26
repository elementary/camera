// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as
  published    by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses>

  END LICENSE
***/

namespace Snap {
    public Snap.Services.Settings settings;

    public class SnapApp : Granite.Application {
        /**
         * Translatable launcher (.desktop) strings to be added to template (.pot) file.
         * These strings should reflect any changes in these launcher keys in .desktop file
         */
        public const string CAMERA = N_("Camera");
        public const string COMMENT = N_("Take photos and videos with the camera");
        public const string GENERIC_NAME = N_("Photo Booth");
        public const string PROGRAM_NAME = "Snap";
        public const string QUICKLIST_ABOUT_STOCK = N_("About Snap");
        public const string QUICKLIST_ABOUT_GENERIC = N_("About Camera");

        public SnapWindow window = null;

        construct {
            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;

            program_name = PROGRAM_NAME;
            exec_name = "snap-photobooth";
            app_years = "2011-2014";
            app_icon = "accessories-camera";
            app_launcher = "snap-photobooth.desktop";
            application_id = "net.launchpad.snap-elementary";
            main_url = "https://launchpad.net/snap-elementary";
            bug_url = "https://bugs.launchpad.net/snap-elementary";
            help_url = "https://answers.launchpad.net/snap-elementary";
            translate_url = "https://translations.launchpad.net/snap-elementary";
            about_authors = {"Mario Guerriero <mario@elementaryos.org>", null };
            about_artists = { "Daniel Fore <daniel.p.fore@gmail.com >", "Harvey Cabaguio <harveycabaguio@gmail.com>", null };
            about_translators = "Launchpad Translators";
            about_license_type = Gtk.License.GPL_3_0;
        }

        public SnapApp () {
            Granite.Services.Logger.initialize ("Snap");
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;

            settings = new Snap.Services.Settings ();
        }

        protected override void activate () {
            if (get_windows () == null) {
                window = new SnapWindow (this);
                window.show ();
            }
            else {
                window.present ();
            }
        }

        public static int main (string[] args) {
            Gst.init (ref args);

            var app = new SnapApp ();

            return app.run (args);
        }
    }
}
