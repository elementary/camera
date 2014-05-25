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
        public bool is_temp { get; public set; }
        public File temp_file { get; public set; }
        
        public Thumbnail (File file, Gdk.Pixbuf pixbuf) {
            this.file = file;
            this.pixbuf = pixbuf;
        }
    }

    public class ThumbnailProvider : GLib.Object {
        private File path;
        private Gee.Set<Thumbnail> cache;
        private int temp_thumb;
        
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
            this.cache = new Gee.TreeSet<Thumbnail> ();
            this.temp_thumb = 0;
        }
        
        /**
         * Asynchronously load thumbnails and add them in a Gee.TreeSet object. The thumbnail_loaded
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
                            this.cache.add (thumb);
                            thumbnail_loaded (thumb);
                        }
                    }
                }
            } catch (Error err) {
                warning ("Error: parse_thumbs failed: %s", err.message);
            }
        }
        
        private Thumbnail? get_thumbnail (File file) {
            Thumbnail? thumb = null;
            try {
                var info = file.query_info ("*", 0, null);
                var attr = info.get_attribute_byte_string ("thumbnail::path");
                Gdk.Pixbuf pix = null;
                if (attr == null) pix = new Gdk.Pixbuf.from_file (file.get_path ());
                else pix = new Gdk.Pixbuf.from_file (attr);
                pix = pix.scale_simple (THUMB_WIDTH, THUMB_HEIGHT, 0);
                thumb = new Thumbnail (file, pix);
            } catch (Error err) {
                warning ("Error: get_thumbnail failed: %s", err.message);
            }
            
            if (thumb == null) {
                // Try to obtain the thumbnail with ffmpegthumbnailer
                try {
                    string tmp_path = GLib.Environment.get_tmp_dir ();
                    string out_path = tmp_path + "/temp" + this.temp_thumb.to_string () + ".png";
                    string[] spawn_args = {"ffmpegthumbnailer", 
                                            "-i", file.get_path (), // Input file
                                            "-o", out_path, // Output file
                                            "-c", "png",
                                            "-f", "-t", "10",
                                            "-s", THUMB_WIDTH.to_string () };
                    string[] spawn_env = Environ.get ();
                    Pid child_pid;

                    Process.spawn_async ("/",
                        spawn_args,
                        spawn_env,
                        SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                        null,
                        out child_pid);

                    ChildWatch.add (child_pid, (pid, status) => {
                        // Triggered when the child indicated by child_pid exits
                        Process.close_pid (pid);
                    });

                    Gdk.Pixbuf pix = new Gdk.Pixbuf.from_file (out_path);
                    pix = pix.scale_simple (THUMB_WIDTH, THUMB_HEIGHT, 0);
                    thumb = new Thumbnail (file, pix);
                    thumb.is_temp = true;
                    thumb.temp_file = File.new_for_path (out_path);
                    // Increment temp thumbs counter
                    this.temp_thumb++;
                } catch (SpawnError serr) {
                    warning ("Error: get_thumbnail failed: %s", serr.message);
                } catch (Error err) {
                    warning ("Error: get_thumbnail failed: %s", err.message);
                }
            }
            return thumb;
        }
        
        /**
         * Execute this method on quitting to clean temp cache
         */
        public void clear_cache () {
            Gee.Iterator<Thumbnail> iterator = this.cache.iterator ();
            while (iterator.has_next ()) {
                iterator.next ();
                Thumbnail? thumb = iterator.get ();
                if (thumb != null && thumb.is_temp) {
                    try {
                        thumb.temp_file.delete (null);
                    } catch (Error err) {
                        warning ("Error: clear_cache failed: %s", err.message);
                    }
                }
            }
        }
    }
}