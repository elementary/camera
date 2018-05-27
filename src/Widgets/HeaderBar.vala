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

public class Camera.Widgets.HeaderBar : Gtk.HeaderBar {
    private const string PHOTO_ICON_SYMBOLIC = "view-list-images-symbolic";
    private const string VIDEO_ICON_SYMBOLIC = "view-list-video-symbolic";
    private const string STOP_ICON_SYMBOLIC = "media-playback-stop-symbolic";

    private Widgets.TakeButton take_button;
    private Widgets.TimerButton timer_button;

    private Gtk.Switch mode_switch;
    private bool is_recording = false;

    public bool camera_controls_sensitive {
        set {
            take_button.sensitive = value;
            timer_button.sensitive = value;
            mode_switch.sensitive = value;
        }
    }
    public Backend.Settings settings { private get; construct; }

    public signal void take_photo_clicked ();
    public signal void start_recording_clicked ();
    public signal void stop_recording_clicked ();

    public HeaderBar (Backend.Settings settings) {
        Object (settings: settings);
    }

    construct {
        timer_button = new Widgets.TimerButton ();

        take_button = new Widgets.TakeButton ();
        take_button.icon_name = PHOTO_ICON_SYMBOLIC;

        var photo_icon = new Gtk.Image.from_icon_name (PHOTO_ICON_SYMBOLIC, Gtk.IconSize.SMALL_TOOLBAR);
        photo_icon.tooltip_text = _("Take a photo");

        mode_switch = new Gtk.Switch ();
        mode_switch.sensitive = false;
        mode_switch.valign = Gtk.Align.CENTER;

        var video_icon = new Gtk.Image.from_icon_name (VIDEO_ICON_SYMBOLIC, Gtk.IconSize.SMALL_TOOLBAR);
        video_icon.tooltip_text = _("Make a video");

        show_close_button = true;
        set_custom_title (take_button);
        pack_start (timer_button);
        pack_end (video_icon);
        pack_end (mode_switch);
        pack_end (photo_icon);

        update_take_button_icon ();
        connect_signals ();
    }

    public void set_is_recording (bool is_recording) {
        this.is_recording = is_recording;
        update_take_button_icon ();
    }

    private void connect_signals () {
        settings.action_type_changed.connect (update_take_button_icon);

        take_button.clicked.connect ( () => {
            if (settings.get_action_type () == Utils.ActionType.PHOTO) {
                take_button.start_delay_time (timer_button.time);
                Timeout.add_seconds (timer_button.time, () => {
                    take_photo_clicked ();
                    return false;
                });
            } else {
                if (is_recording) {
                    take_button.stop_timer ();
                    stop_recording_clicked ();
                } else {
                    take_button.start_timer ();
                    start_recording_clicked ();
                }
            }
        });

        mode_switch.notify["active"].connect( () => {
            if (mode_switch.active) {
                settings.set_action_type (Utils.ActionType.VIDEO);
            } else {
                settings.set_action_type (Utils.ActionType.PHOTO);
            }
        });
    }

    private void update_take_button_icon () {
        string icon_name;
        Utils.ActionType action_type = settings.get_action_type ();

        if (action_type == Utils.ActionType.PHOTO) {
            icon_name = PHOTO_ICON_SYMBOLIC;
            mode_switch.active = false;
            timer_button.visible = true;
        } else {
            icon_name = (is_recording ? STOP_ICON_SYMBOLIC : VIDEO_ICON_SYMBOLIC);
            mode_switch.active = true;
            timer_button.visible = false;
        }

        take_button.icon_name = icon_name;
    }
}
