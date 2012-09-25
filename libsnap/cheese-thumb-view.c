/*
 * Copyright © 2007,2008 daniel g. siegel <dgsiegel@gnome.org>
 * Copyright © 2007,2008 Jaap Haitsma <jaap@haitsma.org>
 * Copyright © 2008 Filippo Argiolas <filippo.argiolas@gmail.com>
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

#include <glib.h>
#include <gtk/gtk.h>
#include <libgnome-desktop/gnome-desktop-thumbnail.h>
#include <string.h>

#include "cheese-fileutil.h"
#include "cheese-thumbnail.h"

#include "cheese-thumb-view.h"

const guint THUMB_VIEW_MINIMUM_WIDTH = 140;
const guint THUMB_VIEW_MINIMUM_HEIGHT = 100;

const gchar CHEESE_OLD_VIDEO_NAME_SUFFIX[] = ".ogv";

#define CHEESE_THUMB_VIEW_GET_PRIVATE(o) \
  (G_TYPE_INSTANCE_GET_PRIVATE ((o), CHEESE_TYPE_THUMB_VIEW, CheeseThumbViewPrivate))

G_DEFINE_TYPE (CheeseThumbView, cheese_thumb_view, GTK_TYPE_ICON_VIEW);

typedef struct
{
  GtkListStore *store;
  CheeseFileUtil *fileutil;
  GFileMonitor   *photo_file_monitor;
  GFileMonitor   *video_file_monitor;
  GnomeDesktopThumbnailFactory *factory;
  gboolean multiplex_thumbnail_generator;
  guint n_items;
  guint idle_id;
  GQueue *thumbnails;
} CheeseThumbViewPrivate;

enum
{
  THUMBNAIL_PIXBUF_COLUMN,
  THUMBNAIL_URL_COLUMN,
  THUMBNAIL_BASENAME_URL_COLUMN
};

/* Drag 'n Drop */
enum THUMBNAIL_PIXBUF_COLUMN
{
  TARGET_PLAIN,
  TARGET_PLAIN_UTF8,
  TARGET_URILIST,
};

static GtkTargetEntry target_table[] = {
  {"text/uri-list", 0, TARGET_URILIST},
};

typedef struct
{
  CheeseThumbView *thumb_view;
  GFile *file;
  GtkTreeIter iter;
} CheeseThumbViewIdleData;


static void cheese_thumb_view_constructed (GObject *object);
GtkWidget * cheese_thumb_view_new (void);

static gboolean
cheese_thumb_view_idle_append_item (gpointer data)
{
  CheeseThumbViewIdleData *item = g_queue_peek_head (data);
  CheeseThumbView         *thumb_view;
  CheeseThumbViewPrivate  *priv;

  /* Disconnect the idle handler when the queue is empty. */
  if (item == NULL) return FALSE;

  thumb_view = item->thumb_view;
  priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);


  GnomeDesktopThumbnailFactory *factory = priv->factory;
  GFile                        *file    = item->file;
  GtkTreeIter                   iter    = item->iter;
  GdkPixbuf                    *pixbuf  = NULL;
  GFileInfo                    *info;
  char                         *thumb_loc;
  GTimeVal                      mtime;
  char                         *mime_type;
  char                         *uri;
  char                         *filename;

  info = g_file_query_info (file, "standard::content-type,time::modified", 0, NULL, NULL);

  if (!info)
  {
    g_warning ("Invalid filename\n");
    return TRUE;
  }
  g_file_info_get_modification_time (info, &mtime);
  mime_type = g_strdup (g_file_info_get_content_type (info));

  uri      = g_file_get_uri (file);
  filename = g_file_get_path (file);

  thumb_loc = gnome_desktop_thumbnail_factory_lookup (factory, uri, mtime.tv_sec);

  if (!thumb_loc)
  {
    pixbuf = gnome_desktop_thumbnail_factory_generate_thumbnail (factory, uri, mime_type);
    if (!pixbuf)
    {
      g_warning ("could not generate thumbnail for %s (%s)\n", filename, mime_type);
    }
    else
    {
      gnome_desktop_thumbnail_factory_save_thumbnail (factory, pixbuf, uri, mtime.tv_sec);
    }
  }
  else
  {
    pixbuf = gdk_pixbuf_new_from_file (thumb_loc, NULL);
    if (!pixbuf)
    {
      g_warning ("could not load thumbnail %s (%s)\n", filename, mime_type);
    }
  }
  g_object_unref (info);
  g_free (thumb_loc);
  g_free (uri);

  if (!pixbuf)
  {
    gchar  *escape = NULL;
    GError *error  = NULL;
    escape = g_strrstr (mime_type, "/");
    if (escape != NULL) *escape = '-';
    pixbuf = gtk_icon_theme_load_icon (gtk_icon_theme_get_default (),
                                       mime_type,
                                       96,
                                       GTK_ICON_LOOKUP_GENERIC_FALLBACK,
                                       &error);
    if (error)
    {
      g_warning ("%s", error->message);
      return TRUE;
    }
  }
  else
  {
    cheese_thumbnail_add_frame (&pixbuf);
  }

  gtk_list_store_set (priv->store, &iter,
                      THUMBNAIL_PIXBUF_COLUMN, pixbuf, -1);

  g_free (mime_type);
  g_free (filename);
  g_object_unref (pixbuf);
  g_object_unref (file);
  g_slice_free (CheeseThumbViewIdleData, item);
  g_queue_pop_head (data);

  return TRUE;
}

