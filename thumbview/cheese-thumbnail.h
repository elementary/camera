/*
 * Copyright © 2010 daniel g. siegel <dgsiegel@gnome.org>
 *
 *
 * Based on eog and eel code by:
 *   - Lucas Rocha <lucasr@gnome.org>
 *   - Andy Hertzfeld <andy@eazel.com>
 *
 * Licensed under the GNU General Public License Version 2
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _CHEESE_THUMBNAIL_H_
#define _CHEESE_THUMBNAIL_H_

#include <gdk-pixbuf/gdk-pixbuf.h>

G_BEGIN_DECLS

void cheese_thumbnail_init (void);

void cheese_thumbnail_add_frame (GdkPixbuf **pixbuf);

G_END_DECLS

#endif /* _CHEESE_THUMBNAIL_H_ */
