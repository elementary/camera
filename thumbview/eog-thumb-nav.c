/* Eye Of Gnome - Thumbnail Navigator
 *
 * Copyright (C) 2006 The Free Software Foundation
 *
 * Author: Lucas Rocha <lucasr@gnome.org>
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
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifdef HAVE_CONFIG_H
  #include <cheese-config.h>
#endif

#include "eog-thumb-nav.h"
#include "cheese-thumb-view.h"

#include <glib.h>
#include <glib/gi18n.h>
#include <glib-object.h>
#include <gtk/gtk.h>
#include <string.h>
#include <math.h>

#define EOG_THUMB_NAV_GET_PRIVATE(object) \
  (G_TYPE_INSTANCE_GET_PRIVATE ((object), EOG_TYPE_THUMB_NAV, EogThumbNavPrivate))

G_DEFINE_TYPE (EogThumbNav, eog_thumb_nav, GTK_TYPE_BOX);

#define EOG_THUMB_NAV_SCROLL_INC     20
#define EOG_THUMB_NAV_SCROLL_MOVE    20
#define EOG_THUMB_NAV_SCROLL_TIMEOUT 20

enum
{
  PROP_SHOW_BUTTONS = 1,
  PROP_THUMB_VIEW,
  PROP_MODE
};

struct _EogThumbNavPrivate
{
  gboolean show_buttons;
  gboolean vertical;
  gboolean scroll_dir;
  gint scroll_pos;
  gint scroll_id;

  GtkWidget *button_up;
  GtkWidget *button_down;
  GtkWidget *button_left;
  GtkWidget *button_right;
  GtkWidget *sw;
  GtkWidget *thumbview;
  GtkWidget *vbox;
  GtkAdjustment *hadj;
  GtkAdjustment *vadj;
  GtkAdjustment *adj;
};

static gboolean
eog_thumb_nav_scroll_event (GtkWidget *widget, GdkEventScroll *event, gpointer user_data)
{
  EogThumbNav *nav = EOG_THUMB_NAV (user_data);
  gint         inc = EOG_THUMB_NAV_SCROLL_INC * 3;
  gdouble      value, upper, page_size, delta_x, delta_y;
  gboolean smooth;

  nav->priv->adj = nav->priv->vertical ? nav->priv->vadj : nav->priv->hadj;

  switch (event->direction)
  {
#if GTK_CHECK_VERSION (3, 3, 18)
    /* Handle smooth scroll events from mouse wheels, bug 672311. */
    case GDK_SCROLL_SMOOTH:
      smooth = gdk_event_get_scroll_deltas ((const GdkEvent *) event,
                                            &delta_x, &delta_y);
      /* Pass through non-mouse wheel events. */
      if (G_UNLIKELY (!smooth) || delta_x != 0.0 || fabs (delta_y) != 1.0)
        return FALSE;

      inc *= (gint) delta_y;
      break;
#endif
    case GDK_SCROLL_UP:
    case GDK_SCROLL_LEFT:
      inc *= -1;
      break;

    case GDK_SCROLL_DOWN:
    case GDK_SCROLL_RIGHT:
      break;

    default:
      g_assert_not_reached ();
      return FALSE;
  }

  value = gtk_adjustment_get_value (nav->priv->adj);
  if (inc < 0)
    gtk_adjustment_set_value (nav->priv->adj, MAX (0, value + inc));
  else
  {
    upper     = gtk_adjustment_get_upper (nav->priv->adj);
    page_size = gtk_adjustment_get_page_size (nav->priv->adj);
    gtk_adjustment_set_value (nav->priv->adj, MIN (upper - page_size, value + inc));
  }

  gtk_adjustment_value_changed (nav->priv->adj);

  return TRUE;
}

static void
eog_thumb_nav_vadj_changed (GtkAdjustment *vadj, gpointer user_data)
{
  EogThumbNav        *nav;
  EogThumbNavPrivate *priv;
  gboolean            ltr;
  gdouble             value, upper, page_size;

  nav  = EOG_THUMB_NAV (user_data);
  priv = EOG_THUMB_NAV_GET_PRIVATE (nav);
  ltr  = gtk_widget_get_direction (priv->sw) == GTK_TEXT_DIR_LTR;

  g_object_get (vadj,
                "value", &value,
                "upper", &upper,
                "page_size", &page_size,
                NULL);
  gtk_widget_set_sensitive (priv->button_up, value > 0);

  gtk_widget_set_sensitive (priv->button_down,
                            value < upper - page_size);
}

