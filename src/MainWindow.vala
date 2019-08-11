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

public class Camera.MainWindow : Gtk.ApplicationWindow {
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_FULLSCREEN = "fullscreen";
    public const string ACTION_TAKE_PHOTO = "take_photo";
    public const string ACTION_RECORD = "record";

    private const GLib.ActionEntry[] action_entries = {
        {ACTION_FULLSCREEN, on_fullscreen},
        {ACTION_TAKE_PHOTO, on_take_photo},
        {ACTION_RECORD, on_record, null, "false", null},
    };

    private uint configure_id;

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

        add_action_entries (action_entries, this);
        get_application ().set_accels_for_action (ACTION_PREFIX + ACTION_FULLSCREEN, {"F11"});
    }

    construct {
        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/camera");

        this.set_application (application);
        this.title = _("Camera");
        this.icon_name = "accessories-camera";
        this.set_size_request (640, 480);
        this.window_position = Gtk.WindowPosition.CENTER;

        header_bar = new Widgets.HeaderBar ();

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

        new Thread<int> (null, () => {
            debug ("Initializing camera manager...");

            initialize_camera_manager ();

            return 0;
        });
    }

    private void initialize_camera_manager () {
        ClutterGst.CameraManager camera_manager = ClutterGst.CameraManager.get_default ();

        Idle.add (() => {
            GenericArray<ClutterGst.CameraDevice> camera_devices = camera_manager.get_camera_devices ();

            if (camera_devices.length > 0) {
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
        camera_view.get_camera_device ().set_capture_resolution (640, 480);

        camera_view.initialized.connect (() => {
            stack.set_visible_child_name ("camera");
        });

        camera_content.set_player (camera_view);

        loading_view.set_status (_("Connecting to \"%s\"…").printf (camera_view.get_camera_device ().get_name ()));
    }

    private void on_fullscreen () {
        if (Gdk.WindowState.FULLSCREEN in get_window ().get_state ()) {
            unfullscreen ();
        } else {
            fullscreen ();
        }
    }

    private void on_take_photo () {
        var delay = header_bar.timer_delay;
        header_bar.start_timeout (delay);

        GLib.Timeout.add_seconds (delay, () => {
            camera_view.take_photo ();
            return GLib.Source.REMOVE;
        });
    }

    private void on_record (GLib.SimpleAction action, GLib.Variant? parameter) {
        if (action.state.get_boolean ()) {
            camera_view.stop_recording ();
            header_bar.stop_recording_time ();
            action.set_state (new Variant.boolean (false));
        } else {
            camera_view.start_recording ();
            header_bar.start_recording_time ();
            action.set_state (new Variant.boolean (true));
        }
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id != 0) {
            GLib.Source.remove (configure_id);
        }

        configure_id = Timeout.add (100, () => {
            configure_id = 0;

            if (is_maximized) {
                Application.settings.set_boolean ("window-maximized", true);
            } else {
                Application.settings.set_boolean ("window-maximized", false);

                Gdk.Rectangle rect;
                get_allocation (out rect);
                Application.settings.set ("window-size", "(ii)", rect.width, rect.height);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
