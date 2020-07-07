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
    private Gst.Bin? record_bin;

    private Camera.CameraInfo[] infos = {};
    public bool recording { get; private set; default = false; }

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

        status_grid = new Gtk.Grid () {
            column_spacing = 6,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };
        status_grid.add (spinner);
        status_grid.add (status_label);

        no_device_view = new Granite.Widgets.AlertView (
            _("No Supported Camera Found"),
            _("Connect a webcam or other supported video device to take photos and video."),
            ""
        );

        add (status_grid);
        add (no_device_view);

        if (infos.length == 0) {
            visible_child = no_device_view;
            return;
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
        visible_child = status_grid;

        status_label.label = _("Connecting to \"%s\"…").printf (infos[camera_number].name);
        v4l2src["device"] = "/dev/%s".printf (infos[camera_number].path);

        try {
            pipeline = (Gst.Pipeline) Gst.parse_launch (
                "v4l2src name=v4l2src ! " +
                "videoflip method=horizontal-flip ! " +
                "tee name=tee ! " +
                "queue leaky=downstream max-size-buffers=10 ! " +
                "videoconvert ! " +
                "videoscale ! " +
                "gtksink name=gtksink"
            );
            pipeline.set_state (Gst.State.NULL);

            v4l2src = pipeline.get_by_name ("v4l2src");
            tee = pipeline.get_by_name ("tee");

            var gtksink = pipeline.get_by_name ("gtksink");
            gtksink.get ("widget", out video_widget);

            video_widget.expand = true;

            add (video_widget);

            visible_child = video_widget;
            pipeline.set_state (Gst.State.PLAYING);
        } catch (Error e) {
            visible_child = no_device_view;

            var dialog = new Granite.MessageDialog.with_image_from_icon_name (_("Unable To View Camera"), e.message, "dialog-error");
            dialog.run ();
            dialog.destroy ();
        }
    }

    public void take_photo () {
        if (recording) {
            return;
        }

        recording = true;
        var snap_bin = new Gst.Bin (null);

        string[] missing_messages = {};
        var queue = Gst.ElementFactory.make ("queue", null);
        if (queue == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("queue");
        }

        var videoconvert = Gst.ElementFactory.make ("videoconvert", null);
        if (videoconvert == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("videoconvert");
        }

        var encoder = Gst.ElementFactory.make ("jpegenc", null);
        if (encoder == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("jpegenc");
        }

        var filesink = Gst.ElementFactory.make ("filesink", null);
        if (filesink == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("filesink");
        } else {
            filesink["buffer-size"] = 1;
            filesink["location"] = Camera.Utils.get_new_media_filename (Camera.Utils.ActionType.PHOTO);
            filesink.get_static_pad ("sink").add_probe (Gst.PadProbeType.BUFFER, (pad, info) => {
                Idle.add (() => {
                    pipeline.set_state (Gst.State.PAUSED);
                    pipeline.remove (snap_bin);
                    pipeline.set_state (Gst.State.PLAYING);
                    recording = false;
                    return GLib.Source.REMOVE;
                });

                return Gst.PadProbeReturn.REMOVE;
            });
        }

        if (missing_messages.length > 0) {
            Gst.PbUtils.install_plugins_async (missing_messages, null, (result) => {});
            recording = false;
            return;
        }

        snap_bin.add_many (queue, videoconvert, encoder, filesink);
        queue.link_many (videoconvert, encoder, filesink);

        var ghostpad = new Gst.GhostPad (null, queue.get_static_pad ("sink"));
        snap_bin.add_pad (ghostpad);

        pipeline.set_state (Gst.State.PAUSED);
        pipeline.add (snap_bin);
        snap_bin.sync_state_with_parent ();
        tee.link (snap_bin);
        pipeline.set_state (Gst.State.PLAYING);
        Gst.Debug.BIN_TO_DOT_FILE (pipeline, Gst.DebugGraphDetails.VERBOSE, "snapshot");
        play_shutter_sound ();
    }

    public void start_recording () {
        if (recording) {
            return;
        }

        recording = true;
        record_bin = new Gst.Bin (null);

        string[] missing_messages = {};
        var queue = Gst.ElementFactory.make ("queue", null);
        var videoconvert = Gst.ElementFactory.make ("videoconvert", null);
        if (videoconvert == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("videoconvert");
        }

        var encoder = Gst.ElementFactory.make ("vp8enc", null);
        if (encoder == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("vp8enc");
        }

        var muxer = Gst.ElementFactory.make ("webmmux", null);
        if (muxer == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("webmmux");
        }

        var filesink = Gst.ElementFactory.make ("filesink", null);
        if (filesink == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("filesink");
        } else {
            filesink["location"] = Camera.Utils.get_new_media_filename (Camera.Utils.ActionType.VIDEO);
        }

        if (missing_messages.length > 0) {
            Gst.PbUtils.install_plugins_async (missing_messages, null, (result) => {});
            recording = false;
            return;
        }

        record_bin.add_many (queue, videoconvert, encoder, muxer, filesink);
        queue.link_many (videoconvert, encoder, muxer, filesink);

        var ghostpad = new Gst.GhostPad (null, queue.get_static_pad ("sink"));
        record_bin.add_pad (ghostpad);

        pipeline.set_state (Gst.State.PAUSED);
        pipeline.add (record_bin);
        record_bin.sync_state_with_parent ();
        tee.link (record_bin);
        pipeline.set_state (Gst.State.PLAYING);
        Gst.Debug.BIN_TO_DOT_FILE (pipeline, Gst.DebugGraphDetails.VERBOSE, "recording");
    }

    public void stop_recording () {
        if (!recording) {
            return;
        }

        pipeline.set_state (Gst.State.PAUSED);
        tee.unlink (record_bin);
        pipeline.remove (record_bin);
        pipeline.set_state (Gst.State.PLAYING);
        record_bin.set_state (Gst.State.PLAYING);
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
