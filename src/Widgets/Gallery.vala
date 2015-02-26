// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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

namespace Snap.Widgets {

    public class Gallery : Gtk.ScrolledWindow {
        private Gtk.ListStore model;
        private Gtk.IconView view;

        public Gallery () {
            this.model = new Gtk.ListStore (2, typeof (Gdk.Pixbuf), typeof (Services.Thumbnail));

            this.view = new Gtk.IconView.with_model (model);
            this.view.set_pixbuf_column (0);
            this.view.set_selection_mode (Gtk.SelectionMode.SINGLE);
            this.view.selection_changed.connect (() => {
                GLib.List<Gtk.TreePath> paths = this.view.get_selected_items ();
                Gtk.TreeIter iter;
                Services.Thumbnail thumb = null;

                foreach (Gtk.TreePath path in paths) {
                    this.model.get_iter (out iter, path);

                    GLib.Value val;
                    this.model.get_value (iter, 1, out val);

                    thumb = (Services.Thumbnail) val;

                    Resources.launch_file (thumb.file);
                }
            });

            Resources.photo_thumb_provider.thumbnail_loaded.connect (add_thumbnail);
            Resources.video_thumb_provider.thumbnail_loaded.connect (add_thumbnail);

            this.add (view);
        }

        private void add_thumbnail (Services.Thumbnail thumb) {
            Gtk.TreeIter iter;
            this.model.append (out iter);
            this.model.set (iter, 0, thumb.pixbuf, 1, thumb);
        }

        /**
         + Simply clear the IconView as the name suggests
         */
        public void clear_view () {
            this.model.clear ();
        }
    }
}
