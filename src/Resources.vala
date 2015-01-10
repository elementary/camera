// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2011-2012 Snap Developers
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

using Snap.Widgets;
using Snap.Services;

namespace Resources {

    public const string TAKE_BUTTON_STYLESHEET = """
        .take-button {
            border-radius: 400px;
        }
    """;

    public const string PREVIEW_STYLESHEET = """
        .snap-preview-bg {
            background-color: #000;
        }
    """;

    public const string ICON_VIEW_STYLESHEET = """
        GtkIconView.view {
            background-color: @bg_color;
        }

        GtkIconView.view.cell:selected,
        GtkIconView.view.cell:selected:focused {
            background-color: @selected_bg_color;
            border-radius: 4px;
        }
    """;

    /**
     * @return path to save photos or videos
     */
    public string get_media_dir (Camera.ActionType type) {
        UserDirectory user_dir;

        if (type == Camera.ActionType.PHOTO)
            user_dir = UserDirectory.PICTURES;
        else
            user_dir = UserDirectory.VIDEOS;

        string dir = GLib.Environment.get_user_special_dir (user_dir);
        return GLib.Path.build_path ("/", dir, "Webcam");
    }

    /**
     * Creates a file name with format 'YYYY-MM-DD HH:MM:SS.ext'
     *
     * @param extension file extension [allow-none]
     *
     * @return new photo/video filename.
     */
    public string get_new_media_filename (Camera.ActionType type, string? ext = null) {
        // Get date and time
        var datetime = new GLib.DateTime.now_local ();
        string time = datetime.format ("%F%H:%M:%S");

        int n = 0;
        string filename = "";
        do {
            filename = time + (n > 0 ? "-" + n.to_string () : "");
            n++;
        } while (GLib.FileUtils.test (build_media_filename (filename, type, ext), FileTest.EXISTS));

        return build_media_filename (filename, type, ext);
    }

    /**
     * @return a valid photo/video filename.
     */
    public string build_media_filename (string filename, Camera.ActionType type, string? ext = null) {
        string new_filename = filename;
        if (ext == null) {
            if (type == Camera.ActionType.PHOTO)
                new_filename += ".jpg";
            else if (type == Camera.ActionType.VIDEO)
                new_filename += ".mp4";
        } else {
            new_filename += "." + ext;
        }
        
        string media_dir = get_media_dir (type);
        if (!FileUtils.test (media_dir, FileTest.EXISTS))
            DirUtils.create (media_dir, 0777);
        
        return GLib.Path.build_filename (Path.DIR_SEPARATOR_S, media_dir, new_filename);
    }
    
    /**
     * @return a valid photo/video uri.
     */
    public string build_uri_from_filename (string filename) {        
        var file = File.new_for_path (filename);
        
        return file.get_uri ();
    }
    
    /** Thumbnail providers **/
    public ThumbnailProvider photo_thumb_provider;
    public ThumbnailProvider video_thumb_provider;

    /**
     * @param surface_size size of the new pixbuf. Set a value of 0 to use the pixbuf's natural size.
     **/
    public Gdk.Pixbuf get_pixbuf_shadow (Gdk.Pixbuf pixbuf, int surface_size,
                                          int shadow_size = 5, double alpha = 0.8) {

        int S_WIDTH = (surface_size > 0)? surface_size : pixbuf.width;
        int S_HEIGHT = (surface_size > 0)? surface_size : pixbuf.height;

        var buffer_surface = new Granite.Drawing.BufferSurface(S_WIDTH, S_HEIGHT);

        S_WIDTH -= 2 * shadow_size;
        S_HEIGHT -= 2 * shadow_size;

        buffer_surface.context.rectangle (shadow_size, shadow_size, S_WIDTH, S_HEIGHT);
        buffer_surface.context.set_source_rgba (0, 0, 0, alpha);
        buffer_surface.context.fill();
        buffer_surface.fast_blur(2, 3);
        Gdk.cairo_set_source_pixbuf(buffer_surface.context, pixbuf.scale_simple (S_WIDTH, S_HEIGHT, Gdk.InterpType.BILINEAR), shadow_size, shadow_size);
        buffer_surface.context.paint();

        return buffer_surface.load_to_pixbuf();
    }

    /**
     * Launch a file with its default handler
     */
    public void launch_file (File file) {
        try {
            var handler = file.query_default_handler (null);
            var list = new GLib.List<File> ();
            list.append (file);
            handler.launch (list, null);
        } catch (Error err) {
            warning (err.message);
        }
    }
}