static void
eog_thumb_nav_hadj_changed (GtkAdjustment *hadj, gpointer user_data)
{
  EogThumbNav        *nav;
  EogThumbNavPrivate *priv;
  gboolean            ltr;
  gdouble             value, upper, page_size;

  nav  = EOG_THUMB_NAV (user_data);
  priv = EOG_THUMB_NAV_GET_PRIVATE (nav);
  ltr  = gtk_widget_get_direction (priv->sw) == GTK_TEXT_DIR_LTR;

  g_object_get (hadj,
                "value", &value,
                "upper", &upper,
                "page_size", &page_size,
                NULL);

  gtk_widget_set_sensitive (ltr ? priv->button_right : priv->button_left,
                            value < upper - page_size);
}

static void
eog_thumb_nav_vadj_value_changed (GtkAdjustment *vadj, gpointer user_data)
{
  EogThumbNav        *nav;
  EogThumbNavPrivate *priv;
  gboolean            ltr;
  gdouble             value, upper, page_size;

  nav  = EOG_THUMB_NAV (user_data);
  priv = EOG_THUMB_NAV_GET_PRIVATE (nav);
  ltr  = gtk_widget_get_direction (priv->sw) == GTK_TEXT_DIR_LTR;

  g_object_get (vadj,
                "value", &value,
                "upper", &upper,
                "page_size", &page_size,
                NULL);

  gtk_widget_set_sensitive (priv->button_up, value > 0);

  gtk_widget_set_sensitive (priv->button_down,
                            value < upper - page_size);
}

static void
eog_thumb_nav_hadj_value_changed (GtkAdjustment *hadj, gpointer user_data)
{
  EogThumbNav        *nav;
  EogThumbNavPrivate *priv;
  gboolean            ltr;
  gdouble             value, upper, page_size;

  nav  = EOG_THUMB_NAV (user_data);
  priv = EOG_THUMB_NAV_GET_PRIVATE (nav);
  ltr  = gtk_widget_get_direction (priv->sw) == GTK_TEXT_DIR_LTR;

  g_object_get (hadj,
                "value", &value,
                "upper", &upper,
                "page_size", &page_size,
                NULL);

  gtk_widget_set_sensitive (ltr ? priv->button_left : priv->button_right, value > 0);

  gtk_widget_set_sensitive (ltr ? priv->button_right : priv->button_left,
                            value < upper - page_size);
}

static gboolean
eog_thumb_nav_scroll_step (gpointer user_data)
{
  EogThumbNav *nav = EOG_THUMB_NAV (user_data);
  gint         delta;
  gdouble      value, upper, page_size;

  if (nav->priv->scroll_pos < 10)
    delta = EOG_THUMB_NAV_SCROLL_INC;
  else if (nav->priv->scroll_pos < 20)
    delta = EOG_THUMB_NAV_SCROLL_INC * 2;
  else if (nav->priv->scroll_pos < 30)
    delta = EOG_THUMB_NAV_SCROLL_INC * 2 + 5;
  else
    delta = EOG_THUMB_NAV_SCROLL_INC * 2 + 12;

  if (!nav->priv->scroll_dir)
    delta *= -1;

  g_object_get (nav->priv->adj,
                "value", &value,
                "upper", &upper,
                "page_size", &page_size,
                NULL);

  if ((gint) (value + (gdouble) delta) >= 0 &&
      (gint) (value + (gdouble) delta) <= upper - page_size)
  {
    gtk_adjustment_set_value (nav->priv->adj, value + (gdouble) delta);
    nav->priv->scroll_pos++;
    gtk_adjustment_value_changed (nav->priv->adj);
  }
  else
  {
    if (delta > 0)
      gtk_adjustment_set_value (nav->priv->adj, upper - page_size);
    else
      gtk_adjustment_set_value (nav->priv->adj, 0);

    nav->priv->scroll_pos = 0;

    gtk_adjustment_value_changed (nav->priv->adj);

    return G_SOURCE_REMOVE;
  }

  return G_SOURCE_CONTINUE;
}

