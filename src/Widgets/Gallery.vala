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
        
        private Gtk.ListStore photo_model;
        private Gtk.ListStore video_model;
        private Gtk.IconView photo_view;
        private Gtk.IconView video_view;
        
        public Gallery () {
            this.photo_model = new Gtk.ListStore (2, typeof (Gdk.Pixbuf), typeof (string));
            this.video_model = new Gtk.ListStore (2, typeof (Gdk.Pixbuf), typeof (string));
        
            this.photo_view = new Gtk.IconView.with_model (photo_model);
            this.video_view = new Gtk.IconView.with_model (video_model);
        
            Resources.photo_thumb_provider.thumbnail_loaded.connect (on_photo_thumb_loaded);
            Resources.video_thumb_provider.thumbnail_loaded.connect (on_video_thumb_loaded);
        }
        
        private void on_photo_thumb_loaded (Services.Thumbnail thumb) {
            Gtk.TreeIter iter;
            this.photo_model.append (out iter);
            this.photo_model.set (iter, 0, thumb.pixbuf, 1, thumb.file.get_basename ());
        }
        
        private void on_video_thumb_loaded (Services.Thumbnail thumb) {
            Gtk.TreeIter iter;
            this.video_model.append (out iter);
            this.video_model.set (iter, 0, thumb.pixbuf, 1, thumb.file.get_basename ());
        }
    }
    
}