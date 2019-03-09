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

private struct Camera.CameraInfo {
    public string name;
    public string path;
}

public class Camera.Widgets.CameraView : Gtk.Stack {
    private Gtk.Widget video_widget;
    private Gtk.Grid status_grid;
    private Granite.Widgets.AlertView no_device_view;
    private Gtk.Label status_label;

    private Gst.Pipeline pipeline;
    private Gst.Element v4l2src;
    private Gst.Element tee;

    private Camera.CameraInfo[] infos = {};

    public CameraView () {
        var v4ldir = GLib.File.new_for_path ("/sys/class/video4linux/");
        try {
            var enumerator = v4ldir.enumerate_children (GLib.FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE, null);
            GLib.FileInfo fileinfo;
            while ((fileinfo = enumerator.next_file ()) != null) {
                unowned string filename = fileinfo.get_name ();
                var name_path = v4ldir.resolve_relative_path (filename).get_child ("name").get_path ();
                string content;
                size_t length;
                try {
                    GLib.FileUtils.get_contents (name_path, out content, out length);
                    content = content.replace ("\n", "").strip ();
                } catch (Error e) {
                    critical (e.message);
                    content = _("Camera %u").printf (infos.length + 2);
                }

                var info = Camera.CameraInfo () {
                    name = content,
                    path = fileinfo.get_name ()
                };
                infos += info;
            }
        } catch (Error e) {
            critical (e.message);
        }

        var spinner = new Gtk.Spinner ();
        spinner.active = true;

        status_label = new Gtk.Label (null);

        status_grid = new Gtk.Grid ();
        status_grid.row_spacing = 6;
        status_grid.orientation = Gtk.Orientation.VERTICAL;
        status_grid.halign = Gtk.Align.CENTER;
        status_grid.valign = Gtk.Align.CENTER;
        status_grid.add (spinner);
        status_grid.add (status_label);
        add_named (status_grid, "status");

        no_device_view = new Granite.Widgets.AlertView (_("No Supported Camera Found"),
                                                        _("Connect a webcam or other supported video device to take photos and video."),
                                                        "accessories-camera");
        add_named (no_device_view, "no-device");

        if (infos.length == 0) {
            visible_child = no_device_view;
            return;
        }

        try {
            pipeline = Gst.parse_launch ("v4l2src name=v4l2src ! autovideoconvert ! videoscale ! videoflip method=horizontal-flip ! queue ! tee name=tee ! gtksink name=gtksink") as Gst.Pipeline;
            v4l2src = pipeline.get_by_name ("v4l2src");
            tee = pipeline.get_by_name ("tee");
            var gtksink = pipeline.get_by_name ("gtksink");
            gtksink.get ("widget", out video_widget);
            video_widget.expand = true;
            add_named (video_widget, "video");
            visible_child = status_grid;
        } catch (Error e) {
            critical (e.message);
        }
    }

    public int get_cameras () {
        return infos.length;
    }

    public unowned string? get_camera_name (int camera_number) {
        if (camera_number < 0 || camera_number > infos.length) {
            return null;
        }

        return infos[camera_number].name;
    }

    public void start_view (int camera_number) {
        pipeline.set_state (Gst.State.NULL);
        visible_child = status_grid;
        if (camera_number < 0 || camera_number > infos.length) {
            return;
        }

        status_label.label = _("Connecting to \"%s\"…").printf (infos[camera_number].name);
        v4l2src["device"] = "/dev/%s".printf (infos[camera_number].path);
        visible_child = video_widget;
        pipeline.set_state (Gst.State.PLAYING);
    }

    public bool take_photo () {
        /*if (!this.is_ready_for_capture () || this.is_recording_video ()) {
            warning ("Device isn't ready for taking photos.");

            return false;
        }

        base.take_photo (Utils.get_new_media_filename (Utils.ActionType.PHOTO));*/
        play_shutter_sound ();

        return true;
    }

    public bool start_recording () {
        /*if (!this.is_ready_for_capture () || this.is_recording_video ()) {
            warning ("Device isn't ready for recording videos.");

            return false;
        }

        this.start_video_recording (Utils.get_new_media_filename (Utils.ActionType.VIDEO));*/

        return true;
    }

    public void stop_recording () {
        /*if (!this.is_recording_video ()) {
            warning ("Cannot stop recording because no record is running.");

            return;
        }

        this.stop_video_recording ();*/
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
