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
    private const string VIDEO_SRC_NAME = "v4l2src";
    public signal void recording_finished (string file_path);

    private Gtk.Box status_box;
    private Granite.Widgets.AlertView no_device_view;
    private Gtk.Label status_label;
    Gtk.Widget gst_video_widget;

    private Gst.Pipeline preview_pipeline;
    private Gst.Video.ColorBalance color_balance;
    private Gst.Video.Direction? hflip;
    private Gst.Device? current_device = null;
    private int current_video_caps_index = -1;
    private int default_video_caps_index = -1;
    private int current_picture_caps_index = -1;

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

        status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };
        status_box.pack_start (spinner);
        status_box.pack_start (status_label);

        no_device_view = new Granite.Widgets.AlertView (
            _("No Supported Camera Found"),
            _("Connect a webcam or other supported video device to take photos and video."),
            ""
        );

        add (status_box);
        add (no_device_view);
        monitor.get_bus ().add_watch (GLib.Priority.DEFAULT, on_bus_message);

        var caps = new Gst.Caps.empty_simple ("video/x-raw");
        monitor.add_filter ("Video/Source", caps);

        Camera.Application.settings.changed["mode"].connect (() => {
            if (current_device == null) {
                return;
            } else if (Camera.Application.settings.get_enum ("mode") == Utils.ActionType.PHOTO) {

                set_preview_caps (default_video_caps_index);
                update_resolution_action_state (current_picture_caps_index);
            } else {
                set_preview_caps (current_video_caps_index);
                update_resolution_action_state (current_video_caps_index);
            }
        });
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
        visible_child = status_box;
        status_label.label = _("Connecting to \"%s\"…").printf (camera.display_name);

        if (recording) {
            stop_recording ();
        }

        if (preview_pipeline != null) {
            preview_pipeline.set_state (Gst.State.NULL);
            preview_pipeline.sync_children_states ();

            Gst.Debug.BIN_TO_DOT_FILE (preview_pipeline, Gst.DebugGraphDetails.VERBOSE, "changing");
        }

        var caps = camera.get_caps ();
        int largest_picture_index = -1;
        int largest_video_index = -1;
        var max_area_picture = 640 * 480;
        var max_area_video = 320 * 240;

        if (caps != null) {
            for (int i = 0; i < caps.get_size (); i++) {
                unowned var s = caps.get_structure (i);
                int w, h;
                double fr = 0.0;
                if (Camera.Utils.parse_structure (s, out w, out h, out fr)) {
                    if (s.get_name () == "image/jpeg") {
                        if (w * h > max_area_picture) {
                            largest_picture_index = i;
                            max_area_picture = w * h;
                        }
                    } else if (s.get_name () == "video/x-raw") {
                        if (w * h >= max_area_video && fr >= 10.0) {
                            largest_video_index = i;
                            max_area_video = w * h;
                        }
                    }
                }
            }
        }

        current_picture_caps_index = largest_picture_index;
        current_video_caps_index = largest_video_index;
        default_video_caps_index = largest_video_index;

        current_device = camera;
        create_video_pipeline ();
    }

    private void create_video_pipeline () {
        try {
            var device_src = current_device.create_element (VIDEO_SRC_NAME);
            preview_pipeline = (Gst.Pipeline) Gst.parse_launch (
                "capsfilter name=capsfilter ! " +
                "decodebin name=decodebin ! " +
                "videoflip method=horizontal-flip name=hflip ! " +
                "videobalance name=balance ! " +
                "tee name=tee ! " +
                "videorate name=videorate ! " +
                "queue leaky=downstream max-size-buffers=10 ! " +
                "videoconvert ! " +
                "videoscale name=videoscale"
            );

            preview_pipeline.add (device_src);
            dynamic Gst.Element capsfilter = preview_pipeline.get_by_name ("capsfilter");
            device_src.link (capsfilter);

            // Ensure action state changes with caps filter
            capsfilter.get_static_pad ("src").add_probe (Gst.PadProbeType.EVENT_BOTH, (pad, info) => {
                unowned Gst.Event? event = info.get_event ();
                if (event.type == Gst.EventType.CAPS) {
                    unowned var s= event.get_structure ();
                    update_resolution_action_state (find_structure_index (s));
                }

                return Gst.PadProbeReturn.OK;
            });

            var default_caps = get_caps_from_index (default_video_caps_index);
            if (default_caps != null) {
                capsfilter.caps = default_caps;
            } else {
                critical ("Could not find default caps from index %u", default_video_caps_index);
            }

            hflip = (preview_pipeline.get_by_name ("hflip") as Gst.Video.Direction);
            color_balance = (preview_pipeline.get_by_name ("balance") as Gst.Video.ColorBalance);

            if (gst_video_widget != null) {
                remove (gst_video_widget);
            }

            dynamic Gst.Element videorate = preview_pipeline.get_by_name ("videorate");
            videorate.max_rate = 30;
            videorate.drop_only = true;

            dynamic Gst.Element gtksink = Gst.ElementFactory.make ("gtkglsink", null);
            if (gtksink != null) {
                dynamic Gst.Element glsinkbin = Gst.ElementFactory.make ("glsinkbin", null);
                glsinkbin.sink = gtksink;
                preview_pipeline.add (glsinkbin);
                preview_pipeline.get_by_name ("videoscale").link (glsinkbin);
            } else {
                gtksink = Gst.ElementFactory.make ("gtksink", null);
                preview_pipeline.add (gtksink);
                preview_pipeline.get_by_name ("videoscale").link (gtksink);
            }

            gst_video_widget = gtksink.widget;
            add (gst_video_widget);
            gst_video_widget.show ();

            visible_child = gst_video_widget;
            preview_pipeline.set_state (Gst.State.PLAYING);
        } catch (Error e) {
            // It is possible that there is another camera present that could selected so do not show
            // no_device_view
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (_("Unable To View Camera"), e.message, "dialog-error");
            dialog.run ();
            dialog.destroy ();
        }
    }
    private Gst.Pipeline? create_picture_pipeline () {
        var brightness_value = GLib.Value (typeof (double));
        color_balance.get_property ("brightness", ref brightness_value);
        var contrast_value = GLib.Value (typeof (double));
        color_balance.get_property ("contrast", ref contrast_value);
        Gst.Pipeline? picture_pipeline = null;

        var preview_video_src = (Gst.Element) preview_pipeline.get_by_name (VIDEO_SRC_NAME);
        string device_path;
        preview_video_src.get ("device", out device_path);

        try {
            picture_pipeline = (Gst.Pipeline) Gst.parse_launch (
                VIDEO_SRC_NAME +" device=%s name=%s num-buffers=1 !".printf (device_path, VIDEO_SRC_NAME) +
                "capsfilter name=capsfilter ! " +
                "decodebin name=decodebin ! " +
                "videoflip method=%s !".printf (horizontal_flip ? "horizontal-flip" : "none") +
                "videobalance brightness=%f contrast=%f !".printf (brightness_value.get_double (), contrast_value.get_double ()) +
                "jpegenc ! filesink location=%s name=filesink".printf (Camera.Utils.get_new_media_filename (Camera.Utils.ActionType.PHOTO))
            );

            dynamic Gst.Element capsfilter = picture_pipeline.get_by_name ("capsfilter");
            picture_pipeline.get_by_name (VIDEO_SRC_NAME).link (capsfilter);
            var current_picture_caps = get_caps_from_index (current_picture_caps_index);
            if (current_picture_caps != null) {
                capsfilter.caps = current_picture_caps;
            }
        } catch (Error e) {
            // It is possible that there is another camera present that could selected so do not show
            // no_device_view
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (_("Unable To View Camera"), e.message, "dialog-error");
            dialog.run ();
            dialog.destroy ();
        }

        return picture_pipeline;
    }

    public void change_color_balance (double brightnesss, double contrast) {
        color_balance.set_property ("brightness", brightnesss);
        color_balance.set_property ("contrast", contrast);
    }

    public void change_caps (int index) {
        var new_caps = get_caps_from_index (index);
        if (new_caps != null) {
            unowned var s = new_caps.get_structure (0);
            if (s.get_name () == "image/jpeg") {
                current_picture_caps_index = index;
            } else if (s.get_name () == "video/x-raw") {
                current_video_caps_index = index;
                dynamic Gst.Element capsfilter = preview_pipeline.get_by_name ("capsfilter");
                capsfilter.caps = new_caps;
            }
        }
    }

    private void set_preview_caps (int index) {
        var new_caps = get_caps_from_index (index);
        if (new_caps != null) {
            dynamic Gst.Element capsfilter = preview_pipeline.get_by_name ("capsfilter");
            capsfilter.caps = new_caps;
        } else {
            critical ("Failed to set preview caps index %i", index);
        }
    }

    private void update_resolution_action_state (int index) {
        var caps = current_device.get_caps ();
        if (caps == null || index < 0 || index >= caps.get_size ()) {
            return;
        }

        get_action_group ("win").change_action_state (MainWindow.ACTION_CHANGE_CAPS, new GLib.Variant.uint32 (index));
    }

    public void take_photo () {
        if (recording || preview_pipeline == null) {
            return;
        }

        recording = true;
        preview_pipeline.set_state (Gst.State.NULL);
        preview_pipeline.sync_children_states ();
        var picture_pipeline = create_picture_pipeline ();
        var filesink = picture_pipeline.get_by_name ("filesink");
        filesink.get_static_pad ("sink").add_probe (Gst.PadProbeType.EVENT_DOWNSTREAM, (pad, info) => {
            if (info.get_event ().type == Gst.EventType.EOS) {
                Idle.add (() => {
                    picture_pipeline.set_state (Gst.State.NULL);
                    play_shutter_sound ();
                    create_video_pipeline ();

                    recording = false;
                    return Source.REMOVE;
                });

                return Gst.PadProbeReturn.REMOVE;
            }

            return Gst.PadProbeReturn.PASS;
        });

        picture_pipeline.set_state (Gst.State.PLAYING);
        picture_pipeline.sync_children_states ();

        Gst.Debug.BIN_TO_DOT_FILE (picture_pipeline, Gst.DebugGraphDetails.VERBOSE, "snapshot");
    }

    public void start_recording () {
        if (recording) {
            return;
        }

        recording = true;
        var record_bin = new Gst.Bin (null);
        record_bin.set_name ("record_bin");

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

        preview_pipeline.set_state (Gst.State.PAUSED);
        preview_pipeline.add (record_bin);
        record_bin.sync_state_with_parent ();
        preview_pipeline.get_by_name ("tee").link (record_bin);
        preview_pipeline.set_state (Gst.State.PLAYING);
        preview_pipeline.sync_children_states ();

        Gst.Debug.BIN_TO_DOT_FILE (preview_pipeline, Gst.DebugGraphDetails.VERBOSE, "recording");
    }

    public void stop_recording () {
        if (!recording) {
            return;
        }

        preview_pipeline.set_state (Gst.State.PAUSED);
        var record_bin = (Gst.Bin?)(preview_pipeline.get_by_name ("record_bin"));
        var filesink = record_bin.get_by_name ("filesink");
        if (filesink != null) {
            var locationval = GLib.Value (typeof (string));
            filesink.get_property ("location", ref locationval);
            string location = locationval.get_string ();
            recording_finished (location);
        }

        preview_pipeline.get_by_name ("tee").unlink (record_bin);
        preview_pipeline.remove (record_bin);
        record_bin.set_state (Gst.State.NULL);
        record_bin.dispose (); // Required for successful saving of video file
        recording = false;
        preview_pipeline.set_state (Gst.State.PLAYING);
    }

    private int find_structure_index (Gst.Structure? s) {
        var caps = current_device.get_caps ();
        if (caps != null && s != null) {
            for (int i = 0; i < caps.get_size (); i++) {
                if (s.is_equal (caps.get_structure (i))) {
                    return i;
                }
            }
        }

        return -1;
    }

    private Gst.Caps? get_caps_from_index (int index) {
        var caps = current_device.get_caps ();
        if (caps != null && index > 0 && index < caps.get_size ()) {
            unowned var s = caps.get_structure (index);
            var new_caps = new Gst.Caps.empty ();
            new_caps.append_structure (s.copy ());
            return new_caps;
        } else {
            return null;
        }

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
