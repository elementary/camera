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

/**
 * This is Snap's preview area
 */

namespace Snap.Widgets {

    public class MediaBin : Gtk.EventBox {

        public PreviewArea preview_area { get; private set; }

        public MediaBin () {
            push_composite_child ();
            this.preview_area = new PreviewArea ();
            pop_composite_child ();

            add (this.preview_area);

            // Dark background theming

            var style = new Gtk.CssProvider ();
            try {
                style.load_from_data (Resources.PREVIEW_STYLESHEET, -1);
            } catch (Error e) {
                warning (e.message);
            }

            this.get_style_context ().add_class ("snap-preview-bg");
            this.get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_THEME);
        }

        public void set_aspect_ratio (int width, int height) {
            this.preview_area.set_aspect_ratio (width, height);
        }
    }

    public class PreviewArea : Gtk.DrawingArea {

        // Aspect ratio h:v. Default: 4:3
        private uint h = 4;
        private uint v = 3;

        public PreviewArea () {
            this.vexpand = true;
            this.hexpand = false;

            this.valign = Gtk.Align.FILL;
            this.halign = Gtk.Align.CENTER;
        }

        public void set_aspect_ratio (uint horizontal, uint vertical) {
            this.h = horizontal;
            this.v = vertical;
            queue_resize ();
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT;
        }

        public override void get_preferred_width_for_height (int height, out int minimum_width,
                                                                out int natural_width) {
            uint width = (this.h * height) / this.v;
            minimum_width = (int)width;
            natural_width = minimum_width;
        }
    }
}

