namespace Test {
    [DBus (name = "org.example.App")] public class Service : Object {
        public void execute ([CCode (array_length = false)] string[] args) {}
    }
}
