/* test_idempotency_sampler.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Sweeps test fixtures and complex code samples, asserting format(x) == format(format(x)).
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
	private static void check_idempotency (string code_input, string label) {
		var engine = TestSupport.create_engine ();
		try {
			string pass1 = engine.format_single_pass (code_input, label);
			string pass2 = engine.format_single_pass (pass1, label);
			TestSupport.assert_equal_with_diff (pass1, pass2, @"single-pass idempotency ($label)");
		} catch (Error e) {
			Test.message ("Single-pass format failed for %s: %s", label, e.message);
			Test.fail ();
		}
	}

	private static void test_fixture_idempotency_sampler () {
		string? fixtures_dir = Environment.get_variable ("VALAFMT_FIXTURES_DIR");
		if (fixtures_dir == null || fixtures_dir.length == 0) {
			fixtures_dir = "tests/fixtures";
		}
		int checked = 0;
		try {
			var dir = Dir.open (fixtures_dir);
			string? name = null;
			while ((name = dir.read_name ()) != null) {
				string input_path = Path.build_filename (fixtures_dir, name, "input.vala");
				if (FileUtils.test (input_path, FileTest.IS_REGULAR)) {
					string content = TestSupport.read_file_or_fail (input_path);
					check_idempotency (content, input_path);
					checked++;
				}
			}
		} catch (FileError e) {
			Test.message ("Failed to scan fixtures directory %s: %s", fixtures_dir, e.message);
			Test.fail ();
			return;
		}
		assert_cmpint (checked, CompareOperator.GT, 0);
	}

	private static void test_complex_code_samples_idempotency () {
		string[] samples = {
			"""
namespace Sample1 {
	[CCode (array_length = false, array_null_terminated = true, cname = "sample_func")]
	public static string[] get_samples (int count, string prefix = "item") {
		var list = new GenericArray<string> ();
		for (int i = 0; i < count; i++) {
			list.add (@"$(prefix)_$(i)");
		}
		return list.data;
	}
}
""",
			"""
namespace Sample2 {
	public interface Listener {
		public abstract void on_event (string event_name, int status_code);
	}

	public class Dispatcher : Object, Listener {
		public void on_event (string event_name, int status_code) {
			switch (status_code) {
				case 200:
					stdout.printf ("Success: %s\n", event_name);
					break;
				case 404:
					printerr ("Not found: %s\n", event_name);
					break;
				default:
					printerr ("Unknown status: %d\n", status_code);
					break;
			}
		}
	}
}
"""
		};
		for (int i = 0; i < samples.length; i++) {
			check_idempotency (samples[i], @"complex_sample_$i");
		}
	}

	public static int main (string[] args) {
		Test.init (ref args);
		Test.add_func ("/idempotency/all_fixtures", test_fixture_idempotency_sampler);
		Test.add_func ("/idempotency/complex_samples", test_complex_code_samples_idempotency);
		return Test.run ();
	}
}
