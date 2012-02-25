// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2011-2012 Snap Developers
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

// TODO: Read time values [time = 3] from settings

namespace Snap {

    public class Recorder {

        //gst objects
        public Pipelines pipeline {get; private set;}

        public bool recording {get; private set;}

        public int photo_timeout {get; private set;}
        public int video_timeout {get; private set;}

        public Widgets.Countdown countdown_window {get; private set;}
        public Widgets.MediaBin media_bin {get; private set;}

        public Recorder (Widgets.MediaBin media_bin) {
            this.media_bin = media_bin;

            setup_pipeline ();

            recording = false;
            photo_timeout = video_timeout = 3;

            // FIXME: set this value according to the current camera's resolution
            media_bin.set_aspect_ratio (4, 3);
        }

        private void setup_pipeline () {
            this.pipeline = new Pipelines (media_bin.preview_area);
            pipeline.play ();
        }

        public void start (MediaType media_type) {
            if (recording == true)
                return;

            recording = true;

            int secs = 0;
            if (media_type == MediaType.PHOTO)
                secs = photo_timeout;
            else if (media_type == MediaType.VIDEO)
                secs = video_timeout;

            countdown_window = new Snap.Widgets.Countdown (media_type);
            countdown_window.start (secs);

            countdown_window.time_elapsed.connect ( () => {
                if (media_type == MediaType.PHOTO)
                    pipeline.take_photo ();
                else if (media_type == MediaType.VIDEO)
                    pipeline.take_video ();
                recording = false;
            });
        }

        public void stop () {
            if (!recording)
                return;

            if (countdown_window != null)
                countdown_window.destroy ();

            pipeline.take_video_stop ();

            recording = false;
        }
    }
}