static void
eog_thumb_nav_button_clicked (GtkButton *button, EogThumbNav *nav)
{
  nav->priv->scroll_pos = 0;

  if ((GTK_WIDGET (button) == nav->priv->button_right) ||
      (GTK_WIDGET (button) == nav->priv->button_left))
  {
    nav->priv->scroll_dir = gtk_widget_get_direction (GTK_WIDGET (button)) == GTK_TEXT_DIR_LTR ?
                            GTK_WIDGET (button) == nav->priv->button_right :
                            GTK_WIDGET (button) == nav->priv->button_left;
  }
  else
  {
    nav->priv->scroll_dir = (GTK_WIDGET (button) == nav->priv->button_down);
  }

  nav->priv->adj = ((GTK_WIDGET (button) == nav->priv->button_right) ||
                    (GTK_WIDGET (button) == nav->priv->button_left)) ? nav->priv->hadj : nav->priv->vadj;

  eog_thumb_nav_scroll_step (nav);
}

static void
eog_thumb_nav_start_scroll (GtkButton *button, EogThumbNav *nav)
{
  if ((GTK_WIDGET (button) == nav->priv->button_right) ||
      (GTK_WIDGET (button) == nav->priv->button_left))
  {
    nav->priv->scroll_dir = gtk_widget_get_direction (GTK_WIDGET (button)) == GTK_TEXT_DIR_LTR ?
                            GTK_WIDGET (button) == nav->priv->button_right :
                            GTK_WIDGET (button) == nav->priv->button_left;
  }
  else
  {
    nav->priv->scroll_dir = (GTK_WIDGET (button) == nav->priv->button_down);
  }

  nav->priv->adj = ((GTK_WIDGET (button) == nav->priv->button_right) ||
                    (GTK_WIDGET (button) == nav->priv->button_left)) ? nav->priv->hadj : nav->priv->vadj;

  nav->priv->scroll_id = g_timeout_add (EOG_THUMB_NAV_SCROLL_TIMEOUT,
                                        eog_thumb_nav_scroll_step,
                                        nav);
}

static void
eog_thumb_nav_stop_scroll (GtkButton *button, EogThumbNav *nav)
{
  if (nav->priv->scroll_id > 0)
  {
    g_source_remove (nav->priv->scroll_id);
    nav->priv->scroll_id  = 0;
    nav->priv->scroll_pos = 0;
  }
}

static void
eog_thumb_nav_get_property (GObject    *object,
                            guint       property_id,
                            GValue     *value,
                            GParamSpec *pspec)
{
  EogThumbNav *nav = EOG_THUMB_NAV (object);

  switch (property_id)
  {
    case PROP_SHOW_BUTTONS:
      g_value_set_boolean (value,
                           eog_thumb_nav_get_show_buttons (nav));
      break;

    case PROP_THUMB_VIEW:
      g_value_set_object (value, nav->priv->thumbview);
      break;
  }
}

static void
eog_thumb_nav_set_property (GObject      *object,
                            guint         property_id,
                            const GValue *value,
                            GParamSpec   *pspec)
{
  EogThumbNav *nav = EOG_THUMB_NAV (object);

  switch (property_id)
  {
    case PROP_SHOW_BUTTONS:
      eog_thumb_nav_set_show_buttons (nav,
                                      g_value_get_boolean (value));
      break;

    case PROP_THUMB_VIEW:
      nav->priv->thumbview =
        GTK_WIDGET (g_value_get_object (value));
      break;
  }
}

static GObject *
eog_thumb_nav_constructor (GType                  type,
                           guint                  n_construct_properties,
                           GObjectConstructParam *construct_params)
{
  GObject            *object;
  EogThumbNavPrivate *priv;

  object = G_OBJECT_CLASS (eog_thumb_nav_parent_class)->constructor
             (type, n_construct_properties, construct_params);

  priv = EOG_THUMB_NAV_GET_PRIVATE (object);

  if (priv->thumbview != NULL)
  {
    gtk_container_add (GTK_CONTAINER (priv->sw), priv->thumbview);
    gtk_widget_show_all (priv->sw);
  }

  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (priv->sw),
                                  GTK_POLICY_AUTOMATIC,
                                  GTK_POLICY_NEVER);

  return object;
}

