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

using Gtk;

/**
 * This is Snap's preview area
 */

namespace Snap.Widgets {

    public class MediaBin : EventBox {

        public DrawingArea preview_area {get; private set;}

        private Box wrapper_box;

        // Aspect ratio hr:vr. Default: 4:3
        private int vr = 3;
        private int hr = 4;

        public MediaBin () {
            preview_area = new DrawingArea ();

            wrapper_box = new Box (Orientation.HORIZONTAL, 0);
            wrapper_box.pack_start (preview_area, true, true, 0);

            add (wrapper_box);

            var style = new Gtk.CssProvider ();
            try {
                style.load_from_data (Resources.PREVIEW_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }

            // Dark background
            this.get_style_context ().add_class ("snap-preview-bg");
            this.get_style_context ().add_provider (style, STYLE_PROVIDER_PRIORITY_THEME);

            this.size_allocate.connect (on_size_allocate);
        }

        public void set_aspect_ratio (int horizontal, int vertical) {
            if (horizontal <= 0 || vertical <= 0)
                return;

            hr = horizontal;
            vr = vertical;
        }

        private void on_size_allocate (Allocation alloc) {
            Timeout.add (20, () => {
                int preview_width = (this.get_allocated_height() * hr) / vr;
                int blank_area_width = this.get_allocated_width() - preview_width;
                int margin = blank_area_width / 2;
/*
                if (blank_area_width < 0)
                    return false;

                if (preview_area.get_allocated_width () - 2 * margin < 0)
                    return false;
*/
                preview_area.margin_left = margin;
                preview_area.margin_right = margin;

                return preview_width / this.get_allocated_height() != 4 / 3;
            });
        }
        
                public override bool draw (Cairo.Context ctx){
            int w = this.get_allocated_width  ();
            int h = this.get_allocated_height ();
            Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 4, 4, w-8, h-8, 4);
            ctx.set_source_rgba (0.0, 0.0, 1.0, 1.0);
            ctx.fill ();
            return base.draw (ctx);
        }
    }
}

