using GLib;
namespace Cheese
{
  [CCode (cheader_filename = "thumbview/cheese-thumb-view.h")]
  public class ThumbView : Gtk.IconView
  {
    public ThumbView ();
    public string          get_selected_image ();
    public List<GLib.File> get_selected_images_list ();
    public int             get_n_selected ();
    public void            remove_item (GLib.File file);
    public void            start_monitoring_photo_path (string path_photos);
    public void            start_monitoring_video_path (string path_videos);
  }
}