static void
eog_thumb_nav_class_init (EogThumbNavClass *class)
{
  GObjectClass *g_object_class = (GObjectClass *) class;

  g_object_class->constructor  = eog_thumb_nav_constructor;
  g_object_class->get_property = eog_thumb_nav_get_property;
  g_object_class->set_property = eog_thumb_nav_set_property;

  g_object_class_install_property (g_object_class,
                                   PROP_SHOW_BUTTONS,
                                   g_param_spec_boolean ("show-buttons",
                                                         "Show Buttons",
                                                         "Whether to show navigation buttons or not",
                                                         TRUE,
                                                         G_PARAM_READWRITE |
                                                         G_PARAM_STATIC_STRINGS));

  g_object_class_install_property (g_object_class,
                                   PROP_THUMB_VIEW,
                                   g_param_spec_object ("thumbview",
                                                        "Thumbnail View",
                                                        "The internal thumbnail viewer widget",
                                                        CHEESE_TYPE_THUMB_VIEW,
                                                        G_PARAM_CONSTRUCT_ONLY |
                                                        G_PARAM_READWRITE |
                                                        G_PARAM_STATIC_STRINGS));

  g_type_class_add_private (g_object_class, sizeof (EogThumbNavPrivate));
}

static void
eog_thumb_nav_init (EogThumbNav *nav)
{
  EogThumbNavPrivate *priv;
  GtkWidget          *arrow;

  nav->priv = EOG_THUMB_NAV_GET_PRIVATE (nav);

  priv = nav->priv;

  priv->show_buttons = TRUE;
  priv->vertical     = FALSE;

  priv->button_left = gtk_button_new ();
  gtk_button_set_relief (GTK_BUTTON (priv->button_left), GTK_RELIEF_NONE);

  arrow = gtk_arrow_new (GTK_ARROW_LEFT, GTK_SHADOW_ETCHED_IN);
  gtk_container_add (GTK_CONTAINER (priv->button_left), arrow);

  gtk_widget_set_size_request (GTK_WIDGET (priv->button_left), 25, 0);

  g_signal_connect (priv->button_left,
                    "clicked",
                    G_CALLBACK (eog_thumb_nav_button_clicked),
                    nav);

  g_signal_connect (priv->button_left,
                    "pressed",
                    G_CALLBACK (eog_thumb_nav_start_scroll),
                    nav);

  g_signal_connect (priv->button_left,
                    "released",
                    G_CALLBACK (eog_thumb_nav_stop_scroll),
                    nav);

  priv->vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);

  priv->sw = gtk_scrolled_window_new (NULL, NULL);

  gtk_widget_set_name (gtk_scrolled_window_get_hscrollbar (GTK_SCROLLED_WINDOW (priv->sw)),
                       "hscrollbar");
  gtk_widget_set_name (gtk_scrolled_window_get_vscrollbar (GTK_SCROLLED_WINDOW (priv->sw)),
                       "vscrollbar");

  gtk_scrolled_window_set_shadow_type (GTK_SCROLLED_WINDOW (priv->sw),
                                       GTK_SHADOW_IN);



  g_signal_connect (priv->sw,
                    "scroll-event",
                    G_CALLBACK (eog_thumb_nav_scroll_event),
                    nav);

  priv->hadj = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (priv->sw));

  g_signal_connect (priv->hadj,
                    "changed",
                    G_CALLBACK (eog_thumb_nav_hadj_changed),
                    nav);

  g_signal_connect (priv->hadj,
                    "value-changed",
                    G_CALLBACK (eog_thumb_nav_hadj_value_changed),
                    nav);

  priv->vadj = gtk_scrolled_window_get_vadjustment (GTK_SCROLLED_WINDOW (priv->sw));

  g_signal_connect (priv->vadj,
                    "changed",
                    G_CALLBACK (eog_thumb_nav_vadj_changed),
                    nav);

  g_signal_connect (priv->vadj,
                    "value-changed",
                    G_CALLBACK (eog_thumb_nav_vadj_value_changed),
                    nav);

  priv->button_right = gtk_button_new ();
  gtk_button_set_relief (GTK_BUTTON (priv->button_right), GTK_RELIEF_NONE);

  arrow = gtk_arrow_new (GTK_ARROW_RIGHT, GTK_SHADOW_NONE);
  gtk_container_add (GTK_CONTAINER (priv->button_right), arrow);

  gtk_widget_set_size_request (GTK_WIDGET (priv->button_right), 25, 0);

  g_signal_connect (priv->button_right,
                    "clicked",
                    G_CALLBACK (eog_thumb_nav_button_clicked),
                    nav);

  g_signal_connect (priv->button_right,
                    "pressed",
                    G_CALLBACK (eog_thumb_nav_start_scroll),
                    nav);

  g_signal_connect (priv->button_right,
                    "released",
                    G_CALLBACK (eog_thumb_nav_stop_scroll),
                    nav);

  priv->button_down = gtk_button_new ();
  gtk_button_set_relief (GTK_BUTTON (priv->button_down), GTK_RELIEF_NONE);

  arrow = gtk_arrow_new (GTK_ARROW_DOWN, GTK_SHADOW_NONE);
  gtk_container_add (GTK_CONTAINER (priv->button_down), arrow);

  gtk_widget_set_size_request (GTK_WIDGET (priv->button_down), 0, 25);

  g_signal_connect (priv->button_down,
                    "clicked",
                    G_CALLBACK (eog_thumb_nav_button_clicked),
                    nav);

  g_signal_connect (priv->button_down,
                    "pressed",
                    G_CALLBACK (eog_thumb_nav_start_scroll),
                    nav);

  g_signal_connect (priv->button_down,
                    "released",
                    G_CALLBACK (eog_thumb_nav_stop_scroll),
                    nav);

  priv->button_up = gtk_button_new ();
  gtk_button_set_relief (GTK_BUTTON (priv->button_up), GTK_RELIEF_NONE);

  arrow = gtk_arrow_new (GTK_ARROW_UP, GTK_SHADOW_NONE);
  gtk_container_add (GTK_CONTAINER (priv->button_up), arrow);

  gtk_widget_set_size_request (GTK_WIDGET (priv->button_up), 0, 25);

  g_signal_connect (priv->button_up,
                    "clicked",
                    G_CALLBACK (eog_thumb_nav_button_clicked),
                    nav);

  g_signal_connect (priv->button_up,
                    "pressed",
                    G_CALLBACK (eog_thumb_nav_start_scroll),
                    nav);

  g_signal_connect (priv->button_up,
                    "released",
                    G_CALLBACK (eog_thumb_nav_stop_scroll),
                    nav);


  g_object_ref (priv->button_up);
  g_object_ref (priv->button_down);
  gtk_box_pack_start (GTK_BOX (nav), priv->button_left, FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (nav), priv->vbox, TRUE, TRUE, 0);
  gtk_box_pack_start (GTK_BOX (nav), priv->button_right, FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (priv->vbox), priv->sw, TRUE, TRUE, 0);

  gtk_adjustment_value_changed (priv->hadj);
}

