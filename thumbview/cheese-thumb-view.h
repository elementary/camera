/*
 * Copyright © 2007,2008 daniel g. siegel <dgsiegel@gnome.org>
 * Copyright © 2007,2008 Jaap Haitsma <jaap@haitsma.org>
 * Copyright © 2012 Mario Guerriero <mario@elementaryos.org>
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

#ifndef __CHEESE_THUMB_VIEW_H__
#define __CHEESE_THUMB_VIEW_H__

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define CHEESE_TYPE_THUMB_VIEW (cheese_thumb_view_get_type ())
#define CHEESE_THUMB_VIEW(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), CHEESE_TYPE_THUMB_VIEW, CheeseThumbView))
#define CHEESE_THUMB_VIEW_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), CHEESE_TYPE_THUMB_VIEW, \
                                                                    CheeseThumbViewClass))
#define CHEESE_IS_THUMB_VIEW(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), CHEESE_TYPE_THUMB_VIEW))
#define CHEESE_IS_THUMB_VIEW_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), CHEESE_TYPE_THUMB_VIEW))
#define CHEESE_THUMB_VIEW_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), CHEESE_TYPE_THUMB_VIEW, \
                                                                      CheeseThumbViewClass))

typedef struct
{
  GtkIconView parent;
} CheeseThumbView;

typedef struct
{
  GtkIconViewClass parent_class;
} CheeseThumbViewClass;

GType      cheese_thumb_view_get_type (void);
GtkWidget *cheese_thumb_view_new (const int *type);

GList *cheese_thumb_view_get_selected_images_list (CheeseThumbView *thumb_view);
char * cheese_thumb_view_get_selected_image (CheeseThumbView *thumb_view);
guint  cheese_thumb_view_get_n_selected (CheeseThumbView *thumbview);
void cheese_thumb_view_fill (CheeseThumbView *thumb_view);
void   cheese_thumb_view_remove_item (CheeseThumbView *thumb_view, GFile *file);
void cheese_thumb_view_start_monitoring_photo_path (CheeseThumbView *thumbview, const char *path_photos);
void cheese_thumb_view_start_monitoring_video_path (CheeseThumbView *thumbview, const char *path_videos);

G_END_DECLS

#endif /* __CHEESE_THUMB_VIEW_H__ */
