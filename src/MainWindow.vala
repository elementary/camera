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
    public const string ACTION_CHANGE_CAMERA = "change_camera";

    private const GLib.ActionEntry[] ACTION_ENTRIES = {
        {ACTION_FULLSCREEN, on_fullscreen},
        {ACTION_TAKE_PHOTO, on_take_photo},
        {ACTION_RECORD, on_record, null, "false", null},
        {ACTION_CHANGE_CAMERA, on_change_camera, "s", "''"}
    };

    private const string PHOTO_ICON_SYMBOLIC = "view-list-images-symbolic";
    private const string VIDEO_ICON_SYMBOLIC = "view-list-video-symbolic";
    private const string STOP_ICON_SYMBOLIC = "media-playback-stop-symbolic";

    private Widgets.CameraView camera_view;
    private Menu camera_options;
    private Gtk.Button take_button;
    private Gtk.Image take_image;
    private Gtk.Label take_timer_label;
    private Gtk.Revealer camera_menu_revealer;
    private Gtk.Revealer video_timer_revealer;
    private Widgets.TimerButton timer_button;
    private Granite.ModeSwitch mode_switch;
    private Gtk.MenuButton menu_button;
    private Gtk.Box linked_box;

    private bool timer_running = false;
    public bool recording { get; private set; default = false; }

    public MainWindow (Application application) {
        Object (application: application);

        add_action_entries (ACTION_ENTRIES, this);
        get_application ().set_accels_for_action (ACTION_PREFIX + ACTION_FULLSCREEN, {"F11"});
    }

    construct {
        title = _("Camera");
        icon_name = "io.elementary.camera";

        camera_view = new Widgets.CameraView ();
        camera_view.camera_added.connect (add_camera_option);
        camera_view.camera_removed.connect (remove_camera_option);

        var recording_finished_toast = new Granite.Toast (_("Saved to Videos"));
        recording_finished_toast.set_default_action (_("View File"));
        recording_finished_toast.set_data ("location", "");
        recording_finished_toast.default_action.connect (() => {
            var file_path = recording_finished_toast.get_data<string> ("location");
            var file = GLib.File.new_for_path (file_path);
            try {
                var context = get_display ().get_app_launch_context ();
                context.set_timestamp (Gdk.CURRENT_TIME);
                AppInfo.launch_default_for_uri (file.get_parent ().get_uri (), context);
            } catch (Error e) {
                warning ("Error launching file manager: %s", e.message);
            }
        });

        var recording_finished_fail_toast = new Granite.Toast (_("Recording failed"));

        var overlay = new Gtk.Overlay () {
            child = camera_view
        };
        overlay.add_overlay (recording_finished_toast);
        overlay.add_overlay (recording_finished_fail_toast);

        var window_handle = new Gtk.WindowHandle () {
            child = overlay
        };

        child = window_handle;
        titlebar = construct_headerbar ();

        camera_view.recording_finished.connect ((file_path) => {
            if (file_path == "") {
                recording_finished_fail_toast.send_notification ();
            } else {
                recording_finished_toast.set_data ("location", file_path);
                recording_finished_toast.send_notification ();
            }
        });

        camera_view.start ();
    }

    /* This function copies (with some reordering/reformating) the construct clause of Camera.Widgets.HeaderBar */
    private Gtk.HeaderBar construct_headerbar () {
        timer_button = new Widgets.TimerButton ();

        /* Construct take photo/video tool */
        take_image = new Gtk.Image.from_icon_name (PHOTO_ICON_SYMBOLIC);
        take_timer_label = new Gtk.Label (null);

        video_timer_revealer = new Gtk.Revealer () {
            child = take_timer_label,
            transition_type = SLIDE_RIGHT
        };

        var take_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            halign = Gtk.Align.CENTER
        };
        take_box.append (take_image);
        take_box.append (video_timer_revealer);

        take_button = new Gtk.Button () {
            action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_TAKE_PHOTO,
            child = take_box,
            width_request = 54
        };
        take_button.add_css_class ("take-button");
        take_button.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);

        /* Construct mode switch */
        mode_switch = new Granite.ModeSwitch.from_icon_name (PHOTO_ICON_SYMBOLIC, VIDEO_ICON_SYMBOLIC) {
            valign = Gtk.Align.CENTER
        };
        mode_switch.notify["active"].connect (() => {
            if (mode_switch.active) {
                Camera.Application.settings.set_enum ("mode", Utils.ActionType.VIDEO);
                take_button.action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_RECORD;
                take_image.icon_name = VIDEO_ICON_SYMBOLIC;
                timer_button.sensitive = false;
            } else {
                Camera.Application.settings.set_enum ("mode", Utils.ActionType.PHOTO);
                take_button.action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_TAKE_PHOTO;
                take_image.icon_name = PHOTO_ICON_SYMBOLIC;
                timer_button.sensitive = true;
            }
        });
        Camera.Application.settings.changed["mode"].connect ((key) => {
            mode_switch.active = Camera.Application.settings.get_enum ("mode") == Utils.ActionType.VIDEO;
        });
        mode_switch.active = Camera.Application.settings.get_enum ("mode") == Utils.ActionType.VIDEO;

        /* Construct AppMenu */
        var mirror_switch = new Granite.SwitchModelButton (_("Mirror"));
        mirror_switch.bind_property (
            "active", camera_view, "horizontal-flip", GLib.BindingFlags.BIDIRECTIONAL
        );

        var brightness_image = new Gtk.Image.from_icon_name ("display-brightness-symbolic");
        var brightness_label = new Gtk.Label (_("Brightness")) {
            hexpand = true,
            xalign = 0
        };
        var brightness_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, -1, 1, 0.1) {
            draw_value = false,
            hexpand = true,
            margin_bottom = 6
        };
        brightness_scale.set_value (0);
        brightness_scale.add_mark (0, Gtk.PositionType.BOTTOM, "");

        var contrast_image = new Gtk.Image.from_icon_name ("color-contrast-symbolic");
        var contrast_label = new Gtk.Label (_("Contrast")) {
            hexpand = true,
            xalign = 0
        };
        var contrast_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 2, 0.1) {
            draw_value = false,
            hexpand = false
        };
        contrast_scale.set_value (1);
        contrast_scale.add_mark (1, Gtk.PositionType.BOTTOM, "");

        contrast_scale.value_changed.connect (() => {
            camera_view.change_color_balance (brightness_scale.get_value (), contrast_scale.get_value ());
        });
        brightness_scale.value_changed.connect (() => {
            camera_view.change_color_balance (brightness_scale.get_value (), contrast_scale.get_value ());
        });

        var image_settings = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 3,
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12
        };
        image_settings.attach (brightness_image, 0, 0);
        image_settings.attach (brightness_label, 1, 0);
        image_settings.attach (brightness_scale, 0, 1, 2);
        image_settings.attach (contrast_image, 0, 2);
        image_settings.attach (contrast_label, 1, 2);
        image_settings.attach (contrast_scale, 0, 3, 2);

        var menu_popover_grid = new Gtk.Grid () {
            width_request = 250,
            margin_bottom = 3
        };
        menu_popover_grid.attach (image_settings, 0, 0);
        menu_popover_grid.attach (mirror_switch, 0, 1);

        var popover = new Gtk.Popover () {
            child = menu_popover_grid
        };

        menu_button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            popover = popover,
            tooltip_text = _("Settings")
        };

        /* Construct menu for multiple cameras */
        camera_options = new Menu ();
        var camera_menu_button = new Gtk.MenuButton () {
            menu_model = camera_options
        };
        camera_menu_button.popover.has_arrow = false;

        var menubutton_child = camera_menu_button.get_first_child ();
        menubutton_child.add_css_class (Granite.STYLE_CLASS_DESTRUCTIVE_ACTION);
        menubutton_child.add_css_class ("camera-menu");
        menubutton_child.remove_css_class ("image-button");

        camera_menu_revealer = new Gtk.Revealer () {
            child = camera_menu_button,
            overflow = VISIBLE,
            transition_duration = 250,
            transition_type = SLIDE_RIGHT
        };

        linked_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        linked_box.append (take_button);
        linked_box.append (camera_menu_revealer);

        var header_widget = new Gtk.HeaderBar () {
            show_title_buttons = true,
            title_widget = linked_box
        };
        header_widget.pack_start (timer_button);
        header_widget.pack_end (menu_button);
        header_widget.pack_end (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        header_widget.pack_end (mode_switch);

        notify["recording"].connect (() => {
            timer_button.sensitive = !recording && !mode_switch.active;
            mode_switch.sensitive = !recording;
            video_timer_revealer.reveal_child = recording;

            if (recording) {
                take_image.icon_name = STOP_ICON_SYMBOLIC;
            } else {
                take_image.icon_name = VIDEO_ICON_SYMBOLIC;
            }
        });

        enable_header (false);
        return header_widget;
    }

    private void on_fullscreen () {
        if (fullscreened) {
            unfullscreen ();
        } else {
            fullscreen ();
        }
    }

    private void on_take_photo () {
        if (timer_running) {
            return;
        }

        var delay = timer_button.delay;
        start_timeout (delay);
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
            stop_recording_time ();
            action.set_state (new Variant.boolean (false));
        } else {
            camera_view.start_recording ();
            start_recording_time ();
            action.set_state (new Variant.boolean (true));
        }
    }

    /** Header bar tools management functions from Camera.Widgets.HeaderBar **/

    private void enable_header (bool enable) {
        linked_box.sensitive = enable;
        mode_switch.sensitive = enable;
        menu_button.sensitive = enable;
        timer_button.sensitive = enable;
    }

    private void add_camera_option (Gst.Device camera) {
        camera_options.append (
            camera.display_name,
            "%s%s('%s')".printf (ACTION_PREFIX, ACTION_CHANGE_CAMERA, camera.name)
        );
        camera_options.set_data (camera.name, camera);

        change_action_state (ACTION_CHANGE_CAMERA, new Variant.string (camera.name));

        update_take_button ();
        enable_header (true);
    }

    private void on_change_camera (GLib.SimpleAction action, GLib.Variant? parameter) {
        // action state setting is handled in change_camera ()
        camera_view.change_camera (camera_options.get_data (parameter.get_string ()));
    }

    private void remove_camera_option (Gst.Device camera) {
        var item_count = camera_options.get_n_items ();
        for (var index = 0; index < item_count; index++) {
            var variant = camera_options.get_item_attribute_value (index, Menu.ATTRIBUTE_TARGET, VariantType.STRING);
            if (variant.get_string () == camera.name) {
                camera_options.remove (index);
                item_count--;
                break;
            }
        }

        update_take_button ();
        enable_header (item_count > 0);
    }

    private void update_take_button () {
        if (camera_options.get_n_items () > 1) {
            camera_menu_revealer.reveal_child = true;
            take_button.add_css_class ("multiple");
        } else {
            camera_menu_revealer.reveal_child = false;
            take_button.remove_css_class ("multiple");
        }
    }

    private void start_timeout (int time) {
        var timeout_reached = time == 0;

        mode_switch.sensitive = timeout_reached;
        take_image.visible = timeout_reached;
        timer_button.sensitive = timeout_reached;
        video_timer_revealer.reveal_child = !timeout_reached;

        if (!timeout_reached) {
            take_timer_label.label = time.to_string ();

            Timeout.add_seconds (1, () => {
                start_timeout (time - 1);
                return GLib.Source.REMOVE;
            });
        }
    }

    private uint recording_timeout = 0U;
    private void start_recording_time () {
        recording = true;
        int seconds = 0;
        take_timer_label.label = Granite.DateTime.seconds_to_time (seconds);

        recording_timeout = Timeout.add_seconds (1, () => {
            seconds++;
            take_timer_label.label = Granite.DateTime.seconds_to_time (seconds);
            return GLib.Source.CONTINUE;
        });
    }

    private void stop_recording_time () {
        recording = false;
        if (recording_timeout > 0) {
            GLib.Source.remove (recording_timeout);
        }

        recording_timeout = 0U;
    }
}
