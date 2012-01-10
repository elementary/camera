using Gtk;
using Granite;


namespace Snap.Widgets {
	
	public enum CountdownAction {
	    PHOTO = 0,
	    VIDEO
	}
	
	public class Countdown : Granite.Widgets.CompositedWindow {
		
		Snap.Pipelines pipeline;
		
		public Label count;
		public int time;
		
		public Countdown (SnapWindow window, Snap.Pipelines pipeline) {
			this.time = 5;
			
			this.pipeline = pipeline;

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
			
			var title = new Label ("<span size='20000' color='#fbfbfb'>"+_("Recording starts in")+"</span>");
			title.use_markup = true;
			
			this.count = new Label ("<span size='40000' color='#fbfbfb'>"+time.to_string ()+"</span>");
			this.count.use_markup = true;
			
			box.pack_start (title);
			box.pack_start (count);
			
			this.add (box);
		}
		
		public override bool draw (Cairo.Context ctx){
			int w = this.get_allocated_width  ();
			int h = this.get_allocated_height ();
			Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 4, 4, w-8, h-8, 4);
			ctx.set_source_rgba (0.1, 0.1, 0.1, 0.8);
			ctx.fill ();
			return base.draw (ctx);
		}
		
		public void start (int action){
			
			this.show_all ();
			Timeout.add (1000, () => {
				this.time --;
				count.label = "<span size='40000' color='#fbfbfb'>"+time.to_string ()+"</span>";
				if (time == -1){
					this.destroy ();
					switch (action) {
					    case CountdownAction.PHOTO:
					        pipeline.take_photo ();
					    break;
					    case CountdownAction.VIDEO:
					        pipeline.take_video ();
					    break;
					} 
					return false;
				}
				return true;
			});
		}
		
	}
	
	
}


