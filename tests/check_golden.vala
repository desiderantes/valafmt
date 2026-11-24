/* check_golden.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Single-fixture golden test runner for Meson using GLib.Test.
 * Usage: check_golden [--tap] <valafmt_bin> <input_file> <expected_file>
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
	private static string valafmt_bin_path;
	private static string input_file_path;
	private static string expected_file_path;
	private static void test_golden_fixture () {
		assert_true (FileUtils.test (valafmt_bin_path, FileTest.EXISTS));
		Environment.set_variable ("VALAFMT_BIN", valafmt_bin_path, true);
		string expected_text = TestSupport.read_file_or_fail (expected_file_path);
		string formatted_text = "";
		string stderr_text = "";
		int rc1 = TestSupport.run_cli ({ "--stdout", input_file_path }, null, out formatted_text, out stderr_text);
		if (rc1 != 0) {
			Test.message ("valafmt --stdout failed (%d): %s", rc1, stderr_text);
			Test.fail ();
			return;
		}
		string fixture_dir = Path.get_basename (Path.get_dirname (input_file_path));
		TestSupport.assert_equal_with_diff (expected_text, formatted_text, @"golden output ($fixture_dir)");
		string idempotent_text = "";
		string stderr_text2 = "";
		int rc2 = TestSupport.run_cli ({ "--stdin" }, formatted_text, out idempotent_text, out stderr_text2);
		if (rc2 != 0) {
			Test.message ("valafmt --stdin failed (%d): %s", rc2, stderr_text2);
			Test.fail ();
			return;
		}
		TestSupport.assert_equal_with_diff (formatted_text, idempotent_text, @"idempotency ($fixture_dir)");
	}

	public static int main (string[] args) {
		Test.init (ref args);
		if (args.length < 4) {
			printerr ("Usage: check_golden [--tap] <valafmt_bin> <input_file> <expected_file>\n");
			return 1;
		}
		valafmt_bin_path = args[1];
		input_file_path = args[2];
		expected_file_path = args[3];
		string fixture_name = Path.get_basename (Path.get_dirname (input_file_path));
		Test.add_func (@"/golden/$fixture_name", test_golden_fixture);
		return Test.run ();
	}
}
