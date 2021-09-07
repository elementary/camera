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

public class Camera.MainWindow : Hdy.ApplicationWindow {
    public const string ACTION_PREFIX = "win.";
    public const string ACTION_FULLSCREEN = "fullscreen";
    public const string ACTION_TAKE_PHOTO = "take_photo";
    public const string ACTION_RECORD = "record";

    private const GLib.ActionEntry[] ACTION_ENTRIES = {
        {ACTION_FULLSCREEN, on_fullscreen},
        {ACTION_TAKE_PHOTO, on_take_photo},
        {ACTION_RECORD, on_record, null, "false", null},
    };

    private uint configure_id;

    private bool timer_running;

    private Widgets.CameraView camera_view;
    private Widgets.HeaderBar header_bar;

    public MainWindow (Application application) {
        Object (application: application);

        add_action_entries (ACTION_ENTRIES, this);
        get_application ().set_accels_for_action (ACTION_PREFIX + ACTION_FULLSCREEN, {"F11"});
    }

    construct {
        Hdy.init ();

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/camera");

        this.title = _("Camera");
        icon_name = "io.elementary.camera";

        header_bar = new Widgets.HeaderBar ();

        camera_view = new Widgets.CameraView ();
        camera_view.bind_property ("horizontal-flip", header_bar, "horizontal-flip", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);

        var overlay = new Gtk.Overlay ();
        overlay.add (camera_view);

        var recording_finished_toast = new Granite.Widgets.Toast (_("Saved to Videos"));
        recording_finished_toast.set_default_action (_("View File"));
        recording_finished_toast.set_data ("location", "");
        recording_finished_toast.default_action.connect (() => {
            var file_path = recording_finished_toast.get_data<string> ("location");
            var file = GLib.File.new_for_path (file_path);
            try {
                var context = get_display ().get_app_launch_context ();
                context.set_timestamp (Gtk.get_current_event_time ());
                AppInfo.launch_default_for_uri (file.get_parent ().get_uri (), context);
            } catch (Error e) {
                warning ("Error launching file manager: %s", e.message);
            }
        });
        overlay.add_overlay (recording_finished_toast);

        var recording_finished_fail_toast = new Granite.Widgets.Toast (_("Recording failed"));
        overlay.add_overlay (recording_finished_fail_toast);

        camera_view.recording_finished.connect ((file_path) => {
            if (file_path == "") {
                recording_finished_fail_toast.send_notification ();
            } else {
                recording_finished_toast.set_data ("location", file_path);
                recording_finished_toast.send_notification ();
            }
        });

        var grid = new Gtk.Grid ();
        grid.attach (header_bar, 0, 0);
        grid.attach (overlay, 0, 1);

        var window_handle = new Hdy.WindowHandle ();
        window_handle.add (grid);

        add (window_handle);

        timer_running = false;
        camera_view.camera_added.connect (header_bar.add_camera_option);
        camera_view.camera_removed.connect (header_bar.remove_camera_option);
        camera_view.camera_present.connect (header_bar.enable_all_controls);
        header_bar.request_camera_change.connect (camera_view.change_camera);

        timer_running = false;

        camera_view.start ();

        header_bar.request_change_balance.connect (camera_view.change_color_balance);
    }

    private void on_fullscreen () {
        if (Gdk.WindowState.FULLSCREEN in get_window ().get_state ()) {
            unfullscreen ();
        } else {
            fullscreen ();
        }
    }

    private void on_take_photo () {
        if (timer_running) {
            return;
        }

        var delay = header_bar.timer_delay;
        header_bar.start_timeout (delay);
        timer_running = true;

        GLib.Timeout.add_seconds (delay, () => {
            camera_view.take_photo ();
            timer_running = false;
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
                int width, height;
                get_size (out width, out height);
                Application.settings.set ("window-size", "(ii)", width, height);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
