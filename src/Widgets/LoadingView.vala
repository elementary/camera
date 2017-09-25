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

public class Camera.Widgets.LoadingView : Gtk.Box {
    private Gtk.Grid inner_grid;

    private Gtk.Spinner spinner;
    private Gtk.Label status_label;

    public LoadingView () {
        Object (orientation: Gtk.Orientation.HORIZONTAL);

        build_ui ();
    }

    public void set_status (string status) {
        status_label.set_label (status);
    }

    private void build_ui () {
        this.override_background_color (Gtk.StateFlags.NORMAL, { 0, 0, 0, 1 });
        this.override_color (Gtk.StateFlags.NORMAL, { 1, 1, 1, 1 });

        inner_grid = new Gtk.Grid ();
        inner_grid.halign = Gtk.Align.CENTER;
        inner_grid.valign = Gtk.Align.CENTER;

        spinner = new Gtk.Spinner ();
        spinner.active = true;

        status_label = new Gtk.Label (_("Searching for video devices…"));
        status_label.margin_top = 12;

        inner_grid.attach (spinner, 0, 0, 1, 1);
        inner_grid.attach (status_label, 0, 1, 1, 1);

        this.pack_start (inner_grid);
    }
}
