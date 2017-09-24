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
 * Authored by: Marcus Wichelmann <marcus.wichelmann@hotmail.de>
 */

namespace Camera.Utils {
    public enum ActionType {
        PHOTO,
        VIDEO
    }

    public string get_new_media_filename (ActionType action_type) {
        string time = new GLib.DateTime.now_local ().format ("%F%H:%M:%S");

        int file_id = 0;
        string next_filename = "";

        do {
            next_filename = time + (file_id > 0 ? "-" + file_id.to_string () : "");
            file_id++;
        } while (GLib.FileUtils.test (build_media_filename (next_filename, action_type), FileTest.EXISTS));

        return build_media_filename (next_filename, action_type);
    }

    public string build_media_filename (string filename, ActionType action_type) {
        string full_filename = "%s.%s".printf (filename, action_type == ActionType.PHOTO ? "jpg" : "ogv");
        string media_directory = get_media_directory (action_type);

        if (!FileUtils.test (media_directory, FileTest.EXISTS)) {
            DirUtils.create (media_directory, 0777);
        }

        return GLib.Path.build_filename (Path.DIR_SEPARATOR_S, media_directory, full_filename);
    }

    public string get_media_directory (ActionType action_type) {
        UserDirectory user_dir = (action_type == ActionType.PHOTO ? UserDirectory.PICTURES : UserDirectory.VIDEOS);
        string media_directory = GLib.Environment.get_user_special_dir (user_dir);

        return GLib.Path.build_path (Path.DIR_SEPARATOR_S, media_directory, "Webcam");
    }
}
