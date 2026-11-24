namespace Test {
	public class SwitchTest {
		public void process (int state) {
			switch (state) {
				case 1:
					do_work ();
					break;
				default:
					do_default ();
					break;
			}
		}

		private void do_work () {
		}

		private void do_default () {
		}
	}
}
