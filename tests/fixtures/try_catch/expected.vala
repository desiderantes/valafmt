namespace Test {
	public class ErrorHandling {
		public void process () {
			try {
				do_work ();
			} catch (Error e) {
				stderr.printf ("Error: %s\n", e.message);
			} finally {
				cleanup ();
			}
		}

		private void do_work () throws Error {
		}

		private void cleanup () {
		}
	}
}
