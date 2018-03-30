/*
 * Copyright (c) 2011-2016 elementary LLC. (https://github.com/elementary/camera)
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
 */

public class Camera.MainWindow : Gtk.Window {
    private bool is_fullscreened = false;

    private Backend.Settings settings;

    private Gtk.Stack stack;
    private Granite.Widgets.AlertView no_device_view;

    private GtkClutter.Embed clutter_embed;
    private Clutter.Actor camera_actor;
    private Clutter.Stage clutter_stage;
    private ClutterGst.Aspectratio camera_content;

    private Widgets.CameraView? camera_view = null;
    private Widgets.HeaderBar header_bar;
    private Widgets.LoadingView loading_view;

    public MainWindow (Application application) {
        Object (application: application);
    }

    construct {
        settings = new Backend.Settings ();

        this.set_application (application);
        this.title = _("Camera");
        this.icon_name = "accessories-camera";
        this.set_default_size (1000, 700);
        this.set_size_request (640, 480);
        this.window_position = Gtk.WindowPosition.CENTER;
        this.add_events (Gdk.EventMask.KEY_PRESS_MASK);

        header_bar = new Widgets.HeaderBar (settings);

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        stack.transition_duration = 500;

        loading_view = new Widgets.LoadingView ();

        no_device_view = new Granite.Widgets.AlertView (_("No Supported Camera Found"),
                                                        _("Connect a webcam or other supported video device to take photos and video."),
                                                        "accessories-camera");

        clutter_embed = new GtkClutter.Embed ();

        clutter_stage = (Clutter.Stage)clutter_embed.get_stage ();
        clutter_stage.background_color = Clutter.Color.get_static (Clutter.StaticColor.BLACK);
        clutter_stage.set_fullscreen (true);

        camera_content = new ClutterGst.Aspectratio ();

        camera_actor = new GtkClutter.Actor ();
        camera_actor.content = camera_content;
        camera_actor.add_constraint (new Clutter.BindConstraint (clutter_stage, Clutter.BindCoordinate.SIZE, 0));

        clutter_stage.add_child (camera_actor);

        stack.add_named (loading_view, "loading");
        stack.add_named (no_device_view, "no-device");
        stack.add_named (clutter_embed, "camera");

        this.set_titlebar (header_bar);
        this.add (stack);

        connect_signals ();

        new Thread<int> (null, () => {
            debug ("Initializing camera manager...");

            initialize_camera_manager ();

            return 0;
        });

        this.configure_event.connect ((event) => {
            if (camera_view != null) {
                camera_view.set_optimal_resolution (event.width, event.height);
            }
            return false;
        });
    }

    private void initialize_camera_manager () {
        ClutterGst.CameraManager camera_manager = ClutterGst.CameraManager.get_default ();

        Idle.add (() => {
            GenericArray<ClutterGst.CameraDevice> camera_devices = camera_manager.get_camera_devices ();

            if (camera_devices.length > 0 && camera_devices[0].get_name () != null) {
                initialize_camera_view ();
            } else {
                stack.set_visible_child_name ("no-device");

                debug ("No camera device found.");
            }

            return false;
        });
    }

    private void initialize_camera_view () {
        camera_view = new Widgets.CameraView ();
        camera_view.initialized.connect (() => {
            header_bar.camera_controls_sensitive = true;
            stack.set_visible_child_name ("camera");
            camera_view.set_optimal_resolution (1000, 700);
        });

        camera_content.set_player (camera_view);

        loading_view.set_status (_("Connecting to \"%s\"…".printf (camera_view.get_camera_device ().get_name ())));
    }

    private void connect_signals () {
        this.key_press_event.connect ((event) => {
            switch (event.keyval) {
                case Gdk.Key.F11 :
                    if (is_fullscreened) {
                        this.unfullscreen ();
                    } else {
                        this.fullscreen ();
                    }
                    is_fullscreened = !is_fullscreened;
                    break;

                default:
                    return Gdk.EVENT_PROPAGATE;
            }

            return Gdk.EVENT_STOP;
        });

        header_bar.take_photo_clicked.connect (() => {
            if (camera_view == null) {
                return;
            }

            camera_view.take_photo ();
        });
        header_bar.start_recording_clicked.connect (() => {
            if (camera_view == null) {
                return;
            }

            if (camera_view.start_recording ()) {
                header_bar.set_is_recording (true);
            }
        });
        header_bar.stop_recording_clicked.connect (() => {
            if (camera_view == null) {
                return;
            }

            camera_view.stop_recording ();
            header_bar.set_is_recording (false);
        });
    }
}
