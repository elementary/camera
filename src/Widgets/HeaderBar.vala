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
    private const string PHOTO_ICON_SYMBOLIC = "view-list-images-symbolic";
    private const string VIDEO_ICON_SYMBOLIC = "view-list-video-symbolic";
    private const string STOP_ICON_SYMBOLIC = "media-playback-stop-symbolic";

    private Widgets.TimerButton timer_button;
    private Gtk.Revealer video_timer_revealer;
    private Gtk.Label take_timer;
    private Gtk.Button take_button;
    private Gtk.Image take_image;
    private Granite.ModeSwitch mode_switch;

    public signal void request_horizontal_flip ();
    public signal void request_change_balance (double brightness, double contrast);

    public bool recording { get; set; default = false; }

    public int timer_delay {
        get {
            return timer_button.delay;
        }
    }

    public const string TAKE_BUTTON_STYLESHEET = """
        .take-button {
            border-radius: 400px;
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
        take_grid.margin_start = take_grid.margin_end = 6;
        take_grid.add (take_image);
        take_grid.add (video_timer_revealer);

        take_button = new Gtk.Button ();
        take_button.action_name = Camera.MainWindow.ACTION_PREFIX + Camera.MainWindow.ACTION_TAKE_PHOTO;
        take_button.sensitive = false;
        take_button.width_request = 54;
        take_button.add (take_grid);

        Gtk.CssProvider take_button_style_provider = new Gtk.CssProvider ();

        try {
            take_button_style_provider.load_from_data (TAKE_BUTTON_STYLESHEET, -1);
        } catch (Error e) {
            warning ("Styling take button failed: %s", e.message);
        }

        var take_button_style_context = take_button.get_style_context ();
        take_button_style_context.add_provider (take_button_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        take_button_style_context.add_class ("take-button");
        take_button_style_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        mode_switch = new Granite.ModeSwitch.from_icon_name (PHOTO_ICON_SYMBOLIC, VIDEO_ICON_SYMBOLIC);
        mode_switch.valign = Gtk.Align.CENTER;


        var brightness_image = new Gtk.Image.from_icon_name ("display-brightness-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        var brightness_label = new Gtk.Label (_("Brightness"));
        brightness_label.get_style_context ().add_class ("h3");
        brightness_label.hexpand = true;
        brightness_label.set_xalign (0);

        var contrast_image = new Gtk.Image.from_icon_name ("night-light-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        var constrast_label = new Gtk.Label (_("Contrast"));
        constrast_label.get_style_context ().add_class ("h3");
        constrast_label.hexpand = true;
        constrast_label.set_xalign (0);

        var brightness_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
        brightness_scale.draw_value = false;
        brightness_scale.hexpand = true;
        brightness_scale.set_value (0);
        brightness_scale.add_mark (0, Gtk.PositionType.BOTTOM, "");
        brightness_scale.add_mark (1, Gtk.PositionType.BOTTOM, "");
        
        var contrast_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
        contrast_scale.draw_value = false;
        contrast_scale.hexpand = true;
        contrast_scale.set_value (1.0);
        contrast_scale.add_mark (0, Gtk.PositionType.BOTTOM, "");
        contrast_scale.add_mark (1, Gtk.PositionType.BOTTOM, "");
        
        brightness_scale.value_changed.connect (() => {
            request_change_balance (brightness_scale.get_value (), contrast_scale.get_value ());
        });

        contrast_scale.value_changed.connect (() => {
            request_change_balance (brightness_scale.get_value (), contrast_scale.get_value ());
        });

        var image_settings = new Gtk.Grid ();
        image_settings.row_spacing = 6;
        image_settings.margin = 6;
        image_settings.width_request = 250;
        image_settings.attach (brightness_image, 0, 0, 1, 1);
        image_settings.attach (brightness_label, 1, 0, 1, 1);
        image_settings.attach (brightness_scale, 0, 1, 2, 1);
        image_settings.attach (contrast_image, 0, 2, 1, 1);
        image_settings.attach (constrast_label, 1, 2, 1, 1);
        image_settings.attach (contrast_scale, 0, 3, 2, 1);
        image_settings.show_all ();

        var popover = new Gtk.Popover (null);
        popover.add (image_settings);

        var but = new Gtk.MenuButton ();
        but.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.MENU);
        but.popover = popover;

        show_close_button = true;
        get_style_context ().add_class (Gtk.STYLE_CLASS_TITLEBAR);
        pack_start (timer_button);
        set_custom_title (take_button);
        pack_end (but);
        pack_end (mode_switch);

        Camera.Application.settings.changed.connect ((key) => {
            if (key == "mode") {
                mode_switch.active = Camera.Application.settings.get_enum ("mode") == Utils.ActionType.VIDEO;
            }
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
