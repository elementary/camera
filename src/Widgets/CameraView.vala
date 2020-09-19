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
    private Gtk.Grid status_grid;
    private Granite.Widgets.AlertView no_device_view;
    private Gtk.Label status_label;

    private Gst.Pipeline pipeline;
    private Gst.Element tee;
    private Gst.Video.Direction hflip;
    private Gst.Video.ColorBalance color_balance;
    private Gst.Bin? record_bin;

    private Gst.DeviceMonitor monitor = new Gst.DeviceMonitor ();
    private GenericArray<Gst.Device> cameras = new GenericArray<Gst.Device> ();
    public bool recording { get; private set; default = false; }

    construct {
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

        monitor.get_bus ().add_watch (GLib.Priority.DEFAULT, on_bus_message);

        var caps = new Gst.Caps.empty_simple ("video/x-raw");
        monitor.add_filter ("Video/Source", caps);
    }

    private void on_device_added (owned Gst.Device device) {
        cameras.add ((owned) device);
        if (cameras.length == 1) {
            start_view (0);
        }
    }

    private bool on_bus_message (Gst.Bus bus, Gst.Message message) {
        switch (message.type) {
            case DEVICE_ADDED:
                Gst.Device device;
                message.parse_device_added (out device);
                on_device_added ((owned) device);

                break;
            case DEVICE_CHANGED:
                Gst.Device device, changed_device;
                message.parse_device_changed (out device, out changed_device);
                cameras.remove ((owned) changed_device);
                cameras.add ((owned) device);
                break;
            case DEVICE_REMOVED:
                Gst.Device device;
                message.parse_device_removed (out device);
                cameras.remove ((owned) device);
                if (cameras.length == 0) {
                    visible_child = no_device_view;
                }

                break;
            default:
                break;
        }

        return GLib.Source.CONTINUE;
    }

    public void start () {
        monitor.get_devices ().foreach ((dev) => {on_device_added (dev);});
        monitor.start ();

        if (cameras.length == 0) {
            visible_child = no_device_view;
        }
    }

    public void start_view (int camera_number) {
        unowned Gst.Device camera = cameras[camera_number];
        visible_child = status_grid;

        status_label.label = _("Connecting to \"%s\"…").printf (camera.display_name);

        try {
            pipeline = (Gst.Pipeline) Gst.parse_launch (
                "v4l2src device=%s name=v4l2src !".printf (camera.get_properties ().get_string ("device.path")) +
                "video/x-raw, width=640, height=480, framerate=30/1 ! " +
                "videoflip method=horizontal-flip name=hflip ! " +
                "videobalance name=balance ! " +
                "tee name=tee ! " +
                "queue leaky=downstream max-size-buffers=10 ! " +
                "videoconvert ! " +
                "videoscale ! " +
                "gtksink name=gtksink"
            );

            tee = pipeline.get_by_name ("tee");
            hflip = (pipeline.get_by_name ("hflip") as Gst.Video.Direction);
            color_balance = (pipeline.get_by_name ("balance") as Gst.Video.ColorBalance);

            var gtksink = pipeline.get_by_name ("gtksink");
            Gtk.Widget gst_video_widget;
            gtksink.get ("widget", out gst_video_widget);

            add (gst_video_widget);
            gst_video_widget.show ();

            visible_child = gst_video_widget;
            pipeline.set_state (Gst.State.PLAYING);
        } catch (Error e) {
            visible_child = no_device_view;

            var dialog = new Granite.MessageDialog.with_image_from_icon_name (_("Unable To View Camera"), e.message, "dialog-error");
            dialog.run ();
            dialog.destroy ();
        }
    }

    public void change_color_balance (double brightnesss, double contrast) {
        color_balance.set_property ("brightness", brightnesss);
        color_balance.set_property ("contrast", contrast);
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
