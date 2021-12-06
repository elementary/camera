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
    public signal void recording_finished (string file_path);

    private Gtk.Grid status_grid;
    private Granite.Widgets.AlertView no_device_view;
    private Gtk.Label status_label;
    Gtk.Widget gst_video_widget;

    private Gst.Pipeline pipeline;
    private Gst.Element tee;
    private Gst.Video.ColorBalance color_balance;
    private Gst.Video.Direction? hflip;
    private Gst.Bin? record_bin;

    public uint n_cameras {
        get {
            return monitor.get_devices ().length ();
        }
    }

    private Gst.DeviceMonitor monitor = new Gst.DeviceMonitor ();
    public bool recording { get; private set; default = false; }
    public bool horizontal_flip {
        get {
            if (hflip == null) {
                return true;
            }

            return hflip.video_direction == Gst.Video.OrientationMethod.HORIZ;
        }
        set {
            if (hflip == null) {
                return;
            }

            if (hflip.video_direction == Gst.Video.OrientationMethod.IDENTITY) {
                hflip.video_direction = Gst.Video.OrientationMethod.HORIZ;
            } else {
                hflip.video_direction = Gst.Video.OrientationMethod.IDENTITY;
            }
        }
    }

    public signal void camera_added (Gst.Device camera);
    public signal void camera_removed (Gst.Device camera);

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

    private void on_camera_added (Gst.Device device) {
        camera_added (device);
        change_camera (device);
    }
    private void on_camera_removed (Gst.Device device) {
        camera_removed (device);
        if (n_cameras == 0) {
            no_device_view.show ();
            visible_child = no_device_view;
        } else {
            change_camera (monitor.get_devices ().nth_data (0));
        }
    }

    private bool on_bus_message (Gst.Bus bus, Gst.Message message) {
        switch (message.type) {
            case DEVICE_ADDED:
                Gst.Device device;
                message.parse_device_added (out device);
                on_camera_added (device);

                break;
            case DEVICE_CHANGED:
                Gst.Device device, changed_device;
                message.parse_device_changed (out device, out changed_device);
                on_camera_removed (changed_device);
                on_camera_added (device);

                break;
            case DEVICE_REMOVED:
                Gst.Device device;
                message.parse_device_removed (out device);
                on_camera_removed (device);

                break;
            default:
                break;
        }

        return GLib.Source.CONTINUE;
    }

    public void start () {
        monitor.get_devices ().foreach ((dev) => {
            on_camera_added (dev);
        });
        monitor.start ();
    }

    public void change_camera (Gst.Device camera) {
        visible_child = status_grid;
        status_label.label = _("Connecting to \"%s\"…").printf (camera.display_name);

        if (recording) {
            stop_recording ();
        }

        if (record_bin != null) {
            record_bin.set_state (Gst.State.NULL);
            record_bin.sync_state_with_parent ();
            record_bin.sync_children_states ();
        }

        if (pipeline != null) {
            pipeline.set_state (Gst.State.NULL);
            pipeline.sync_children_states ();

            Gst.Debug.BIN_TO_DOT_FILE (pipeline, Gst.DebugGraphDetails.VERBOSE, "changing");
        }

        create_pipeline (camera);
    }

    private void create_pipeline (Gst.Device camera) {
        unowned Gst.Element? camera_element = camera.create_element (null);
        var capsfilter = Gst.ElementFactory.make ("capsfilter", null);
        var filtered_caps = camera.caps.copy ();
        filtered_caps.filter_and_map_in_place ((features, structure) => {
            int value_numerator, value_denominator;
            unowned var val = structure.get_value ("framerate");
            if (val != null && val.holds (typeof (Gst.ValueList))) {
                uint max_size = Gst.ValueList.get_size (val);
                for (uint i = 0; i < max_size; i++) {
                    unowned Value? subval =  Gst.ValueList.get_value (val, i);
                    value_denominator = Gst.Value.get_fraction_denominator (subval);
                    value_numerator = Gst.Value.get_fraction_numerator (subval);
                    if ((double)value_numerator / (double)value_denominator >= 24.0f) {
                        return true;
                    }
                }

                return false;
            } else if (structure.get_fraction ("framerate", out value_numerator, out value_denominator)) {
                if ((double)value_numerator / (double)value_denominator >= 24.0f) {
                    return true;
                } else {
                    return false;
                }
            }

            return false;
        });

        // A laggy preview is better than an empty preview
        if (filtered_caps.is_empty ()) {
            debug ("No matching framerate, using any possible one");
            filtered_caps = camera.caps;
        }

        capsfilter.set ("caps", filtered_caps);
        var videoflip = Gst.ElementFactory.make ("videoflip", null);
        hflip = videoflip as Gst.Video.Direction;
        hflip.video_direction = Gst.Video.OrientationMethod.HORIZ;
        var videobalance = Gst.ElementFactory.make ("videobalance", null);
        color_balance = videobalance as Gst.Video.ColorBalance;
        tee = Gst.ElementFactory.make ("tee", null);
        var queue = Gst.ElementFactory.make ("queue", null);
        queue.set ("leaky", 2 /* downstream */, "max-size-buffers", 10);
        var videoconvert = Gst.ElementFactory.make ("videoconvert", null);
        var videoscale = Gst.ElementFactory.make ("videoscale", null);

        pipeline = new Gst.Pipeline (null);
        pipeline.add_many (camera_element, capsfilter, videoflip, videobalance, tee, queue, videoconvert, videoscale);
        camera_element.link_many (capsfilter, videoflip, videobalance, tee, queue, videoconvert, videoscale);

        var gtksink = Gst.ElementFactory.make ("gtkglsink", null);
        if (gtksink != null) {
            var glsinkbin = Gst.ElementFactory.make ("glsinkbin", null);
            glsinkbin.set ("sink", gtksink);
            pipeline.add (glsinkbin);
            videoscale.link (glsinkbin);
        } else {
            gtksink = Gst.ElementFactory.make ("gtksink", null);
            pipeline.add (gtksink);
            videoscale.link (gtksink);
        }

        if (gst_video_widget != null) {
            remove (gst_video_widget);
        }

        gtksink.get ("widget", out gst_video_widget);

        add (gst_video_widget);
        gst_video_widget.show ();

        visible_child = gst_video_widget;
        pipeline.set_state (Gst.State.PLAYING);
    }

    public void change_color_balance (double brightnesss, double contrast) {
        color_balance.set_property ("brightness", brightnesss);
        color_balance.set_property ("contrast", contrast);
    }

    public void take_photo () {
        if (recording || pipeline == null) {
            return;
        }

        recording = true;
        var picture_bin = new Gst.Bin (null);
        picture_bin.set ("message-forward", true);

        string[] missing_messages = {};
        var queue = Gst.ElementFactory.make ("queue", null);

        var jpegenc = Gst.ElementFactory.make ("jpegenc", null);
        if (jpegenc == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("jpegenc");
        } else {
            jpegenc.set ("snapshot", true);
        }

        var filesink = Gst.ElementFactory.make ("filesink", "filesink");
        if (filesink == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("filesink");
        } else {
            filesink["location"] = Camera.Utils.get_new_media_filename (Camera.Utils.ActionType.PHOTO);
        }

        if (missing_messages.length > 0) {
            Gst.PbUtils.install_plugins_async (missing_messages, null, (result) => {});
            recording = false;
            return;
        }

        picture_bin.add_many (queue, jpegenc, filesink);
        queue.link_many (jpegenc, filesink);

        var ghostpad = new Gst.GhostPad (null, queue.get_static_pad ("sink"));
        picture_bin.add_pad (ghostpad);

        pipeline.set_state (Gst.State.PAUSED);
        pipeline.add (picture_bin);
        tee.link (picture_bin);
        picture_bin.sync_state_with_parent ();
        pipeline.get_bus ().add_watch (GLib.Priority.DEFAULT, (bus, message) => {
            unowned Gst.Structure? structure = message.get_structure ();
            if (message.type == Gst.MessageType.ELEMENT && structure.has_name ("GstBinForwarded")) {
                Gst.Message fwd_msg;
                structure.get ("message", typeof (Gst.Message), out fwd_msg, null);
                if (fwd_msg.type == Gst.MessageType.EOS) {
                    var peer = ghostpad.get_peer ();
                    tee.unlink (picture_bin);
                    pipeline.set_state (Gst.State.NULL);
                    tee.release_request_pad (peer);
                    pipeline.remove (picture_bin);
                    pipeline.set_state (Gst.State.PLAYING);
                    Gst.Debug.BIN_TO_DOT_FILE (pipeline, Gst.DebugGraphDetails.VERBOSE, "snapshoted");
                    play_shutter_sound ();
                    recording = false;
                    return GLib.Source.REMOVE;
                }
            }

            return GLib.Source.CONTINUE;
        });

        pipeline.set_state (Gst.State.PLAYING);

        Gst.Debug.BIN_TO_DOT_FILE (pipeline, Gst.DebugGraphDetails.VERBOSE, "snapshot");
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

        var alsasrc = Gst.ElementFactory.make ("alsasrc", null);
        if (alsasrc == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("alsasrc");
        }

        var audio_queue = Gst.ElementFactory.make ("queue", null);

        var audio_convert = Gst.ElementFactory.make ("audioconvert", null);
        if (audio_convert == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("audioconvert");
        }

        var audio_vorbis = Gst.ElementFactory.make ("vorbisenc", null);
        if (audio_vorbis == null) {
            missing_messages += Gst.PbUtils.missing_element_installer_detail_new ("vorbisenc");
        }

        var filesink = Gst.ElementFactory.make ("filesink", "filesink");
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

        record_bin.add_many (alsasrc, audio_queue, audio_convert, audio_vorbis);
        alsasrc.link_many (audio_queue, audio_convert, audio_vorbis, muxer);

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
        var filesink = record_bin.get_by_name ("filesink");

        if (filesink != null) {
            var locationval = GLib.Value (typeof (string));
            filesink.get_property ("location", ref locationval);
            string location = locationval.get_string ();
            recording_finished (location);
        }

        pipeline.remove (record_bin);
        pipeline.set_state (Gst.State.PLAYING);
        record_bin.set_state (Gst.State.NULL);
        record_bin.dispose ();
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
