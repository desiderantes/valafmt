namespace Test {
    public class CuddledTest {
        public void run () {
            if (true) {
                do_a ();
            }
            else {
                do_b ();
            }
        }
        private void do_a () {}
        private void do_b () {}
    }
}
