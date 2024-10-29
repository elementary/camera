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

public class Camera.Widgets.CameraView : Gtk.Box {
    private const string VIDEO_SRC_NAME = "v4l2src";
    public signal void recording_finished (string file_path);

    private Gtk.Stack stack;
    private Gtk.Box status_box;
    private Granite.Placeholder no_device_view;
    private Gtk.Label status_label;
    private Gtk.Picture picture;

    private Gst.Pipeline pipeline;
    private Gst.Element tee;
    private Gst.Video.ColorBalance color_balance;
    private Gst.Video.Direction? hflip;
    private Gst.Bin? record_bin;
    private Gst.Device? current_device = null;
    private uint init_device_timeout_id = 0;

    public uint n_cameras {
        get {
            return monitor.get_devices ().length ();
        }
    }

    private int picture_width;
    private int picture_height;

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
        var spinner = new Gtk.Spinner () {
            spinning = true
        };

        status_label = new Gtk.Label (null);

        status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };
        status_box.append (spinner);
        status_box.append (status_label);

        no_device_view = new Granite.Placeholder (_("No Supported Camera Found")) {
            description = _("Connect a webcam or other supported video device to take photos and video.")
        };

        picture = new Gtk.Picture () {
            content_fit = CONTAIN,
            hexpand = true,
            vexpand = true
        };

        stack = new Gtk.Stack ();
        stack.add_child (status_box);
        stack.add_child (no_device_view);
        stack.add_child (picture);

        monitor.get_bus ().add_watch (GLib.Priority.DEFAULT, on_bus_message);

        append (stack);

        var caps = new Gst.Caps.empty_simple ("video/x-raw");
        caps.append (new Gst.Caps.empty_simple ("image/jpeg"));
        monitor.add_filter ("Video/Source", caps);

        init_device_timeout_id = Timeout.add_seconds (2, () => {
            if (n_cameras == 0) {
                no_device_view.show ();
                stack.visible_child = no_device_view;
            }
            return Source.REMOVE;
        });
    }

    private void on_camera_added (Gst.Device device) {
        if (init_device_timeout_id > 0) {
            Source.remove (init_device_timeout_id);
            init_device_timeout_id = 0;
        }
        camera_added (device);
        change_camera (device);
    }
    private void on_camera_removed (Gst.Device device) {
        camera_removed (device);
        if (n_cameras == 0) {
            no_device_view.show ();
            stack.visible_child = no_device_view;
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
        stack.visible_child = status_box;
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
        current_device = camera;

        ((Camera.MainWindow) this.get_root ()).change_action_state (
            Camera.MainWindow.ACTION_CHANGE_CAMERA,
            new Variant.string (camera.name)
        );
    }

    private void create_pipeline (Gst.Device camera) {
        try {
            var caps = camera.get_caps ();
            picture_width = 640;
            picture_height = 480;
            var max_area = picture_width * picture_height;

            for (uint i = 0; i < caps.get_size (); i++) {
                unowned var s = caps.get_structure (i);
                if (s.get_name () == "image/jpeg") {
                    int w, h;
                    s.get_int ("width", out w);
                    s.get_int ("height", out h);
                    if (w * h > max_area) {
                        picture_width = w;
                        picture_height = h;
                        max_area = w * h;
                    }
                }
            }

            var device_src = camera.create_element (VIDEO_SRC_NAME);
            pipeline = (Gst.Pipeline) Gst.parse_launch (
                "decodebin name=decodebin ! " +
                "videoflip method=horizontal-flip name=hflip ! " +
                "videobalance name=balance ! " +
                "tee name=tee ! " +
                "videorate name=videorate ! " +
                "queue leaky=downstream max-size-buffers=10 ! " +
                "videoconvert ! " +
                "videoscale name=videoscale"
            );

            pipeline.add (device_src);
            device_src.link (pipeline.get_by_name ("decodebin"));
            tee = pipeline.get_by_name ("tee");
            hflip = (pipeline.get_by_name ("hflip") as Gst.Video.Direction);
            color_balance = (pipeline.get_by_name ("balance") as Gst.Video.ColorBalance);

            dynamic Gst.Element videorate = pipeline.get_by_name ("videorate");
            videorate.max_rate = 30;
            videorate.drop_only = true;

            dynamic Gst.Element gtksink = Gst.ElementFactory.make ("gtk4paintablesink", "sink");

            pipeline.add (gtksink);
            pipeline.get_by_name ("videoscale").link (gtksink);

            Gdk.Paintable gst_video_widget;
            gtksink.get ("paintable", out gst_video_widget);

            picture.paintable = gst_video_widget;

            stack.visible_child = picture;
            pipeline.set_state (Gst.State.PLAYING);
        } catch (Error e) {
            // It is possible that there is another camera present that could selected so do not show
            // no_device_view
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Unable To View Camera"),
                e.message,
                "dialog-error"
            );
            dialog.present ();
            dialog.response.connect (dialog.destroy);
        }
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
        pipeline.set_state (Gst.State.NULL);
        pipeline.sync_children_states ();

        var preview_video_src = (Gst.Element) pipeline.get_by_name (VIDEO_SRC_NAME);
        string device_path;
        preview_video_src.get ("device", out device_path);
        var brightness_value = GLib.Value (typeof (double));
        color_balance.get_property ("brightness", ref brightness_value);
        var contrast_value = GLib.Value (typeof (double));
        color_balance.get_property ("contrast", ref contrast_value);
        Gst.Pipeline picture_pipeline;
        try {
             picture_pipeline = (Gst.Pipeline) Gst.parse_launch (
                "v4l2src device=%s name=%s num-buffers=1 !".printf (device_path, VIDEO_SRC_NAME) +
                "videoscale ! video/x-raw, width=%d, height=%d !".printf (picture_width, picture_height) +
                "videoflip method=%s !".printf ((horizontal_flip)?"horizontal-flip":"none") +
                "videobalance brightness=%f contrast=%f !".printf (brightness_value.get_double (), contrast_value.get_double ()).delimit (null, '.') +
                "jpegenc ! filesink location=%s name=filesink".printf (Camera.Utils.get_new_media_filename (Camera.Utils.ActionType.PHOTO))
            );
        } catch (Error e) {
            warning ("Could not make picture pipeline for photo - %s", e.message);
            return;
        }

        var filesink = picture_pipeline.get_by_name ("filesink");
        filesink.get_static_pad ("sink").add_probe (Gst.PadProbeType.EVENT_DOWNSTREAM, (pad, info) => {
            if (info.get_event ().type == Gst.EventType.EOS) {
                Idle.add (() => {
                    picture_pipeline.set_state (Gst.State.NULL);
                    play_shutter_sound ();
                    create_pipeline (current_device);

                    recording = false;
                    return Source.REMOVE;
                });

                return Gst.PadProbeReturn.REMOVE;
            }

            return Gst.PadProbeReturn.PASS;
        });

        picture_pipeline.set_state (Gst.State.PLAYING);
        picture_pipeline.sync_children_states ();

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