static void
cheese_thumb_view_append_item (CheeseThumbView *thumb_view, GFile *file)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  GtkTreeIter   iter;
  GtkIconTheme *icon_theme;
  GdkPixbuf    *pixbuf = NULL;
  GtkTreePath  *path;
  char         *filename, *basename, *col_filename;
  GError       *error = NULL;
  gboolean      skip  = FALSE;
  GFileInfo    *info;
  goffset       size;

  CheeseThumbViewIdleData *data;

  info = g_file_query_info (file, G_FILE_ATTRIBUTE_STANDARD_SIZE, 0, NULL,
                            NULL);
  size = g_file_info_get_size (info);
  g_object_unref (info);

  /* Ignore 0-sized files, bug 677735. */
  if (size == 0)
    return;

  filename = g_file_get_path (file);

  if (!(g_str_has_suffix (filename, CHEESE_PHOTO_NAME_SUFFIX))
    && !(g_str_has_suffix (filename, CHEESE_VIDEO_NAME_SUFFIX))
    && !(g_str_has_suffix (filename, CHEESE_OLD_VIDEO_NAME_SUFFIX)))
  {
    g_free (filename);
    return;
  }

  if (gtk_tree_model_get_iter_first (GTK_TREE_MODEL (priv->store), &iter))
  {
    /* check if the selected item is the first, else go through the store */
    gtk_tree_model_get (GTK_TREE_MODEL (priv->store), &iter, THUMBNAIL_URL_COLUMN, &col_filename, -1);
    if (g_ascii_strcasecmp (col_filename, filename))
    {
      while (gtk_tree_model_iter_next (GTK_TREE_MODEL (priv->store), &iter))
      {
        gtk_tree_model_get (GTK_TREE_MODEL (priv->store), &iter, THUMBNAIL_URL_COLUMN, &col_filename, -1);
        if (!g_ascii_strcasecmp (col_filename, filename))
        {
          skip = TRUE;
          break;
        }
      }
    }
    else
    {
      skip = TRUE;
    }
    g_free (col_filename);
    g_free (filename);

    if (skip) return;
  }

  if (priv->multiplex_thumbnail_generator)
  {
    char *f;

    f      = g_strdup_printf ("%s/pixmaps/cheese-%i.svg", "/usr/share", g_random_int_range (1, 4));
    pixbuf = gdk_pixbuf_new_from_file (f, NULL);
    g_free (f);
  }
  else
  {
    icon_theme = gtk_icon_theme_get_default ();
    pixbuf     = gtk_icon_theme_load_icon (icon_theme,
                                           "image-loading",
                                           96,
                                           GTK_ICON_LOOKUP_GENERIC_FALLBACK,
                                           &error);
  }

  if (!pixbuf)
  {
    g_warning ("Couldn't load icon: %s", error->message);
    g_error_free (error);
    error = NULL;
  }

  filename = g_file_get_path (file);
  basename = g_path_get_basename (filename);

  gtk_list_store_append (priv->store, &iter);
  gtk_list_store_set (priv->store, &iter,
                      THUMBNAIL_PIXBUF_COLUMN, pixbuf,
                      THUMBNAIL_URL_COLUMN, filename,
                      THUMBNAIL_BASENAME_URL_COLUMN, basename, -1);
  g_free (filename);
  g_free (basename);
  path = gtk_tree_model_get_path (GTK_TREE_MODEL (priv->store), &iter);
  gtk_icon_view_scroll_to_path (GTK_ICON_VIEW (thumb_view), path,
                                TRUE, 1.0, 0.5);

  if (pixbuf) g_object_unref (pixbuf);

  if (!priv->multiplex_thumbnail_generator)
  {
    data             = g_slice_new0 (CheeseThumbViewIdleData);
    data->thumb_view = g_object_ref (thumb_view);
    data->file       = g_object_ref (file);
    data->iter       = iter;

    g_queue_push_tail (priv->thumbnails, data);
    if (!priv->idle_id) g_idle_add (cheese_thumb_view_idle_append_item, priv->thumbnails);
  }
}

