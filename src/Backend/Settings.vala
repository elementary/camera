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

public class Camera.Backend.Settings : Granite.Services.Settings {
    protected string mode { get; set; }
    public double brightness { get; set; }

    public signal void action_type_changed (Utils.ActionType action_type);

    public Settings () {
        base ("io.elementary.camera.settings");

        connect_signals ();
    }

    public Utils.ActionType get_action_type () {
        return (mode == "photo" ? Utils.ActionType.PHOTO : Utils.ActionType.VIDEO);
    }

    public void set_action_type (Utils.ActionType action_type) {
        mode = (action_type == Utils.ActionType.PHOTO ? "photo" : "video");
    }

    private void connect_signals () {
        this.notify["mode"].connect (() => {
            action_type_changed (get_action_type ());
        });
    }
}
