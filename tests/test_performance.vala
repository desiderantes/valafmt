/* test_performance.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Performance and single-pass convergence smoke tests for valafmt.
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
	private static void test_single_pass_convergence () {
		string code = """
namespace PerformanceTest {
	public class Controller : Object {
		private string _name;
		public Controller (string name) {
			this._name = name;
		}

		public async void process_data (string[] items) throws Error {
			foreach (var item in items) {
				if (item.length > 0) {
					stdout.printf ("Item: %s\n", item);
				} else {
					printerr ("Empty item\n");
				}
			}
		}
	}
}
""";
		var engine = TestSupport.create_engine ();
		try {
			string pass1 = engine.format_single_pass (code, "single_pass.vala");
			string pass2 = engine.format_single_pass (pass1, "single_pass.vala");
			TestSupport.assert_equal_with_diff (pass1, pass2, "true single-pass convergence");
		} catch (Error e) {
			Test.message ("Single-pass convergence failed: %s", e.message);
			Test.fail ();
		}
	}

	private static void test_formatting_throughput_smoke () {
		string code = """
namespace Bench {
	public class Item {
		public string id { get; set; }
		public int count { get; set; }

		public Item (string id, int count) {
			this.id = id;
			this.count = count;
		}
	}
}
""";
		var engine = TestSupport.create_engine ();
		int iterations = 100;
		var timer = new Timer ();
		for (int i = 0; i < iterations; i++) {
			try {
				string out_code = engine.format (code, "bench.vala");
				assert_true (out_code.length > 0);
			} catch (Error e) {
				Test.message ("Engine.format failed during throughput smoke: %s", e.message);
				Test.fail ();
				return;
			}
		}
		timer.stop ();
		double avg_ms = (timer.elapsed () / (double) iterations) * 1000.0;
		Test.message ("In-process average format time: %.3f ms/call (%d iterations)", avg_ms, iterations);
		assert_cmpfloat (avg_ms, CompareOperator.LT, 25.0);
		int cli_iterations = 20;
		var cli_timer = new Timer ();
		for (int i = 0; i < cli_iterations; i++) {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--stdin" }, code, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 0);
		}
		cli_timer.stop ();
		double cli_avg_ms = (cli_timer.elapsed () / (double) cli_iterations) * 1000.0;
		Test.message ("CLI average invocation time: %.3f ms/call (%d iterations)", cli_avg_ms, cli_iterations);
		assert_cmpfloat (cli_avg_ms, CompareOperator.LT, 100.0);
	}

	public static int main (string[] args) {
		Test.init (ref args);
		Test.add_func ("/performance/single_pass_convergence", test_single_pass_convergence);
		Test.add_func ("/performance/formatting_throughput_smoke", test_formatting_throughput_smoke);
		return Test.run ();
	}
}