void
cheese_thumb_view_remove_item (CheeseThumbView *thumb_view, GFile *file)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  char       *path;
  GtkTreeIter iter;
  char       *filename;
  gboolean    found = FALSE;

  filename = g_file_get_path (file);

  if (!gtk_tree_model_get_iter_first (GTK_TREE_MODEL (priv->store), &iter))
  {
    /* a single item was on the thumbview but it's been already removed */
    return;
  }

  /* check if the selected item is the first, else go through the store */
  gtk_tree_model_get (GTK_TREE_MODEL (priv->store), &iter, THUMBNAIL_URL_COLUMN, &path, -1);
  if (g_ascii_strcasecmp (path, filename))
  {
    while (gtk_tree_model_iter_next (GTK_TREE_MODEL (priv->store), &iter))
    {
      gtk_tree_model_get (GTK_TREE_MODEL (priv->store), &iter, THUMBNAIL_URL_COLUMN, &path, -1);
      if (!g_ascii_strcasecmp (path, filename))
      {
        found = TRUE;
        break;
      }
    }
  }
  else
  {
    found = TRUE;
  }
  g_free (path);
  g_free (filename);

  if (!found) return;

  gboolean valid = gtk_list_store_remove (priv->store, &iter);
  if (!valid)
  {
    int len = gtk_tree_model_iter_n_children (GTK_TREE_MODEL (priv->store), NULL);
    if (len <= 0)
      return;

    valid = gtk_tree_model_iter_nth_child (GTK_TREE_MODEL (priv->store), &iter, NULL, len - 1);
  }
  GtkTreePath *tree_path = gtk_tree_model_get_path (GTK_TREE_MODEL (priv->store), &iter);
  gtk_icon_view_select_path (GTK_ICON_VIEW (thumb_view), tree_path);
  gtk_tree_path_free (tree_path);
}

static void
cheese_thumb_view_monitor_cb (GFileMonitor     *file_monitor,
                              GFile            *file,
                              GFile            *other_file,
                              GFileMonitorEvent event_type,
                              CheeseThumbView  *thumb_view)
{
  switch (event_type)
  {
    case G_FILE_MONITOR_EVENT_DELETED:
      cheese_thumb_view_remove_item (thumb_view, file);
      break;
    case G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT:
      cheese_thumb_view_append_item (thumb_view, file);
      break;
    default:
      break;
  }
}

