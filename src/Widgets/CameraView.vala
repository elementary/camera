/*
 * Copyright (c) 2011-2019 elementary, inc. (https://elementary.io)
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
 *              Corentin Noël <corentin@elementary.io>
 */

public class Camera.Widgets.CameraView : Gtk.Stack {
    private Granite.Widgets.AlertView no_device_view;
    private GtkClutter.Embed embed_view;
    private Clutter.Actor video_preview;

    public bool recording { get; private set; default = false; }

    private Cheese.Camera camera;

    public CameraView () {
        no_device_view = new Granite.Widgets.AlertView (
            _("No Supported Camera Found"),
            _("Connect a webcam or other supported video device to take photos and video."),
            ""
        );

        embed_view = new GtkClutter.Embed ();
        video_preview = new Clutter.Actor () {
            x_expand = true,
            y_expand = true,
            min_height = 75,
            min_width = 100
        };

        embed_view.get_stage ().add_child (video_preview);

        add (embed_view);
        add (no_device_view);

        camera = new Cheese.Camera (video_preview, null, 640, 480);

        try {
            camera.setup ();
            camera.play ();
        } catch (Error e) {
            warning ("Error initializing camera: %s", e.message);
            camera = null;
        }

        if (get_cameras () > 0) {
            visible_child = embed_view;
        } else {
            visible_child = no_device_view;
        }
    }

    public uint get_cameras () {
        if (camera != null) {
            return camera.num_camera_devices;
        }

        return 0;
    }

    public void start_view (int camera_number) {

    }

    public void take_photo () {
        if (recording) {
            return;
        }

        recording = true;

        play_shutter_sound ();
    }

    public void start_recording () {
        if (recording) {
            return;
        }

        recording = true;

    }

    public void stop_recording () {
        if (!recording) {
            return;
        }

        recording = false;
    }

    private static void play_shutter_sound () {
        Canberra.Context context;
        Canberra.Proplist props;

        Canberra.Context.create (out context);
        Canberra.Proplist.create (out props);

        props.sets (Canberra.PROP_EVENT_ID, "camera-shutter");
        props.sets (Canberra.PROP_EVENT_DESCRIPTION, _("Photo taken"));
        props.sets (Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");
        props.sets (Canberra.PROP_MEDIA_ROLE, "event");

        context.play_full (0, props, null);
    }
}
