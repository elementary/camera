// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as
  published    by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses>

  END LICENSE
***/

using Gtk;
using Granite;

namespace Snap.Widgets {

    public class Countdown : Granite.Widgets.CompositedWindow {
        public signal void time_elapsed ();

        public Label count_label {get; private set;}
        public Label title_label {get; private set;}

        public MediaType media_type {get; private set;}

        private bool window_destroyed = false;

        public Countdown (MediaType media_type) {
            this.media_type = media_type;

            this.set_default_size (300, 200);
            this.window_position = WindowPosition.CENTER;
            this.set_keep_above (true);
            this.stick ();
            this.type_hint = Gdk.WindowTypeHint.SPLASHSCREEN;
            this.skip_pager_hint = true;
            this.skip_taskbar_hint = true;

            var box = new Box (Orientation.VERTICAL, 0);
            box.margin = 40;
            box.margin_left = box.margin_right = 60;

            this.title_label = new Label ("");
            this.title_label.use_markup = true;

            this.count_label = new Label ("");
            this.count_label.use_markup = true;

            box.pack_start (title_label);
            box.pack_start (count_label);

            this.add (box);

            string media_text = "";

            if (media_type == MediaType.PHOTO)
                media_text = _("Taking photo in");
            else if (media_type == MediaType.VIDEO)
                media_text = _("Recording starts in");

            media_text = media_text.replace ("&", "&amp;");

            title_label.label = "<span size='20000' color='#fbfbfb'>" + media_text + "</span>";

        }

        public override bool draw (Cairo.Context ctx) {
            int w = this.get_allocated_width  ();
            int h = this.get_allocated_height ();
            Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 4, 4, w - 8, h - 8, 4);
            ctx.set_source_rgba (0.1, 0.1, 0.1, 0.8);
            ctx.fill ();
            return base.draw (ctx);
        }

        public void start (int secs) {
            set_count (secs);

            if (secs > 0)
                this.show_all ();

            Timeout.add (1000, () => {
                secs --;

                if (window_destroyed)
                    return false;

                if (secs == 0) {
                    this.hide ();
                }
                else if (secs == -1) {
                    if (!window_destroyed)
                        this.time_elapsed (); // notify that we're finished here
                    this.destroy ();
                    return false; // stop
                }

                set_count (secs);
                return true; // keep going
            });
        }

        public override void destroy () {
            window_destroyed = true;
            base.destroy ();
        }

        private void set_count (int secs) {
            count_label.label = "<span size='40000' color='#fbfbfb'>" + secs.to_string () + "</span>";
        }
    }
}

