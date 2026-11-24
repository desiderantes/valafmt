namespace Test {
	public abstract class Map<K, V> {
		public abstract V? @get (K key);

		public abstract void put<T> (K key, V val, T metadata);

		protected Map () {
		}
	}

	public interface Iterable<G> {
		public abstract Iterator<G> iterator ();
	}

	public struct Entry<K, V> {
		public K key;
		public V @value;
	}

	public delegate void ProcessFunc<T> (T item);
}
