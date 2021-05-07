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

    private const string PHOTO_ICON_SYMBOLIC = "view-list-images-symbolic";
    private const string VIDEO_ICON_SYMBOLIC = "view-list-video-symbolic";
    private const string STOP_ICON_SYMBOLIC = "media-playback-stop-symbolic";

    private Widgets.TimerButton timer_button;
    private Gtk.Revealer video_timer_revealer;
    private Gtk.Label take_timer;
    private Gtk.Grid linked_box;
    private Gtk.Button take_button;
    private Gtk.MenuButton camera_menu_button;
    private Gtk.MenuButton menu_button;
    private Gtk.Revealer camera_menu_revealer;
    private Gtk.Menu camera_options;
    private Gtk.Image take_image;
    private Granite.ModeSwitch mode_switch;

    public bool recording { get; set; default = false; }
    public bool horizontal_flip { get; set; default = true; }

    public signal void request_camera_change (int camera_id);

    public int timer_delay {
        get {
            return timer_button.delay;
        }
    }

    public const string TAKE_BUTTON_STYLESHEET = """
        .camera-menu {
            border-radius: 0 400px 400px 0;
        }

        .take-button {
            border-radius: 400px;
            padding-left: 6px;
            padding-right: 6px;
            transition-duration: 200ms;
            transition-property: border-top-right-radius, border-bottom-right-radius, padding-right;
        }

        .take-button.multiple {
            border-bottom-right-radius: 0;
            border-top-right-radius: 0;
            border-right-width: 0;
            padding-right: 0;
        }
    """;

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

        var take_grid = new Gtk.Grid ();
        take_grid.halign = Gtk.Align.CENTER;
        take_grid.add (take_image);
        take_grid.add (video_timer_revealer);

        take_button = new Gtk.Button ();
        take_button.action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_TAKE_PHOTO;
        take_button.width_request = 54;
        take_button.add (take_grid);

        var take_button_style_provider = new Gtk.CssProvider ();

        try {
            take_button_style_provider.load_from_data (TAKE_BUTTON_STYLESHEET, -1);
        } catch (Error e) {
            warning ("Styling take button failed: %s", e.message);
        }

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

        camera_menu_button = new Gtk.MenuButton ();
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

        linked_box = new Gtk.Grid ();
        linked_box.add (take_button);
        linked_box.add (camera_menu_revealer);

        show_close_button = true;
        get_style_context ().add_class (Gtk.STYLE_CLASS_TITLEBAR);
        pack_start (timer_button);
        set_custom_title (linked_box);
        pack_end (menu_button);
        pack_end (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));


        pack_end (mode_switch);

        Camera.Application.settings.changed["mode"].connect ((key) => {
            mode_switch.active = Camera.Application.settings.get_enum ("mode") == Utils.ActionType.VIDEO;
        });

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

        mode_switch.active = Camera.Application.settings.get_enum ("mode") == Utils.ActionType.VIDEO;
    }

    public void enable_all_controls (bool enabled) {
        linked_box.sensitive = enabled;
        mode_switch.sensitive = enabled;
        menu_button.sensitive = enabled;
        timer_button.sensitive = enabled;
    }

    public void add_camera_option (Gst.Device camera) {
        var menuitem = new Gtk.RadioMenuItem.with_label (null, camera.get_display_name ());
        camera_options.append (menuitem);

        int i = (int) camera_options.get_children ().length () - 1;
        if (i > 0) {
            var el = camera_options.get_children ().nth_data (0) as Gtk.RadioMenuItem;
            menuitem.join_group (el);
        }
        menuitem.active = true;
        menuitem.activate.connect (() => {
            request_camera_change (i);
        });
        menuitem.show ();

        update_take_button ();
    }

    public void remove_camera_option (Gst.Device camera) {
        Gtk.Widget to_remove = null;
        foreach (unowned Gtk.Widget menuitem in camera_options.get_children ()) {
            var name = ((Gtk.MenuItem) menuitem).label;
            if (name == camera.get_display_name ()) {
                to_remove = menuitem;
                break;
            }
        }
        if (to_remove != null) {
            camera_options.remove (to_remove);
        }

        update_take_button ();
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
        GLib.Source.remove (recording_timeout);
        recording_timeout = 0U;
    }
}
