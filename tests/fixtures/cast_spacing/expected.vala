namespace Test {
	public class CastTest {
		public void run (Object widget) {
			var win = (Gtk.Window) widget;
			var win2 = widget as Gtk.Window;
		}
	}
}