/**
 * eog_thumb_nav_new:
 * @thumbview: a #CheeseThumbView to embed in the navigation widget.
 * @mode: The navigation mode.
 * @show_buttons: Whether to show the navigation buttons.
 *
 * Creates a new thumbnail navigation widget.
 *
 * Returns: a new #EogThumbNav object.
 **/
GtkWidget *
eog_thumb_nav_new (GtkWidget *thumbview,
                   gboolean   show_buttons)
{
  EogThumbNav        *nav;

  nav = g_object_new (EOG_TYPE_THUMB_NAV,
                      "show-buttons", show_buttons,
                      "thumbview", thumbview,
                      "homogeneous", FALSE,
                      "spacing", 0,
                      NULL);

  return GTK_WIDGET (nav);
}

/**
 * eog_thumb_nav_get_show_buttons:
 * @nav: an #EogThumbNav.
 *
 * Gets whether the navigation buttons are visible.
 *
 * Returns: %TRUE if the navigation buttons are visible,
 * %FALSE otherwise.
 **/
gboolean
eog_thumb_nav_get_show_buttons (EogThumbNav *nav)
{
  g_return_val_if_fail (EOG_IS_THUMB_NAV (nav), FALSE);

  return nav->priv->show_buttons;
}

/**
 * eog_thumb_nav_set_show_buttons:
 * @nav: an #EogThumbNav.
 * @show_buttons: %TRUE to show the buttons, %FALSE to hide them.
 *
 * Sets whether the navigation buttons to the left and right of the
 * widget should be visible.
 **/
