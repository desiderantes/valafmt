namespace Test {
    public class Window {
        public string title { get; set; }
        public int default_width { get; set; }
        public int default_height { get; set; }
    }
    public class ObjTest {
        public void run () {
            var window = new Window () { title = "My App", default_width = 800, default_height = 600 };
        }
    }
}
