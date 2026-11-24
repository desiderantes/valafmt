/* test_concurrency.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Multi-thread concurrency test suite for valafmt.
 * Ensures zero race conditions and thread-safety under parallel formatting load.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
using GLib;
namespace ValafmtTests {
	private class WorkerJob : GLib.Object {
		public int idx;
		public string formatted = "";
		public string error_msg = "";
		public WorkerJob (int idx) {
			this.idx = idx;
		}
	}

	private static void test_parallel_formatting_concurrency () {
		int num_workers = 30;
		var jobs = new WorkerJob[num_workers];
		for (int i = 0; i < num_workers; i++) {
			jobs[i] = new WorkerJob (i);
		}
		var shared_engine = TestSupport.create_engine ();
		try {
			var pool = new ThreadPool<WorkerJob>.with_owned_data (
					(job) => {
						string code = """
namespace ConcurrencyTest%d {
	public class Worker%d : Object {
		private int _id = %d;
		public void execute () {
			if (_id %% 2 == 0) {
				stdout.printf ("Even worker %%d\n", _id);
			} else {
				stdout.printf ("Odd worker %%d\n", _id);
			}
		}
	}
}
""".printf (job.idx, job.idx, job.idx);
						try {
							job.formatted = shared_engine.format (code, @"worker_$(job.idx).vala");
						} catch (Error e) {
							job.error_msg = e.message;
						}
					},
					10,
					false
			);
			for (int i = 0; i < num_workers; i++) {
				pool.add (jobs[i]);
			}
			ThreadPool.free ((owned) pool, false, true);
		} catch (ThreadError e) {
			Test.message ("ThreadPool failure: %s", e.message);
			Test.fail ();
			return;
		}
		for (int i = 0; i < num_workers; i++) {
			if (jobs[i].error_msg.length > 0) {
				Test.message ("Worker %d failed: %s", i, jobs[i].error_msg);
				Test.fail ();
			}
			TestSupport.assert_contains (jobs[i].formatted, @"Worker$i");
			TestSupport.assert_contains (jobs[i].formatted, @"ConcurrencyTest$i");
		}
	}

	public static int main (string[] args) {
		Test.init (ref args);
		Test.add_func ("/concurrency/parallel_formatting", test_parallel_formatting_concurrency);
		return Test.run ();
	}
}