static void
cheese_thumb_view_on_drag_data_get_cb (GtkIconView      *thumb_view,
                                       GdkDragContext   *drag_context,
                                       GtkSelectionData *data,
                                       guint             info,
                                       guint             time,
                                       gpointer          user_data)
{
  GList        *list, *l;
  GtkTreeIter   iter;
  GtkTreeModel *model;
  char         *str;
  char         *uris = NULL;
  char         *tmp_str;

  list  = gtk_icon_view_get_selected_items (thumb_view);
  model = gtk_icon_view_get_model (thumb_view);

  for (l = list; l != NULL; l = l->next)
  {
    gtk_tree_model_get_iter (model, &iter, l->data);
    gtk_tree_model_get (model, &iter, 1, &str, -1);
    gtk_tree_path_free (l->data);

    /* we always store local paths in the model, but DnD
     * needs URIs, so we must add file:// to the path.
     */

    /* build the "text/uri-list" string */
    if (uris)
    {
      tmp_str = g_strconcat (uris, "file://", str, "\r\n", NULL);
      g_free (uris);
    }
    else
    {
      tmp_str = g_strconcat ("file://", str, "\r\n", NULL);
    }
    uris = tmp_str;

    g_free (str);
  }
  gtk_selection_data_set (data, gtk_selection_data_get_target (data),
                          8, (guchar *) uris, strlen (uris));
  g_free (uris);
  g_list_free (list);
}

static char *
cheese_thumb_view_get_url_from_path (CheeseThumbView *thumb_view, GtkTreePath *path)
{
  GtkTreeModel *model;
  GtkTreeIter   iter;
  char         *file;

  model = gtk_icon_view_get_model (GTK_ICON_VIEW (thumb_view));
  gtk_tree_model_get_iter (model, &iter, path);

  gtk_tree_model_get (model, &iter, THUMBNAIL_URL_COLUMN, &file, -1);

  return file;
}

char *
cheese_thumb_view_get_selected_image (CheeseThumbView *thumb_view)
{
  GList *list;
  char  *filename = NULL;

  list = gtk_icon_view_get_selected_items (GTK_ICON_VIEW (thumb_view));
  if (list)
  {
    filename = cheese_thumb_view_get_url_from_path (thumb_view, (GtkTreePath *) list->data);
    g_list_foreach (list, (GFunc) gtk_tree_path_free, NULL);
    g_list_free (list);
  }

  return filename;
}

GList *
cheese_thumb_view_get_selected_images_list (CheeseThumbView *thumb_view)
{
  GList *l, *item;
  GList *list = NULL;
  GFile *file;

  GtkTreePath *path;

  l = gtk_icon_view_get_selected_items (GTK_ICON_VIEW (thumb_view));

  for (item = l; item != NULL; item = item->next)
  {
    path = (GtkTreePath *) item->data;
    file = g_file_new_for_path (cheese_thumb_view_get_url_from_path (thumb_view, path));
    list = g_list_prepend (list, file);
    gtk_tree_path_free (path);
  }

  g_list_free (l);
  list = g_list_reverse (list);

  return list;
}

static void
cheese_thumb_view_get_n_selected_helper (GtkIconView *thumbview,
                                         GtkTreePath *path,
                                         gpointer     data)
{
  /* data is of type (guint *) */
  (*(guint *) data)++;
}

guint
cheese_thumb_view_get_n_selected (CheeseThumbView *thumbview)
{
  guint count = 0;

  gtk_icon_view_selected_foreach (GTK_ICON_VIEW (thumbview),
                                  cheese_thumb_view_get_n_selected_helper,
                                  (&count));
  return count;
}

