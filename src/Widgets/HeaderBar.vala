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
    private Gtk.MenuButton camera_menu_button;
    private Gtk.Revealer camera_menu_revealer;
    private Gtk.Menu camera_options;
    private Gtk.Image take_image;
    private Granite.ModeSwitch mode_switch;

    public bool recording { get; set; default = false; }

    public signal void request_camera_change (int camera_id);

    public int timer_delay {
        get {
            return timer_button.delay;
        }
    }

    public const string TAKE_BUTTON_STYLESHEET = """
        .take-button {
            transition-property: border-top-right-radius, border-bottom-right-radius, padding-right;
            transition-duration: 0.5s, 0.5s, 0.5s;
            border-radius: 400px 400px 400px 400px;

            padding-left: 6px;
            padding-right: 6px;
        }

        .take-button-multiple {
            border-top-right-radius: 0;
            border-bottom-right-radius: 0;
            padding-right: 0;
        }

    """;

    public const string CAMERA_MENU_BUTTON_STYLESHEET = """
    .camera-menu {
        border-radius: 0 400px 400px 0;
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

        camera_menu_button = new Gtk.MenuButton ();
        camera_options = new Gtk.Menu ();
        camera_menu_button.set_popup (camera_options);

        Gtk.CssProvider camera_menu_button_style_provider = new Gtk.CssProvider ();

        try {
            camera_menu_button_style_provider.load_from_data (CAMERA_MENU_BUTTON_STYLESHEET, -1);
        } catch (Error e) {
            warning ("Styling take button failed: %s", e.message);
        }

        var camera_menu_button_style_context = camera_menu_button.get_style_context ();
        camera_menu_button_style_context.add_provider (camera_menu_button_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        camera_menu_button_style_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        camera_menu_button_style_context.add_class ("camera-menu");

        var linked_box = new Gtk.Grid ();
        linked_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        linked_box.add (take_button);

        camera_menu_revealer = new Gtk.Revealer ();
        camera_menu_revealer.add (camera_menu_button);
        camera_menu_revealer.set_transition_duration (500);
        camera_menu_revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_RIGHT);
        linked_box.add (camera_menu_revealer);

        show_close_button = true;
        get_style_context ().add_class (Gtk.STYLE_CLASS_TITLEBAR);
        pack_start (timer_button);
        set_custom_title (linked_box);
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

    public void add_camera_option (Gst.Device camera) {
        var menuitem = new Gtk.MenuItem.with_label (camera.get_display_name ());
        camera_options.append (menuitem);
        int i = (int) camera_options.get_children ().length () - 1;
        menuitem.activate.connect (() => {
            request_camera_change (i);
        });
        menuitem.show ();

        if (camera_options.get_children ().length () > 1) {
            camera_menu_revealer.set_reveal_child (true);
            var take_button_style_context = take_button.get_style_context ();
            take_button_style_context.add_class ("take-button-multiple");
        }
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
        if (camera_options.get_children ().length () <= 1) {
            camera_menu_revealer.set_reveal_child (false);
            var take_button_style_context = take_button.get_style_context ();
            take_button_style_context.remove_class ("take-button-multiple");
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
