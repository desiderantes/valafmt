namespace Test {
	public class CurlyTest {
		public void check (int x) {
			if (x > 0) {
				stdout.printf ("positive\n");
			} else {
				stdout.printf ("zero or negative\n");
			}
			while (x > 0) {
				x--;
			}
		}
	}
}
