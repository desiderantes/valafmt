/* test_support.vala
 *
 * Copyright (C) 2026 valafmt contributors
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
using Valafmt;
namespace ValafmtTests {
	public class TestSupport : GLib.Object {
		public static string get_valafmt_bin () {
			string? env_bin = Environment.get_variable ("VALAFMT_BIN");
			if (env_bin != null && env_bin.length > 0) {
				return env_bin;
			}
			return "./build/src/valafmt";
		}

		public static Engine create_engine () {
			return new Engine (Config.get_default ());
		}

		public static string format_or_fail (string code, string filename = "input.vala") {
			var engine = create_engine ();
			try {
				return engine.format (code, filename);
			} catch (Error e) {
				Test.message ("valafmt format failed for %s: %s", filename, e.message);
				Test.fail ();
				return "";
			}
		}

		public static GenericArray<Diagnostic> lint_or_fail (string code, string filename = "input.vala") {
			var engine = create_engine ();
			try {
				return engine.lint (code, filename);
			} catch (Error e) {
				Test.message ("valafmt lint failed for %s: %s", filename, e.message);
				Test.fail ();
				return new GenericArray<Diagnostic> ();
			}
		}

		public static int run_cli (string[] args, string? stdin_text, out string stdout_text, out string stderr_text) {
			stdout_text = "";
			stderr_text = "";
			var argv = new GenericArray<string> ();
			argv.add (get_valafmt_bin ());
			foreach (unowned string a in args) {
				argv.add (a);
			}
			SubprocessFlags flags = SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE;
			if (stdin_text != null) {
				flags |= SubprocessFlags.STDIN_PIPE;
			}
			try {
				var launcher = new SubprocessLauncher (flags);
				string[] cmd = new string[argv.length];
				for (int i = 0; i < argv.length; i++) {
					cmd[i] = argv.get (i);
				}
				Subprocess proc = launcher.spawnv (cmd);
				string? out_buf = null;
				string? err_buf = null;
				proc.communicate_utf8 (stdin_text, null, out out_buf, out err_buf);
				stdout_text = out_buf ?? "";
				stderr_text = err_buf ?? "";
				if (proc.get_if_exited ()) {
					return proc.get_exit_status ();
				}
				return -1;
			} catch (Error e) {
				stderr_text = e.message;
				Test.message ("Failed to spawn valafmt subprocess: %s", e.message);
				Test.fail ();
				return -1;
			}
		}

		public static string make_temp_vala_file (string content) {
			try {
				string tmp_path = "";
				int fd = FileUtils.open_tmp ("valafmt-test-XXXXXX.vala", out tmp_path);
				FileUtils.close (fd);
				FileUtils.set_contents (tmp_path, content);
				return tmp_path;
			} catch (Error e) {
				Test.message ("Failed to create temporary Vala file: %s", e.message);
				Test.fail ();
				return "";
			}
		}

		public static string make_temp_dir () {
			try {
				return DirUtils.make_tmp ("valafmt-test-dir-XXXXXX");
			} catch (Error e) {
				Test.message ("Failed to create temporary directory: %s", e.message);
				Test.fail ();
				return "";
			}
		}

		public static void remove_recursive (string path) {
			if (!FileUtils.test (path, FileTest.EXISTS)) {
				return;
			}
			if (FileUtils.test (path, FileTest.IS_DIR)) {
				try {
					var dir = Dir.open (path);
					string? name = null;
					while ((name = dir.read_name ()) != null) {
						remove_recursive (Path.build_filename (path, name));
					}
					DirUtils.remove (path);
				} catch (Error e) {
					Test.message ("Warning cleaning directory %s: %s", path, e.message);
				}
			} else {
				FileUtils.unlink (path);
			}
		}

		public static string read_file_or_fail (string path) {
			try {
				string content = "";
				FileUtils.get_contents (path, out content);
				return content;
			} catch (Error e) {
				Test.message ("Failed to read file %s: %s", path, e.message);
				Test.fail ();
				return "";
			}
		}

		public static void write_file_or_fail (string path, string content) {
			try {
				string parent = Path.get_dirname (path);
				DirUtils.create_with_parents (parent, 0755);
				FileUtils.set_contents (path, content);
			} catch (Error e) {
				Test.message ("Failed to write file %s: %s", path, e.message);
				Test.fail ();
			}
		}

		public static void assert_equal_with_diff (string expected, string actual, string label) {
			if (expected == actual) {
				return;
			}
			string[] exp_lines = expected.split ("\n");
			string[] act_lines = actual.split ("\n");
			int max_lines = exp_lines.length > act_lines.length ? exp_lines.length : act_lines.length;
			var sb = new StringBuilder ();
			sb.append (@"Mismatch in $label (expected $(exp_lines.length) lines, actual $(act_lines.length) lines):\n");
			int shown = 0;
			for (int i = 0; i < max_lines; i++) {
				string e_line = i < exp_lines.length ? exp_lines[i] : "<EOF>";
				string a_line = i < act_lines.length ? act_lines[i] : "<EOF>";
				if (e_line != a_line) {
					sb.append (@"  line $(i + 1):\n");
					sb.append (@"    - expected: $(e_line.escape ()) \n");
					sb.append (@"    + actual  : $(a_line.escape ())\n");
					shown++;
					if (shown >= 12) {
						sb.append ("  ... (more differences omitted)\n");
						break;
					}
				}
			}
			Test.message ("%s", sb.str);
			Test.fail ();
		}

		public static void assert_contains (string haystack, string needle, string context = "") {
			if (!haystack.contains (needle)) {
				string prefix = context.length > 0 ? context + ": " : "";
				Test.message ("%sExpected substring %s not found in:\n%s", prefix, needle.escape (), haystack);
				Test.fail ();
			}
		}

		public static void assert_not_contains (string haystack, string needle, string context = "") {
			if (haystack.contains (needle)) {
				string prefix = context.length > 0 ? context + ": " : "";
				Test.message ("%sUnexpected substring %s found in:\n%s", prefix, needle.escape (), haystack);
				Test.fail ();
			}
		}
	}
}