static void
cheese_thumb_view_fill (CheeseThumbView *thumb_view)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  GDir       *dir_videos, *dir_photos;
  const char *path_videos, *path_photos;
  const char *name;
  char       *filename;
  GFile      *file;

  gtk_list_store_clear (priv->store);

  path_videos = cheese_fileutil_get_video_path (priv->fileutil);
  path_photos = cheese_fileutil_get_photo_path (priv->fileutil);

  dir_videos = g_dir_open (path_videos, 0, NULL);
  dir_photos = g_dir_open (path_photos, 0, NULL);

  if (!dir_videos && !dir_photos)
    return;

  priv->multiplex_thumbnail_generator = FALSE;
  char *multiplex_file = g_build_filename (path_photos, "cheese, cheese, cheese! all i want is cheese", NULL);
  if (g_file_test (multiplex_file, G_FILE_TEST_EXISTS))
    priv->multiplex_thumbnail_generator = !priv->multiplex_thumbnail_generator;
  g_free (multiplex_file);

  if (dir_videos)
  {
    /* read videos from the vid directory */
    while ((name = g_dir_read_name (dir_videos)))
    {
      if (!(g_str_has_suffix (name, CHEESE_VIDEO_NAME_SUFFIX))
        && !(g_str_has_suffix (name, CHEESE_OLD_VIDEO_NAME_SUFFIX)))
        continue;

      filename = g_build_filename (path_videos, name, NULL);
      file     = g_file_new_for_path (filename);
      cheese_thumb_view_append_item (thumb_view, file);
      g_free (filename);
      g_object_unref (file);
    }
    g_dir_close (dir_videos);
    cheese_thumb_view_start_monitoring_video_path (thumb_view, path_videos);
  }

  if (dir_photos)
  {
    /* read photos from the photo directory */
    while ((name = g_dir_read_name (dir_photos)))
    {
      if (!(g_str_has_suffix (name, CHEESE_PHOTO_NAME_SUFFIX)))
        continue;

      filename = g_build_filename (path_photos, name, NULL);
      file     = g_file_new_for_path (filename);
      cheese_thumb_view_append_item (thumb_view, file);
      g_free (filename);
      g_object_unref (file);
    }
    g_dir_close (dir_photos);
    cheese_thumb_view_start_monitoring_photo_path (thumb_view, path_photos);
  }
}

static void
cheese_thumb_view_finalize (GObject *object)
{
  CheeseThumbView        *thumb_view = CHEESE_THUMB_VIEW (object);
  CheeseThumbViewPrivate *priv       = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  g_object_unref (priv->store);
  g_object_unref (priv->fileutil);
  g_object_unref (priv->factory);
  g_file_monitor_cancel (priv->photo_file_monitor);
  g_file_monitor_cancel (priv->video_file_monitor);
  g_queue_free (priv->thumbnails);

  G_OBJECT_CLASS (cheese_thumb_view_parent_class)->finalize (object);
}

static void
cheese_thumb_view_class_init (CheeseThumbViewClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->constructed = cheese_thumb_view_constructed;
  object_class->finalize = cheese_thumb_view_finalize;

  g_type_class_add_private (klass, sizeof (CheeseThumbViewPrivate));
}

static void
cheese_thumb_view_row_inserted_cb (GtkTreeModel    *tree_model,
                                   GtkTreePath     *path,
                                   GtkTreeIter     *iter,
                                   CheeseThumbView *thumb_view)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  priv->n_items++;
  gtk_widget_set_size_request (GTK_WIDGET (thumb_view), -1, -1);
}

static void
cheese_thumb_view_row_deleted_cb (GtkTreeModel    *tree_model,
                                  GtkTreePath     *path,
                                  CheeseThumbView *thumb_view)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  priv->n_items--;
  if (priv->n_items == 0)
    gtk_widget_set_size_request (GTK_WIDGET (thumb_view),
                                 THUMB_VIEW_MINIMUM_WIDTH,
                                 THUMB_VIEW_MINIMUM_HEIGHT);
}

