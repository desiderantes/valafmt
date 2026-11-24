namespace Showcase {
	public enum TaskStatus {
		PENDING,
		RUNNING,
		COMPLETED,
		FAILED
	}

	public abstract class BaseController<K, V> : Object, Worker<V> {
		private string _name;
		protected BaseController (string name) {
			this._name = name;
		}

		public static inline unowned string get_version () {
			return "1.0.0";
		}

		public override async V execute_task (string task_name, int priority) throws Error {
			if (priority > 10) {
				stdout.printf ("High priority task: %s\n", task_name);
			} else {
				stdout.printf ("Normal task: %s\n", task_name);
			}
			try {
				do_work ();
			} catch (Error e) {
				printerr ("Error in work: %s\n", e.message);
			}
			V? result = null;
			return result;
		}

		protected abstract void do_work () throws Error;
	}

	/**
	 * Generic worker interface
	 */
	public interface Worker<T> : Object {
		public abstract async T execute_task (string task_name, int priority) throws Error;
	}

	public struct TaskInfo<T> {
		public string id;
		public TaskStatus status;
		public T data;
	}

	public delegate void TaskCallback<T> (TaskInfo<T> info);
	[CCode (array_length = false, array_null_terminated = true)]
	public static string[] global_items;
}
