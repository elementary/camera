// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mario@elementaryos.org>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/


namespace Snap.Services {
    public class Thumbnail : GLib.Object {
        public File file { get; protected set; }
        public Gdk.Pixbuf pixbuf { get; protected set; }
        
        public Thumbnail (File file, Gdk.Pixbuf pixbuf) {
            this.file = file;
            this.pixbuf = pixbuf;
        }
    }
    
    public class ThumbnailProvider : GLib.Object {
        private File path;
        private GLib.List<Thumbnail> thumbnails;
        
        public static const int THUMB_WIDTH = Widgets.Camera.WIDTH / 4;
        public static const int THUMB_HEIGHT = Widgets.Camera.HEIGHT / 4;
        
        public signal void thumbnail_loaded (Thumbnail thumbnail);
        
        /**
         * Creates a new object of time ThumbnailProvider. This type of objects are used
         * to obtain thumbnails for files in a specific path
         * @param path the path where the provider will look for thumbnails
         */
        public ThumbnailProvider (File path) {
            this.path = path;
            this.thumbnails = new GLib.List<Thumbnail>();
        }
        
        /**
         * Asynchronously load thumbnails and add them in a GLib.List object. The thumbnail_loaded
         * is emitted whenever a new Thumbnail is fully loaded
         */
        public async void parse_thumbs () {
            try {
                var e = yield this.path.enumerate_children_async (FileAttribute.STANDARD_NAME,
                                                            0, Priority.DEFAULT);
                while (true) {
                    var files = yield e.next_files_async (10, Priority.DEFAULT);
                    if (files == null) {
                        break;
                    }

                    foreach (var info in files) {
                        File thumb_path = this.path.resolve_relative_path (info.get_name ());
                        var thumb = this.get_thumbnail (thumb_path);
                        if (thumb != null) {
                            this.thumbnails.append (thumb);
                            thumbnail_loaded (thumb);
                        }
                    }
                }
            } catch (Error err) {
                warning ("Error: parse_thumbs failed: %s\n", err.message);
            }
        }
        
        private Thumbnail? get_thumbnail (File file) {
            try {
                var info = file.query_info ("*", 0, null);
                var attr = info.get_attribute_byte_string ("thumbnail::path");
                Gdk.Pixbuf pix = null;
                if (attr == null) pix = new Gdk.Pixbuf.from_file (file.get_path ());
                else pix = new Gdk.Pixbuf.from_file (attr);
                pix = pix.scale_simple (THUMB_WIDTH, THUMB_HEIGHT, 0);
                return new Thumbnail (file, pix);
            } catch (Error err) {
                warning ("Error: get_thumbnail failed: %s\n", err.message);
            }
            return null;
        }
    }
}