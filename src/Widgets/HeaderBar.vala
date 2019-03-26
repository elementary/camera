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

    public bool recording { get; set; default = false; }

    public bool camera_controls_sensitive {
        set {
            timer_button.sensitive = value;
            take_button.sensitive = value;
            mode_switch.sensitive = value;
        }
    }

    public const string TAKE_BUTTON_STYLESHEET = """
        .take-button {
            border-radius: 400px;
        }
    """;

    public signal void take_photo_clicked ();
    public signal void start_recording_clicked ();
    public signal void stop_recording_clicked ();

    construct {
        timer_button = new Widgets.TimerButton ();
        timer_button.sensitive = false;

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

        show_close_button = true;
        pack_start (timer_button);
        set_custom_title (take_button);
        pack_end (mode_switch);

        update_take_button_icon ();

        Camera.Application.settings.changed.connect (update_take_button_icon);

        take_button.clicked.connect (() => {
            if (Camera.Application.settings.get_enum ("mode") == Utils.ActionType.PHOTO) {
                start_timeout (timer_button.delay);
                // Time to take a photo
                Timeout.add_seconds (timer_button.delay, () => {
                    take_photo_clicked ();
                    return false;
                });
            } else {
                if (recording) {
                    stop_recording_clicked ();
                    recording = false;
                } else {
                    start_recording_clicked ();
                }
            }
        });

        mode_switch.notify["active"].connect (() => {
            if (mode_switch.active) {
                Camera.Application.settings.set_enum ("mode", Utils.ActionType.VIDEO);
                timer_button.sensitive = false;
            } else {
                Camera.Application.settings.set_enum ("mode", Utils.ActionType.PHOTO);
                timer_button.sensitive = true;
            }
        });

        bool timer_active = false;

        notify["recording"].connect (() => {
            timer_button.sensitive = !recording && !mode_switch.active;
            update_take_button_icon ();

            if (recording) {
                video_timer_revealer.reveal_child = true;
                timer_active = true;

                int seconds = 0;
                take_timer.label = Granite.DateTime.seconds_to_time (seconds);

                Timeout.add_seconds (1, () => {
                    seconds = seconds + 1;
                    take_timer.label = Granite.DateTime.seconds_to_time (seconds);
                    return timer_active;
                });
            } else {
                timer_active = false;
                video_timer_revealer.reveal_child = false;
            }
        });
    }

    private void update_take_button_icon () {
        var action_type = (Utils.ActionType) Camera.Application.settings.get_enum ("mode");

        if (action_type == Utils.ActionType.PHOTO) {
            take_image.icon_name = PHOTO_ICON_SYMBOLIC;
            mode_switch.active = false;
        } else {
            take_image.icon_name = (recording ? STOP_ICON_SYMBOLIC : VIDEO_ICON_SYMBOLIC);
            mode_switch.active = true;
        }
    }

    private void start_timeout (int time) {
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
}
