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

public class Camera.Widgets.CameraView : ClutterGst.Camera {
    public signal void initialized ();
    public Backend.Settings settings;

    public CameraView () {
        new Thread<int> (null, () => {
            debug ("Initializing camera view...");

            initialize_view ();

            settings.changed.connect (() => {
                set_brightness  (settings.brightness);
            });

            return 0;
        });

        settings = new Backend.Settings ();
    }

    public new bool take_photo () {
        if (!this.is_ready_for_capture () || this.is_recording_video ()) {
            warning ("Device isn't ready for taking photos.");

            return false;
        }

        base.take_photo (Utils.get_new_media_filename (Utils.ActionType.PHOTO));
        play_shutter_sound ();

        return true;
    }

    public bool start_recording () {
        if (!this.is_ready_for_capture () || this.is_recording_video ()) {
            warning ("Device isn't ready for recording videos.");

            return false;
        }

        this.start_video_recording (Utils.get_new_media_filename (Utils.ActionType.VIDEO));

        return true;
    }

    public void stop_recording () {
        if (!this.is_recording_video ()) {
            warning ("Cannot stop recording because no record is running.");

            return;
        }

        this.stop_video_recording ();
    }

    private void initialize_view () {
        Gst.Element flip_filter = Gst.ElementFactory.make ("videoflip", "videoflip");
        flip_filter.set_property ("method", 4);

        this.set_filter (flip_filter);
        this.set_playing (true);

        if (this.is_ready_for_capture ()) {
            debug ("Camera view initalized.");

            Idle.add (() => {
                initialized ();

                return false;
            });
        } else {
            warning ("Initializing camera view failed.");
        }
    }

    private void play_shutter_sound () {
        Canberra.Context context;
        Canberra.Proplist props;

        Canberra.Context.create (out context);
        Canberra.Proplist.create (out props);

        props.sets (Canberra.PROP_EVENT_ID, "camera-shutter");
        props.sets (Canberra.PROP_EVENT_DESCRIPTION, _("Photo taken"));
        props.sets (Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");
        props.sets (Canberra.PROP_MEDIA_ROLE, "event");

        context.play_full (0, props, null);
    }
}
