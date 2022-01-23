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

public class Camera.Widgets.Gtk4HeaderBar : Gtk.HeaderBar {
    public bool show_title_buttons { get; set; default = false; }
    public Gtk.Widget? title_widget { get; set; default = null; }

    construct {
        notify["show-title-buttons"].connect (() => {
            show_close_button = show_title_buttons;
        });
        notify["title-widget"].connect (() => {
            custom_title = title_widget;
        });
    }
}
