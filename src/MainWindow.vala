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

public class Camera.MainWindow : Gtk.Window {
    private bool is_fullscreened = false;

    private Widgets.CameraView? camera_view = null;
    private Widgets.HeaderBar header_bar;

    public MainWindow (Application application) {
        Object (application: application);
    }

    construct {
        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/elementary/camera");

        this.set_application (application);
        this.title = _("Camera");
        this.icon_name = "accessories-camera";
        this.set_default_size (1000, 700);
        this.set_size_request (640, 480);
        this.window_position = Gtk.WindowPosition.CENTER;
        this.add_events (Gdk.EventMask.KEY_PRESS_MASK);

        header_bar = new Widgets.HeaderBar ();

        camera_view = new Widgets.CameraView ();

        header_bar.camera_controls_sensitive = true;

        this.set_titlebar (header_bar);
        this.add (camera_view);
        show_all ();

        if (camera_view.get_cameras () > 0) {
            camera_view.start_view (0);
        }

        this.key_press_event.connect ((event) => {
            switch (event.keyval) {
                case Gdk.Key.F11 :
                    if (is_fullscreened) {
                        this.unfullscreen ();
                    } else {
                        this.fullscreen ();
                    }
                    is_fullscreened = !is_fullscreened;
                    break;

                default:
                    return Gdk.EVENT_PROPAGATE;
            }

            return Gdk.EVENT_STOP;
        });

        header_bar.take_photo_clicked.connect (() => {
            if (camera_view == null) {
                return;
            }

            camera_view.take_photo ();
        });
        header_bar.start_recording_clicked.connect (() => {
            if (camera_view == null) {
                return;
            }

            if (camera_view.start_recording ()) {
                header_bar.recording = true;
            }
        });
        header_bar.stop_recording_clicked.connect (() => {
            if (camera_view == null) {
                return;
            }

            camera_view.stop_recording ();
        });
    }
}