void
eog_thumb_nav_set_show_buttons (EogThumbNav *nav, gboolean show_buttons)
{
  g_return_if_fail (EOG_IS_THUMB_NAV (nav));
  g_return_if_fail (nav->priv->button_left != NULL);
  g_return_if_fail (nav->priv->button_right != NULL);

  nav->priv->show_buttons = show_buttons;

  if (show_buttons)
  {
    gtk_widget_show_all (nav->priv->button_left);
    gtk_widget_show_all (nav->priv->button_right);
  }
  else
  {
    gtk_widget_hide (nav->priv->button_left);
    gtk_widget_hide (nav->priv->button_right);
  }
}

void
eog_thumb_nav_set_policy (EogThumbNav  *nav,
                          GtkPolicyType hscrollbar_policy,
                          GtkPolicyType vscrollbar_policy)
{
  EogThumbNavPrivate *priv = EOG_THUMB_NAV_GET_PRIVATE (nav);

  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (priv->sw),
                                  hscrollbar_policy,
                                  vscrollbar_policy);
}

gboolean
eog_thumb_nav_is_vertical (EogThumbNav *nav)
{
  EogThumbNavPrivate *priv = EOG_THUMB_NAV_GET_PRIVATE (nav);

  return priv->vertical;
}

void
eog_thumb_nav_set_vertical (EogThumbNav *nav, gboolean vertical)
{
  EogThumbNavPrivate *priv = EOG_THUMB_NAV_GET_PRIVATE (nav);

  g_return_if_fail (EOG_IS_THUMB_NAV (nav));
  g_return_if_fail (priv->button_left != NULL);
  g_return_if_fail (priv->button_right != NULL);
  g_return_if_fail (priv->vbox != NULL);
  g_return_if_fail (priv->sw != NULL);

  if (vertical == priv->vertical) return;

  /* show/hide doesn't work because of a mandatory show_all in cheese-window */

  if (vertical)
  {
    g_return_if_fail (!gtk_widget_get_parent (priv->button_up));
    g_return_if_fail (!gtk_widget_get_parent (priv->button_down));
    g_return_if_fail (gtk_widget_get_parent (priv->button_left));
    g_return_if_fail (gtk_widget_get_parent (priv->button_right));

    gtk_box_pack_start (GTK_BOX (priv->vbox), priv->button_up, FALSE, FALSE, 0);
    gtk_box_reorder_child (GTK_BOX (priv->vbox), priv->button_up, 0);
    gtk_box_pack_start (GTK_BOX (priv->vbox), priv->button_down, FALSE, FALSE, 0);
    g_object_unref (priv->button_up);
    g_object_unref (priv->button_down);

    g_object_ref (priv->button_left);
    gtk_container_remove (GTK_CONTAINER (nav), priv->button_left);
    g_object_ref (priv->button_right);
    gtk_container_remove (GTK_CONTAINER (nav), priv->button_right);
    gtk_adjustment_value_changed (priv->vadj);

    eog_thumb_nav_set_policy (nav,
                              GTK_POLICY_NEVER,
                              GTK_POLICY_AUTOMATIC);
    priv->vertical = TRUE;
  }
  else
  {
    g_return_if_fail (!gtk_widget_get_parent (priv->button_left));
    g_return_if_fail (!gtk_widget_get_parent (priv->button_right));
    g_return_if_fail (gtk_widget_get_parent (priv->button_up));
    g_return_if_fail (gtk_widget_get_parent (priv->button_down));

    gtk_box_pack_start (GTK_BOX (nav), priv->button_left, FALSE, FALSE, 0);
    gtk_box_reorder_child (GTK_BOX (nav), priv->button_left, 0);
    gtk_box_pack_start (GTK_BOX (nav), priv->button_right, FALSE, FALSE, 0);
    g_object_unref (priv->button_left);
    g_object_unref (priv->button_right);

    g_object_ref (priv->button_up);
    gtk_container_remove (GTK_CONTAINER (priv->vbox), priv->button_up);
    g_object_ref (priv->button_down);
    gtk_container_remove (GTK_CONTAINER (priv->vbox), priv->button_down);
    gtk_adjustment_value_changed (priv->hadj);

    eog_thumb_nav_set_policy (nav,
                              GTK_POLICY_AUTOMATIC,
                              GTK_POLICY_NEVER);
    priv->vertical = FALSE;
  }
  gtk_widget_show_all (GTK_WIDGET (nav));
}
