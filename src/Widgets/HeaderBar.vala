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

public class Camera.Widgets.HeaderBar : Gtk.HeaderBar {
    public signal void request_change_balance (double brightness, double contrast);

    public Gtk.Button take_button;

    private const string PHOTO_ICON_SYMBOLIC = "view-list-images-symbolic";
    private const string VIDEO_ICON_SYMBOLIC = "view-list-video-symbolic";
    private const string STOP_ICON_SYMBOLIC = "media-playback-stop-symbolic";

    private Widgets.TimerButton timer_button;
    private Gtk.Revealer video_timer_revealer;
    private Gtk.Label take_timer;
    private Gtk.Box linked_box;
    private Gtk.MenuButton camera_menu_button;
    private Gtk.MenuButton menu_button;
    private Gtk.Revealer camera_menu_revealer;
    private Gtk.Menu camera_options;
    private GLib.Menu resolution_menu;
    private Gtk.MenuButton resolution_button;
    private Gtk.Image take_image;
    private Granite.ModeSwitch mode_switch;
    private Gst.Device? current_device = null;

    public bool recording { get; set; default = false; }
    public bool horizontal_flip { get; set; default = true; }

    public signal void request_camera_change (Gst.Device camera);

    public int timer_delay {
        get {
            return timer_button.delay;
        }
    }

