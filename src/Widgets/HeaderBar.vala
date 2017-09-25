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

    private Gtk.Button take_button;
    private Granite.Widgets.ModeButton mode_button;

    private bool is_recording = false;

    public bool camera_controls_sensitive {
        set {
            take_button.sensitive = value;
            mode_button.sensitive = value;
        }
    }

    public const string TAKE_BUTTON_STYLESHEET = """
        .take-button {
            border-radius: 400px;
        }
    """;

    public Backend.Settings settings { private get; construct; }

    public signal void take_photo_clicked ();
    public signal void start_recording_clicked ();
    public signal void stop_recording_clicked ();

    public HeaderBar (Backend.Settings settings) {
        Object (settings: settings);
    }

    construct {
        take_button = new Gtk.Button.from_icon_name (PHOTO_ICON_SYMBOLIC, Gtk.IconSize.BUTTON);
        take_button.sensitive = false;
        take_button.width_request = 54;

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

        mode_button = new Granite.Widgets.ModeButton ();
        mode_button.append_icon (PHOTO_ICON_SYMBOLIC, Gtk.IconSize.BUTTON);
        mode_button.append_icon (VIDEO_ICON_SYMBOLIC, Gtk.IconSize.BUTTON);
        mode_button.sensitive = false;

        show_close_button = true;
        set_custom_title (take_button);
        pack_end (mode_button);

        update_take_button_icon ();
        connect_signals ();
    }

    public void set_is_recording (bool is_recording) {
        this.is_recording = is_recording;
        update_take_button_icon ();
    }

    private void connect_signals () {
        settings.action_type_changed.connect (update_take_button_icon);

        take_button.clicked.connect (() => {
            if (settings.get_action_type () == Utils.ActionType.PHOTO) {
                take_photo_clicked ();
            } else {
                if (is_recording) {
                    stop_recording_clicked ();
                } else {
                    start_recording_clicked ();
                }
            }
        });

        mode_button.mode_changed.connect (() => {
            settings.set_action_type (mode_button.selected == 0 ? Utils.ActionType.PHOTO : Utils.ActionType.VIDEO);
        });
    }

    private void update_take_button_icon () {
        string icon_name;
        Utils.ActionType action_type = settings.get_action_type ();

        if (action_type == Utils.ActionType.PHOTO) {
            icon_name = PHOTO_ICON_SYMBOLIC;
        } else {
            icon_name = (is_recording ? STOP_ICON_SYMBOLIC : VIDEO_ICON_SYMBOLIC);
        }

        ((Gtk.Image)take_button.image).set_from_icon_name (icon_name, Gtk.IconSize.BUTTON);
        mode_button.set_active ((int)(action_type == Utils.ActionType.VIDEO));
    }
}
