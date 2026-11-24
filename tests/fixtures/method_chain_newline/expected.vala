namespace Test {
	public delegate bool DelegateFunc (Item item);
	public class Item {
		public bool is_valid () {
			return true;
		}

		public string get_name () {
			return "item";
		}
	}

	public class List {
		public List filter (DelegateFunc f) {
			return this;
		}

		public List map (DelegateFunc f) {
			return this;
		}

		public string collect () {
			return "";
		}
	}

	public class ChainTest {
		public void run () {
			var res = get_items ().filter ((x) => x.is_valid ()).map ((x) => x.get_name ()).collect ();
		}

		private List get_items () {
			return new List ();
		}
	}
}