    construct {
        timer_button = new Widgets.TimerButton ();
        timer_button.image = new Gtk.Image.from_icon_name ("timer-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

        take_image = new Gtk.Image ();
        take_image.icon_name = PHOTO_ICON_SYMBOLIC;
        take_image.icon_size = Gtk.IconSize.BUTTON;

        take_timer = new Gtk.Label (null);

        video_timer_revealer = new Gtk.Revealer ();
        video_timer_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        video_timer_revealer.add (take_timer);

        var take_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        take_box.halign = Gtk.Align.CENTER;
        take_box.pack_start (take_image);
        take_box.pack_start (video_timer_revealer);

        take_button = new Gtk.Button ();
        take_button.action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_TAKE_PHOTO;
        take_button.width_request = 54;
        take_button.add (take_box);

        var take_button_style_provider = new Gtk.CssProvider ();
        take_button_style_provider.load_from_resource ("/io/elementary/camera/application.css");

        unowned Gtk.StyleContext take_button_style_context = take_button.get_style_context ();
        take_button_style_context.add_provider (take_button_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        take_button_style_context.add_class ("take-button");
        take_button_style_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        mode_switch = new Granite.ModeSwitch.from_icon_name (PHOTO_ICON_SYMBOLIC, VIDEO_ICON_SYMBOLIC);
        mode_switch.valign = Gtk.Align.CENTER;

        var mirror_switch = new Granite.SwitchModelButton (_("Mirror"));
        mirror_switch.bind_property ("active", this, "horizontal-flip", GLib.BindingFlags.BIDIRECTIONAL);

        var brightness_image = new Gtk.Image.from_icon_name ("display-brightness-symbolic", Gtk.IconSize.MENU);
        var brightness_label = new Gtk.Label (_("Brightness")) {
            hexpand = true,
            xalign = 0
        };

        var contrast_image = new Gtk.Image.from_icon_name ("color-contrast-symbolic", Gtk.IconSize.MENU);
        var constrast_label = new Gtk.Label (_("Contrast")) {
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

        var contrast_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 2, 0.1) {
            draw_value = false,
            hexpand = false
        };
        contrast_scale.set_value (1);
        contrast_scale.add_mark (1, Gtk.PositionType.BOTTOM, "");

        brightness_scale.value_changed.connect (() => {
            request_change_balance (brightness_scale.get_value (), contrast_scale.get_value ());
        });

        contrast_scale.value_changed.connect (() => {
            request_change_balance (brightness_scale.get_value (), contrast_scale.get_value ());
        });

        var image_settings = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 3,
            margin = 12
        };

        resolution_menu = new GLib.Menu ();
        resolution_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("preferences-desktop-display-symbolic", Gtk.IconSize.MENU),
        };
        resolution_button.set_menu_model (resolution_menu);

        image_settings.attach (brightness_image, 0, 0);
        image_settings.attach (brightness_label, 1, 0);
        image_settings.attach (brightness_scale, 0, 1, 2);
        image_settings.attach (contrast_image, 0, 2);
        image_settings.attach (constrast_label, 1, 2);
        image_settings.attach (contrast_scale, 0, 3, 2);

        var menu_popover_grid = new Gtk.Grid () {
            width_request = 250,
            margin_bottom = 3
        };
        menu_popover_grid.attach (image_settings, 0, 0);
        menu_popover_grid.attach (mirror_switch, 0, 1);
        menu_popover_grid.show_all ();

        var popover = new Gtk.Popover (null);
        popover.add (menu_popover_grid);

        menu_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.MENU),
            popover = popover,
            tooltip_text = _("Settings")
        };

        camera_options = new Gtk.Menu ();

        camera_menu_button = new Gtk.MenuButton () {
            popup = camera_options
        };

        unowned Gtk.StyleContext camera_menu_button_style_context = camera_menu_button.get_style_context ();
        camera_menu_button_style_context.add_provider (take_button_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        camera_menu_button_style_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        camera_menu_button_style_context.add_class ("camera-menu");

        camera_menu_revealer = new Gtk.Revealer () {
            transition_duration = 250,
            transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT
        };
        camera_menu_revealer.add (camera_menu_button);

        linked_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        linked_box.pack_start (take_button);
        linked_box.pack_start (camera_menu_revealer);

        show_close_button = true;
        get_style_context ().add_class (Gtk.STYLE_CLASS_TITLEBAR);
        pack_start (timer_button);
        set_custom_title (linked_box);
        pack_end (menu_button);
        pack_end (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        pack_end (resolution_button);
        pack_end (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        pack_end (mode_switch);

        /* Use schema nicks for binding. The camera view monitors the mode setting and changes accordingly */
        Camera.Application.settings.bind_with_mapping ("mode", mode_switch, "active", SettingsBindFlags.DEFAULT,
            (val, variant, user_data) => {
                val.set_boolean (variant.get_string () == "video");
                return true;
            },
            (val, expected_type, user_data) => {
                if (val.get_boolean ()) {
                    return new Variant ("s", "video");
                } else {
                    return new Variant ("s", "photo");
                }
            },
            null, null
        );

        mode_switch.notify ["active"].connect (on_mode_changed);

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

        on_mode_changed ();
    }

    public void enable_all_controls (bool enabled) {
        linked_box.sensitive = enabled;
        mode_switch.sensitive = enabled;
        menu_button.sensitive = enabled;
        timer_button.sensitive = enabled;
    }

    public void add_camera_option (Gst.Device camera) {
        current_device = camera;
        var menuitem = new Gtk.RadioMenuItem.with_label (null, camera.display_name);
        menuitem.set_data<Gst.Device> ("camera", camera);
        camera_options.append (menuitem);

        int i = (int) camera_options.get_children ().length () - 1;
        if (i > 0) {
            var el = camera_options.get_children ().nth_data (0) as Gtk.RadioMenuItem;
            menuitem.join_group (el);
        }

        menuitem.active = true;
        menuitem.activate.connect (() => {
            current_device = menuitem.get_data<Gst.Device> ("camera");
            if (menuitem.active) {
                request_camera_change (current_device);
                update_resolution_menu ();
            }
        });
        menuitem.show ();

        update_take_button ();
        update_resolution_menu ();
    }

    public void remove_camera_option (Gst.Device camera) {
        Gtk.Widget to_remove = null;
        foreach (unowned Gtk.Widget menuitem in camera_options.get_children ()) {
            var name = ((Gtk.MenuItem) menuitem).get_data<Gst.Device> ("camera").name;
            if (name == camera.name) {
                to_remove = menuitem;
                break;
            }
        }

        if (to_remove != null) {
            camera_options.remove (to_remove);
        }

        if (camera_options.get_children ().length () > 0) {
            camera_options.active = 0;
        }

        update_resolution_menu ();
        update_take_button ();
        enable_all_controls (camera_options.get_children ().length () > 0);
    }

    private void update_resolution_menu () {
        resolution_button.tooltip_text = mode_switch.active ? _("Video capture resolution") : _("Photo capture resolution");
        resolution_menu.remove_all ();
        if (current_device == null || current_device.get_caps () == null) {
            return;
        }

        int prev_w = 0, prev_h = 0;
        double prev_fr = 0.0;
        var caps = current_device.get_caps ();
        for (uint i = 0; i < caps.get_size (); i++) {
            unowned var s = caps.get_structure (i);
            if (s.get_name () != (mode_switch.active ? "video/x-raw" : "image/jpeg")) {
                continue;
            }

            int w, h;
            double fr = 0.0;
            if (Camera.Utils.parse_structure (s, out w, out h, out fr)) {
                // Check not duplicate ( for simplicity assume duplicates listed next to each other)
                if (w != prev_w || h != prev_h || fr != prev_fr) {
                    if (mode_switch.active) { // Show framerate for video capture
                        resolution_menu.append (
                            "%d×%d (%0.f fps)".printf (w, h, fr),
                            GLib.Action.print_detailed_name ("win.change-caps", new GLib.Variant.uint32 (i))
                        );
                    } else { // Framerate not useful for still image capture
                        resolution_menu.append (
                            "%d×%d".printf (w, h),
                            GLib.Action.print_detailed_name ("win.change-caps", new GLib.Variant.uint32 (i))
                        );
                    }
                }

                prev_w = w;
                prev_h = h;
                prev_fr = fr;
            }
        }
    }

    private void update_take_button () {
        unowned Gtk.StyleContext take_button_style_context = take_button.get_style_context ();
        if (camera_options.get_children ().length () > 1) {
            camera_menu_revealer.reveal_child = true;
            take_button_style_context.add_class ("multiple");
        } else {
            camera_menu_revealer.reveal_child = false;
            take_button_style_context.remove_class ("multiple");
        }
    }

    private void on_mode_changed () {
        Idle.add (() => {
            update_resolution_menu ();
            if (mode_switch.active) {
                take_button.action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_RECORD;
                take_image.icon_name = VIDEO_ICON_SYMBOLIC;
                timer_button.sensitive = false;
            } else {
                take_button.action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_TAKE_PHOTO;
                take_image.icon_name = PHOTO_ICON_SYMBOLIC;
                timer_button.sensitive = true;
            }

            return Source.REMOVE;
        });
    }

    public void start_timeout (int time) {
        var timeout_reached = time == 0;

        mode_switch.sensitive = timeout_reached;
        take_image.visible = timeout_reached;
        timer_button.sensitive = timeout_reached;
        video_timer_revealer.reveal_child = !timeout_reached;

        if (!timeout_reached) {
            take_timer.label = time.to_string ();

            Timeout.add_seconds (1, () => {
                start_timeout (time - 1);
                return GLib.Source.REMOVE;
            });
        }
    }

    private uint recording_timeout = 0U;
    public void start_recording_time () {
        recording = true;
        int seconds = 0;
        take_timer.label = Granite.DateTime.seconds_to_time (seconds);

        recording_timeout = Timeout.add_seconds (1, () => {
            seconds++;
            take_timer.label = Granite.DateTime.seconds_to_time (seconds);
            return GLib.Source.CONTINUE;
        });
    }

    public void stop_recording_time () {
        recording = false;
        if (recording_timeout > 0) {
            GLib.Source.remove (recording_timeout);
        }

        recording_timeout = 0U;
    }
}
