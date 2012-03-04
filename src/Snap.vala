// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
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

using Gtk;

using Granite;
using Granite.Services;

namespace Snap {

    /**
     * Type of media
     */
    public enum MediaType {
        PHOTO,
        VIDEO
    }

    public Snap.Services.Settings settings;

    public class SnapApp : Granite.Application {

        public SnapWindow window = null;
        static string app_cmd_name;

        construct {

            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;

            program_name = app_cmd_name;
            exec_name = app_cmd_name.down();
            app_years = "2011-2012";
            app_icon = "snap";
            app_launcher = "snap.desktop";
            application_id = "net.launchpad.snap-elementary";
            main_url = "https://launchpad.net/snap-elementary";
            bug_url = "https://bugs.launchpad.net/snap-elementary";
            help_url = "https://answers.launchpad.net/snap-elementary";
            translate_url = "https://translations.launchpad.net/snap-elementary";
            about_authors = {"Mario Guerriero <mefrio.g@gmail.com>", null };
            //about_documenters = {"",""};
            about_artists = { "Daniel Fore <daniel.p.fore@gmail.com >", "Harvey Cabaguio <harveycabaguio@gmail.com>", null };
            //about_translators = "Launchpad Translators";
            about_license_type = License.GPL_3_0;

        }

        public SnapApp () {

            Logger.initialize (app_cmd_name);
            Logger.DisplayLevel = LogLevel.DEBUG;

            settings = new Snap.Services.Settings ();

            // Create Snap dirs
            GLib.DirUtils.create (Resources.get_media_dir (MediaType.PHOTO), 0755);
            GLib.DirUtils.create (Resources.get_media_dir (MediaType.VIDEO), 0755);
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

            app_cmd_name = "Snap";

            Gst.init (ref args);

            var app = new SnapApp ();

            return app.run (args);

        }

    }
}
