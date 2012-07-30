using Gtk;
namespace Eog
{
  [CCode (cheader_filename = "thumbview/eog-thumb-nav.h")]
  public class ThumbNav : Gtk.Box
  {
    public ThumbNav (Gtk.Widget thumbview, bool show_buttons);
    public bool get_show_buttons ();
    public void set_show_buttons (bool show_buttons);
    public bool is_vertical ();
    public void set_vertical (bool vertical);
    public void set_policy (Gtk.PolicyType hscrollbar_policy,
                            Gtk.PolicyType vscrollbar_policy);
  }
}
