// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com>
  This program is free software: you can redistribute it and/or modify it	
  under the terms of the GNU Lesser General Public License version 3, as
  published	by the Free Software Foundation.
	
  This program is distributed in the hope that it will be useful, but	
  WITHOUT ANY WARRANTY; without even the implied warranties of	
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR	
  PURPOSE.  See the GNU General Public License for more details.
	
  You should have received a copy of the GNU General Public License along	
  with this program.  If not, see <http://www.gnu.org/licenses>
  
  END LICENSE	
***/

using Gtk;
using Gdk;
using Gst;
using Granite.Widgets;

namespace Snap.Widgets {
    
    public class MediaViewer : Granite.Widgets.StaticNotebook {
        
        string directory;
        public string selected;
        
        GLib.List<string> id_list;
        
        //Gnome.DesktopThumbnailFactory thumbnail_factory;
        
        ListStore list_store;
        IconView thumbnailer;
        
        public MediaViewer (string dir) {
            
            this.directory = dir;
            
            /**
             * Thumblainer things
             */
            
            //this.thumbnail_factory = new Gnome.DesktopThumbnailFactory (Gnome.ThumbnailSize.NORMAL);
            
            this.list_store = new Gtk.ListStore (1, typeof (Gdk.Pixbuf));
             
            this.thumbnailer = new Gtk.IconView ();
            thumbnailer.set_selection_mode (Gtk.SelectionMode.SINGLE);
		    thumbnailer.set_pixbuf_column (0);
		    thumbnailer.set_model (this.list_store);
		    thumbnailer.selection_changed.connect (on_selection_changed);
            
            list_dir ();
            
            var scroll = new ScrolledWindow (null, null);
            scroll.vscrollbar_policy = PolicyType.NEVER;
            scroll.add (thumbnailer);
            
            append_page (new VBox (false, 0), new Label (_("All")));
            append_page (scroll, new Label (_("Photo")));  
            append_page (new VBox (false, 0), new Label (_("Video")));   

            show_all ();
            
        }
    
        void on_selection_changed () {
            var item = thumbnailer.get_selected_items ();
		    if (item != null) {
		        string background = id_list.nth_data (int.parse (item.nth_data (0).to_string())).to_string();
		        var path = GLib.File.new_for_path(background).get_path();
		        this.selected = path;
            }
        }
        
        /**
         * Functions used to scan the media folder
         **/
        void list_dir () {
            debug ("Start scan\n");
            var dir = File.new_for_path (directory);
            // asynchronous call, with callback, to get dir entries
            dir.enumerate_children_async (FILE_ATTRIBUTE_STANDARD_NAME, 0,
                                            Priority.DEFAULT, null, list_ready);
        }
     
        /* Callback for enumerate_children_async */
        void list_ready (GLib.Object? file, AsyncResult res) {
            try {
                FileEnumerator e = ((File) file).enumerate_children_async.end (res);
                // asynchronous call, with callback, to get entries so far
                e.next_files_async (10, Priority.DEFAULT, null, list_files);
            } catch (Error err) {
                warning ("Error async_ready failed %s\n", err.message);
            }
        
        }
     
        /* Callback for next_files_async */
        void list_files (GLib.Object? sender, AsyncResult res) {
            Gtk.TreeIter iter;
            try {
                var enumer = (FileEnumerator) sender;
     
                // get a list of the files found so far
                GLib.List<FileInfo> list = enumer.next_files_async.end (res);
                foreach (FileInfo info in list) {
                    this.list_store.append (out iter);
                    this.id_list.append (directory + info.get_name ());
                    var pix = new Gdk.Pixbuf.from_file_at_size (directory + info.get_name (), 100, 150);
                    this.list_store.set (iter, 0, pix,  -1);
                }    
                
                // asynchronous call, with callback, to get any more entries
                enumer.next_files_async (10, Priority.DEFAULT, null, list_files);
            } catch (Error err) {
                warning ("error list_files failed %s\n", err.message);
            }
        }
        
    }

}