namespace Test {
	public class ControlFlow {
		public void check (int val) {
			if (val > 0) {
				stdout.printf ("positive\n");
			} else {
				stdout.printf ("non-positive\n");
			}

			while (val > 0) {
				val--;
			}
		}
	}
}
