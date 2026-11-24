/* test_cli.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Integration test suite for valafmt CLI flags and execution modes.
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
	private static void test_stdin () {
		string out_text;
		string err_text;
		int rc = TestSupport.run_cli ({ "--stdin" }, "namespace StdinTest { class App {} }", out out_text, out err_text);
		assert_cmpint (rc, CompareOperator.EQ, 0);
		TestSupport.assert_contains (out_text, "class App", "stdin output");
	}

	private static void test_stdout () {
		string f_path = TestSupport.make_temp_vala_file ("namespace StdoutTest { class App {} }");
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ f_path, "--stdout" }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 0);
			TestSupport.assert_contains (out_text, "class App", "stdout output");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_check_mode () {
		string unformatted_path = TestSupport.make_temp_vala_file ("namespace CheckTest1 { class App {} }");
		string formatted_path = TestSupport.make_temp_vala_file (
				"namespace CheckTest2 {\n\tpublic class App {\n\t}\n}\n"
		);
		try {
			string out_text;
			string err_text;
			// 1. Unformatted file should return exit code 1
			int rc1 = TestSupport.run_cli ({ "--check", unformatted_path }, null, out out_text, out err_text);
			assert_cmpint (rc1, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "Unformatted:", "--check unformatted");
			// 2. Formatted file should return exit code 0
			int rc_fmt = TestSupport.run_cli ({ formatted_path }, null, out out_text, out err_text);
			assert_cmpint (rc_fmt, CompareOperator.EQ, 0);
			int rc2 = TestSupport.run_cli ({ "--check", formatted_path }, null, out out_text, out err_text);
			assert_cmpint (rc2, CompareOperator.EQ, 0);
			// 3. Multi-file check (returns 1 if any file is unformatted)
			int rc_multi = TestSupport.run_cli (
					{ "--check", unformatted_path, formatted_path },
					null,
					out out_text,
					out err_text
			);
			assert_cmpint (rc_multi, CompareOperator.EQ, 1);
			// 4. Stdin check mode (unformatted vs formatted)
			int rc_stdin_unfmt = TestSupport.run_cli (
					{ "--stdin", "--check" },
					"class App {}",
					out out_text,
					out err_text
			);
			assert_cmpint (rc_stdin_unfmt, CompareOperator.EQ, 1);
			string formatted_code;
			int rc_stdin_run = TestSupport.run_cli ({ "--stdin" }, "class App {}", out formatted_code, out err_text);
			assert_cmpint (rc_stdin_run, CompareOperator.EQ, 0);
			int rc_stdin_fmt = TestSupport.run_cli ({ "--stdin", "--check" }, formatted_code, out out_text, out err_text);
			assert_cmpint (rc_stdin_fmt, CompareOperator.EQ, 0);
			// 5. Format in-place, then re-check
			int rc_inplace = TestSupport.run_cli ({ unformatted_path }, null, out out_text, out err_text);
			assert_cmpint (rc_inplace, CompareOperator.EQ, 0);
			int rc_recheck = TestSupport.run_cli ({ "--check", unformatted_path }, null, out out_text, out err_text);
			assert_cmpint (rc_recheck, CompareOperator.EQ, 0);
		} finally {
			TestSupport.remove_recursive (unformatted_path);
			TestSupport.remove_recursive (formatted_path);
		}
	}

	private static void test_output_file () {
		string in_path = TestSupport.make_temp_vala_file ("namespace OutFileTest { class App {} }");
		string out_path = in_path + ".formatted.vala";
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ in_path, "--output-file=" + out_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 0);
			assert_true (FileUtils.test (out_path, FileTest.EXISTS));
			string content = TestSupport.read_file_or_fail (out_path);
			TestSupport.assert_contains (content, "class App", "--output-file content");
		} finally {
			TestSupport.remove_recursive (in_path);
			TestSupport.remove_recursive (out_path);
		}
	}

	private static void test_input_dir_and_output_dir () {
		string in_dir = TestSupport.make_temp_dir ();
		string out_dir = TestSupport.make_temp_dir ();
		try {
			string sample_path = Path.build_filename (in_dir, "sub", "sample.vala");
			TestSupport.write_file_or_fail (sample_path, "namespace DirTest { class App {} }");
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli (
					{ "--input-dir=" + in_dir, "--output-dir=" + out_dir },
					null,
					out out_text,
					out err_text
			);
			assert_cmpint (rc, CompareOperator.EQ, 0);
			string expected_out_file = Path.build_filename (out_dir, "sub", "sample.vala");
			assert_true (FileUtils.test (expected_out_file, FileTest.EXISTS));
			string content = TestSupport.read_file_or_fail (expected_out_file);
			TestSupport.assert_contains (content, "class App", "--input-dir / --output-dir content");
		} finally {
			TestSupport.remove_recursive (in_dir);
			TestSupport.remove_recursive (out_dir);
		}
	}

	private static void test_incompatible_flags () {
		string out_text;
		string err_text;
		int rc = TestSupport.run_cli (
				{ "f1.vala", "f2.vala", "--output-file=out.vala" },
				null,
				out out_text,
				out err_text
		);
		assert_cmpint (rc, CompareOperator.EQ, 1);
		assert_true (err_text.contains ("mutually exclusive") || err_text.contains ("single file"));
		int rc_cl = TestSupport.run_cli ({ "--check", "--lint", "--stdin" }, "class App {}", out out_text, out err_text);
		assert_cmpint (rc_cl, CompareOperator.EQ, 1);
		TestSupport.assert_contains (err_text, "--check and --lint are mutually exclusive", "check+lint conflict");
		int rc_sd = TestSupport.run_cli (
				{ "--stdin", "--output-dir=/tmp/unused" },
				"class App {}",
				out out_text,
				out err_text
		);
		assert_cmpint (rc_sd, CompareOperator.EQ, 1);
		TestSupport.assert_contains (err_text, "--output-dir cannot be used with --stdin", "stdin+output-dir conflict");
		int rc_so = TestSupport.run_cli (
				{ "--stdin", "--stdout", "--output-file=/tmp/unused.vala" },
				"class App {}",
				out out_text,
				out err_text
		);
		assert_cmpint (rc_so, CompareOperator.EQ, 1);
		TestSupport.assert_contains (
				err_text,
				"--stdout and --output-file are mutually exclusive",
				"stdout+output-file conflict"
		);
		int rc_sp = TestSupport.run_cli ({ "--stdin", "extra.vala" }, "class App {}", out out_text, out err_text);
		assert_cmpint (rc_sp, CompareOperator.EQ, 1);
		TestSupport.assert_contains (err_text, "--stdin cannot be used with positional", "stdin+positional conflict");
		int rc_si = TestSupport.run_cli ({ "--stdin", "--input-dir=src" }, "class App {}", out out_text, out err_text);
		assert_cmpint (rc_si, CompareOperator.EQ, 1);
		TestSupport.assert_contains (err_text, "--stdin cannot be used with --input-dir", "stdin+input-dir conflict");
		int rc_sf = TestSupport.run_cli ({ "--stdin-filename=buf.vala", "extra.vala" }, null, out out_text, out err_text);
		assert_cmpint (rc_sf, CompareOperator.EQ, 1);
		TestSupport.assert_contains (
				err_text,
				"--stdin-filename can only be used with --stdin",
				"stdin-filename without stdin"
		);
		int rc_chk_warn = TestSupport.run_cli (
				{ "--stdin", "--check", "--output-file=/tmp/unused.vala" },
				"class App {\n}\n",
				out out_text,
				out err_text
		);
		assert_cmpint (rc_chk_warn, CompareOperator.EQ, 0);
		TestSupport.assert_contains (
				err_text,
				"Warning: Output option '--output-file' is ignored in --check mode.",
				"check warns on output-file"
		);
	}

	private static void test_help_and_stdin_filename () {
		string out_text;
		string err_text;
		int rc_help = TestSupport.run_cli ({ "--help" }, null, out out_text, out err_text);
		assert_cmpint (rc_help, CompareOperator.EQ, 0);
		TestSupport.assert_contains (out_text, "[PATH...]", "help shows PATH synopsis");
		TestSupport.assert_not_contains (out_text, "valafmt ? ", "help has no garbled em-dash");
		int rc_lint = TestSupport.run_cli (
				{ "--stdin", "--lint", "--stdin-filename=editor/buffer.vala" },
				"class bad_name {}\n",
				out out_text,
				out err_text
		);
		assert_cmpint (rc_lint, CompareOperator.EQ, 1);
		TestSupport.assert_contains (out_text, "editor/buffer.vala:", "lint diagnostic uses stdin-filename");
	}

	private static void test_output_dir_collision_and_symlinks () {
		string root = TestSupport.make_temp_dir ();
		string out_dir = TestSupport.make_temp_dir ();
		try {
			string file_a = Path.build_filename (root, "a", "dup.vala");
			string file_b = Path.build_filename (root, "b", "dup.vala");
			TestSupport.write_file_or_fail (file_a, "class FromA {}");
			TestSupport.write_file_or_fail (file_b, "class FromB {}");
			string out_text;
			string err_text;
			// Collision when two external files map to the same output basename
			int rc_coll = TestSupport.run_cli (
					{ file_a, file_b, "--output-dir=" + out_dir },
					null,
					out out_text,
					out err_text
			);
			assert_cmpint (rc_coll, CompareOperator.EQ, 1);
			TestSupport.assert_contains (err_text, "--output-dir target collision", "collision rejected");
			// Cyclic directory symlink must be skipped safely
			string loop_link = Path.build_filename (root, "a", "loop");
			FileUtils.symlink (root, loop_link);
			int rc_loop = TestSupport.run_cli ({ "--check", root }, null, out out_text, out err_text);
			assert_cmpint (rc_loop, CompareOperator.EQ, 1);
			// In-place formatting through a file symlink preserves the symlink and formats target
			string link_file = Path.build_filename (root, "linked.vala");
			FileUtils.symlink (file_a, link_file);
			int rc_sym = TestSupport.run_cli ({ link_file }, null, out out_text, out err_text);
			assert_cmpint (rc_sym, CompareOperator.EQ, 0);
			assert_true (FileUtils.test (link_file, FileTest.IS_SYMLINK));
			string formatted_target = TestSupport.read_file_or_fail (file_a);
			TestSupport.assert_equal_with_diff ("class FromA {\n}\n", formatted_target, "symlink target formatted");
			// Nonexistent --input-dir must fail with exit code 1
			int rc_nodir = TestSupport.run_cli (
					{ "--check", "--input-dir=" + Path.build_filename (root, "does_not_exist") },
					null,
					out out_text,
					out err_text
			);
			assert_cmpint (rc_nodir, CompareOperator.EQ, 1);
			TestSupport.assert_contains (err_text, "does not exist or is not a directory", "nonexistent input-dir error");
			// Duplicate positional files are deduplicated (reported once, no parallel write race)
			int rc_dup = TestSupport.run_cli ({ "--check", file_b, file_b }, null, out out_text, out err_text);
			assert_cmpint (rc_dup, CompareOperator.EQ, 1);
			string[] dup_lines = out_text.strip ().split ("\n");
			assert_cmpint (dup_lines.length, CompareOperator.EQ, 1);
		} finally {
			TestSupport.remove_recursive (root);
			TestSupport.remove_recursive (out_dir);
		}
	}

	private static void test_version_and_stdin_output_file () {
		string out_text;
		string err_text;
		int rc_ver = TestSupport.run_cli ({ "--version" }, null, out out_text, out err_text);
		assert_cmpint (rc_ver, CompareOperator.EQ, 0);
		TestSupport.assert_contains (out_text, "valafmt " + Valafmt.VERSION, "version matches meson project version");
		string out_dir = TestSupport.make_temp_dir ();
		string out_path = Path.build_filename (out_dir, "from_stdin.vala");
		try {
			int rc = TestSupport.run_cli (
					{ "--stdin", "--output-file=" + out_path },
					"namespace StdinOut { class App {} }",
					out out_text,
					out err_text
			);
			assert_cmpint (rc, CompareOperator.EQ, 0);
			assert_true (FileUtils.test (out_path, FileTest.EXISTS));
			string content = TestSupport.read_file_or_fail (out_path);
			TestSupport.assert_contains (content, "class App", "stdin --output-file content");
		} finally {
			TestSupport.remove_recursive (out_dir);
		}
	}

	private static void test_input_dir_combined_with_positional_file () {
		string in_dir = TestSupport.make_temp_dir ();
		string extra_file = TestSupport.make_temp_vala_file ("class Extra {}");
		try {
			string dir_file = Path.build_filename (in_dir, "inside.vala");
			TestSupport.write_file_or_fail (dir_file, "class Inside {}");
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli (
					{ "--input-dir=" + in_dir, extra_file, "--check" },
					null,
					out out_text,
					out err_text
			);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, dir_file, "input-dir file checked");
			TestSupport.assert_contains (out_text, extra_file, "positional file checked");
		} finally {
			TestSupport.remove_recursive (in_dir);
			TestSupport.remove_recursive (extra_file);
		}
	}

	private static void test_parse_errors_do_not_overwrite_source () {
		string malformed = "namespace Broken { public class App { void run ( { } }";
		string f_path = TestSupport.make_temp_vala_file (malformed);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (err_text, "formatting aborted", "parse error stderr");
			string after = TestSupport.read_file_or_fail (f_path);
			TestSupport.assert_equal_with_diff (malformed, after, "parse error preserved source");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_statement_keyword_syntax_error_hint () {
		string out_text;
		string err_text;
		int rc = TestSupport.run_cli ({ "--stdin" }, "void run () { if + 1; }", out out_text, out err_text);
		assert_cmpint (rc, CompareOperator.EQ, 1);
		TestSupport.assert_contains (
				err_text,
				"statement keyword 'if' cannot be used as an identifier without '@' escaping (use '@if')",
				"statement keyword hint"
		);
	}

	public static int main (string[] args) {
		Test.init (ref args);
		Test.add_func ("/cli/stdin", test_stdin);
		Test.add_func ("/cli/stdout", test_stdout);
		Test.add_func ("/cli/check_mode", test_check_mode);
		Test.add_func ("/cli/output_file", test_output_file);
		Test.add_func ("/cli/input_dir_and_output_dir", test_input_dir_and_output_dir);
		Test.add_func ("/cli/incompatible_flags", test_incompatible_flags);
		Test.add_func ("/cli/help_and_stdin_filename", test_help_and_stdin_filename);
		Test.add_func ("/cli/output_dir_collision_and_symlinks", test_output_dir_collision_and_symlinks);
		Test.add_func ("/cli/version_and_stdin_output_file", test_version_and_stdin_output_file);
		Test.add_func ("/cli/input_dir_combined_with_positional_file", test_input_dir_combined_with_positional_file);
		Test.add_func ("/cli/parse_errors_do_not_overwrite_source", test_parse_errors_do_not_overwrite_source);
		Test.add_func ("/cli/statement_keyword_syntax_error_hint", test_statement_keyword_syntax_error_hint);
		return Test.run ();
	}
}