static void
cheese_thumb_view_init (CheeseThumbView *thumb_view)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  priv->video_file_monitor = NULL;
  priv->photo_file_monitor = NULL;

  cheese_thumbnail_init ();

  priv->store   = gtk_list_store_new (3, GDK_TYPE_PIXBUF, G_TYPE_STRING, G_TYPE_STRING);
  priv->n_items = 0;
  priv->idle_id = 0;
  priv->thumbnails = g_queue_new ();
  
  priv->fileutil = cheese_fileutil_new ();
  priv->factory = gnome_desktop_thumbnail_factory_new (GNOME_DESKTOP_THUMBNAIL_SIZE_NORMAL);


  g_signal_connect (G_OBJECT (priv->store),
                    "row-inserted",
                    G_CALLBACK (cheese_thumb_view_row_inserted_cb),
                    thumb_view);
  g_signal_connect (G_OBJECT (priv->store),
                    "row-deleted",
                    G_CALLBACK (cheese_thumb_view_row_deleted_cb),
                    thumb_view);

  g_signal_connect (G_OBJECT (thumb_view), "drag-data-get",
                    G_CALLBACK (cheese_thumb_view_on_drag_data_get_cb), NULL);
                    
  /* We do the rest of the initialization in our constructed() implementation,
   * because GtkIconView may not be ready for us to do more now.
   * See https://bugzilla.gnome.org/show_bug.cgi?id=643286#c6
   */
}

static void
cheese_thumb_view_constructed (GObject *object)
{
  CheeseThumbView *thumb_view = CHEESE_THUMB_VIEW (object);
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);
  
  gtk_icon_view_set_model (GTK_ICON_VIEW (thumb_view), GTK_TREE_MODEL (priv->store));

  gtk_widget_set_size_request (GTK_WIDGET (thumb_view),
                               THUMB_VIEW_MINIMUM_WIDTH,
                               THUMB_VIEW_MINIMUM_HEIGHT);

  gtk_icon_view_set_margin (GTK_ICON_VIEW (thumb_view), 0);
  gtk_icon_view_set_row_spacing (GTK_ICON_VIEW (thumb_view), 0);
  gtk_icon_view_set_column_spacing (GTK_ICON_VIEW (thumb_view), 0);

  gtk_icon_view_set_pixbuf_column (GTK_ICON_VIEW (thumb_view), 0);

  gtk_icon_view_set_columns (GTK_ICON_VIEW (thumb_view), G_MAXINT);

  gtk_icon_view_enable_model_drag_source (GTK_ICON_VIEW (thumb_view), GDK_BUTTON1_MASK,
                                          target_table, G_N_ELEMENTS (target_table),
                                          GDK_ACTION_COPY);
  gtk_icon_view_set_selection_mode (GTK_ICON_VIEW (thumb_view), GTK_SELECTION_MULTIPLE);

  gtk_tree_sortable_set_sort_column_id (GTK_TREE_SORTABLE (priv->store),
                                        THUMBNAIL_BASENAME_URL_COLUMN, GTK_SORT_ASCENDING);
                                        
  cheese_thumb_view_fill (thumb_view);
}

GtkWidget *
cheese_thumb_view_new ()
{
  CheeseThumbView *thumb_view;

  thumb_view = g_object_new (CHEESE_TYPE_THUMB_VIEW, NULL);
  return GTK_WIDGET (thumb_view);
}

void
cheese_thumb_view_start_monitoring_photo_path (CheeseThumbView *thumb_view, const char *path_photos)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  if (priv->photo_file_monitor != NULL)
    return;

  GFile *file;

  /* connect signal to photo path */
  file                     = g_file_new_for_path (path_photos);
  priv->photo_file_monitor = g_file_monitor_directory (file, 0, NULL, NULL);
  g_signal_connect (priv->photo_file_monitor, "changed", G_CALLBACK (cheese_thumb_view_monitor_cb), thumb_view);

  g_object_unref (file);

}

void
cheese_thumb_view_start_monitoring_video_path (CheeseThumbView *thumb_view, const char *path_videos)
{
  CheeseThumbViewPrivate *priv = CHEESE_THUMB_VIEW_GET_PRIVATE (thumb_view);

  if (priv->video_file_monitor != NULL)
    return;

  GFile *file;

  /* connect signal to video path */
  file                     = g_file_new_for_path (path_videos);
  priv->video_file_monitor = g_file_monitor_directory (file, 0, NULL, NULL);
  g_signal_connect (priv->video_file_monitor, "changed", G_CALLBACK (cheese_thumb_view_monitor_cb), thumb_view);

  g_object_unref (file);

}
