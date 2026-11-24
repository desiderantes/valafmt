/* test_linter.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Integration tests for valafmt static analysis & naming convention linter (--lint / -l).
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
	private static void test_valid_code_passes_linter () {
		string valid_code = """
namespace Test {
	public class GoodApp : Object {
		public const int MAX_RETRIES = 5;
		private string _user_name;

		public void process_data (string item_name) {
			int total_count = 10;
		}
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (valid_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 0);
			assert_cmpstr (out_text.strip (), CompareOperator.EQ, "");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_bad_class_name_warning () {
		string bad_code = """
namespace Test {
	public class bad_class_name {
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "class name 'bad_class_name' should use PascalCase");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_bad_method_and_var_names () {
		string bad_code = """
namespace Test {
	public class GoodName {
		public void calculateTotal () {
			int itemCount = 5;
		}
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "method name 'calculateTotal' should use snake_case");
			TestSupport.assert_contains (out_text, "local variable name 'itemCount' should use snake_case");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_bad_constant_name () {
		string bad_code = """
namespace Test {
	public class App {
		public const int max_retries = 10;
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "constant name 'max_retries' should use ALL_CAPS_SNAKE");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_stdin_linter () {
		string out_text;
		string err_text;
		int rc = TestSupport.run_cli ({ "--stdin", "--lint" }, "class my_class {}", out out_text, out err_text);
		assert_cmpint (rc, CompareOperator.EQ, 1);
		TestSupport.assert_contains (out_text, "class name 'my_class' should use PascalCase");
	}

	private static void test_output_options_ignored_in_lint_mode () {
		string out_dir = TestSupport.make_temp_dir ();
		string out_target = Path.build_filename (out_dir, "ignored_output.vala");
		string f_path = TestSupport.make_temp_vala_file ("class GoodClass {}");
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli (
					{ "--lint", f_path, "--output-file=" + out_target },
					null,
					out out_text,
					out err_text
			);
			assert_cmpint (rc, CompareOperator.EQ, 0);
			TestSupport.assert_contains (err_text, "Warning: Output option '--output-file' is ignored in --lint mode.");
			assert_false (FileUtils.test (out_target, FileTest.EXISTS));
		} finally {
			TestSupport.remove_recursive (f_path);
			TestSupport.remove_recursive (out_dir);
		}
	}

	private static void test_no_valadoc_in_body_warning () {
		string bad_code = """
namespace Test {
	public class Demo {
		public void run () {
			/**
			 * This is an unexported valadoc inside a method body.
			 */
			int x = 1;
		}
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "no-valadoc-in-body");
			TestSupport.assert_contains (
					out_text,
					"Valadoc comment '/** ... */' inside statement block will not be exported"
			);
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_double_semicolon_warning () {
		string bad_code = """
namespace Test {
	public class Demo {
		public void run () {
			int x = 1;;
		}
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "double-semicolon");
			TestSupport.assert_contains (out_text, "unnecessary double semicolon ';;'");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_unnecessary_string_template_warning () {
		string bad_code = """
namespace Test {
	public class Demo {
		public void run () {
			string msg = @"$(name)";
		}
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "unnecessary-string-template");
			TestSupport.assert_contains (out_text, "unnecessary template string interpolation for single expression");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_comment_spacing_warning () {
		string bad_code = """
namespace Test {
	public class Demo {
		//Bad comment without space
		public void run () {
		}
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "comment-spacing");
			TestSupport.assert_contains (out_text, "missing space after comment marker '//'");
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_keyword_as_identifier_warning () {
		string bad_code = """
namespace Test {
	public class Demo {
		public void run () {
			int if = 1;
		}
	}
}
""";
		string f_path = TestSupport.make_temp_vala_file (bad_code);
		try {
			string out_text;
			string err_text;
			int rc = TestSupport.run_cli ({ "--lint", f_path }, null, out out_text, out err_text);
			assert_cmpint (rc, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "keyword-as-identifier");
			TestSupport.assert_contains (out_text, "keyword 'if' used as identifier without '@' escaping; use '@if'");
			int rc2 = TestSupport.run_cli (
					{ "--stdin", "--lint" },
					"void run () {\n\tif = 1;\n}\n",
					out out_text,
					out err_text
			);
			assert_cmpint (rc2, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "keyword-as-identifier");
			TestSupport.assert_contains (out_text, "keyword 'if' used as identifier without '@' escaping; use '@if'");
			int rc3 = TestSupport.run_cli (
					{ "--stdin", "--lint" },
					"void run () {\n\tunlock = 1;\n}\n",
					out out_text,
					out err_text
			);
			assert_cmpint (rc3, CompareOperator.EQ, 1);
			TestSupport.assert_contains (out_text, "keyword-as-identifier");
			TestSupport.assert_contains (
					out_text,
					"keyword 'unlock' used as identifier without '@' escaping; use '@unlock'"
			);
			int rc4 = TestSupport.run_cli (
					{ "--stdin", "--lint" },
					"void run (Mutex m) {\n\tint @unlock = 1;\n\t@unlock = 2;\n\tunlock (m);\n}\n",
					out out_text,
					out err_text
			);
			assert_cmpint (rc4, CompareOperator.EQ, 0);
		} finally {
			TestSupport.remove_recursive (f_path);
		}
	}

	private static void test_no_false_positives_on_urls_strings_and_for_loops () {
		string valid_code = """/* Header comment with URL: https://www.gnu.org/licenses/ */
namespace Test {
	// Line comment referencing https://example.com/docs
	public class UrlAndStringDemo : GLib.Object {
		public void run () {
			string a = "https://example.com";
			string b = "//not-a-comment";
			string c = "not;;double-semi";
			string d = "/** not-valadoc */";
			for (;;) {
				break;
			}
		}
	}
}
""";
		string out_text;
		string err_text;
		int rc = TestSupport.run_cli ({ "--stdin", "--lint" }, valid_code, out out_text, out err_text);
		assert_cmpint (rc, CompareOperator.EQ, 0);
		assert_cmpstr (out_text.strip (), CompareOperator.EQ, "");
	}

	private static void test_errordomain_and_errorcode_naming () {
		string valid_code = """
namespace Test {
	public errordomain CustomError {
		INVALID_ARGUMENT,
		FILE_NOT_FOUND
	}
}
""";
		string out_text;
		string err_text;
		int rc_valid = TestSupport.run_cli ({ "--stdin", "--lint" }, valid_code, out out_text, out err_text);
		assert_cmpint (rc_valid, CompareOperator.EQ, 0);
		string bad_code = """
namespace Test {
	public errordomain bad_error {
		InvalidArgument
	}
}
""";
		int rc_bad = TestSupport.run_cli ({ "--stdin", "--lint" }, bad_code, out out_text, out err_text);
		assert_cmpint (rc_bad, CompareOperator.EQ, 1);
		TestSupport.assert_contains (out_text, "error domain name 'bad_error' should use PascalCase");
		TestSupport.assert_contains (out_text, "error code name 'InvalidArgument' should use ALL_CAPS_SNAKE");
	}

	private static void test_local_const_tuple_and_verbatim_template () {
		string valid_code = "namespace Test {\n"
				+ "\tpublic class Demo {\n"
				+ "\t\tpublic void run () {\n"
				+ "\t\t\tconst int MAX_COUNT = 10;\n"
				+ "\t\t\tvar (first_val, second_val) = pair ();\n"
				+ "\t\t\tstring msg = @\"\"\"hello $first_val\"\"\";\n"
				+ "\t\t}\n"
				+ "\t}\n"
				+ "}\n";
		string out_text;
		string err_text;
		int rc_valid = TestSupport.run_cli ({ "--stdin", "--lint" }, valid_code, out out_text, out err_text);
		assert_cmpint (rc_valid, CompareOperator.EQ, 0);
		assert_cmpstr (out_text.strip (), CompareOperator.EQ, "");
		string bad_code = "namespace Test {\n"
				+ "\tpublic class Demo {\n"
				+ "\t\tpublic void run () {\n"
				+ "\t\t\tconst int max_count = 10;\n"
				+ "\t\t\tvar (badVar, ok_var) = pair ();\n"
				+ "\t\t\tstring msg = @\"\"\"$(ok_var)\"\"\";\n"
				+ "\t\t}\n"
				+ "\t}\n"
				+ "}\n";
		int rc_bad = TestSupport.run_cli ({ "--stdin", "--lint" }, bad_code, out out_text, out err_text);
		assert_cmpint (rc_bad, CompareOperator.EQ, 1);
		TestSupport.assert_contains (out_text, "local constant name 'max_count' should use ALL_CAPS_SNAKE");
		TestSupport.assert_contains (out_text, "local variable name 'badVar' should use snake_case");
		TestSupport.assert_contains (out_text, "unnecessary template string interpolation for single expression");
	}

	private static void test_namespace_naming_and_syntax_error_rejection () {
		string out_text;
		string err_text;
		int rc_ns = TestSupport.run_cli ({ "--stdin", "--lint" }, "namespace bad_ns {\n}\n", out out_text, out err_text);
		assert_cmpint (rc_ns, CompareOperator.EQ, 1);
		TestSupport.assert_contains (out_text, "namespace name 'bad_ns' should use PascalCase");
		int rc_syn = TestSupport.run_cli ({ "--stdin", "--lint" }, "void broken ( {\n", out out_text, out err_text);
		assert_cmpint (rc_syn, CompareOperator.EQ, 1);
		TestSupport.assert_contains (err_text, "syntax error");
		TestSupport.assert_contains (err_text, "linting aborted");
		TestSupport.assert_not_contains (err_text, "formatting aborted");
	}

	public static int main (string[] args) {
		Test.init (ref args);
		Test.add_func ("/linter/valid_code_passes", test_valid_code_passes_linter);
		Test.add_func ("/linter/bad_class_name", test_bad_class_name_warning);
		Test.add_func ("/linter/bad_method_and_var_names", test_bad_method_and_var_names);
		Test.add_func ("/linter/bad_constant_name", test_bad_constant_name);
		Test.add_func ("/linter/stdin_linter", test_stdin_linter);
		Test.add_func ("/linter/output_options_ignored", test_output_options_ignored_in_lint_mode);
		Test.add_func ("/linter/no_valadoc_in_body", test_no_valadoc_in_body_warning);
		Test.add_func ("/linter/double_semicolon", test_double_semicolon_warning);
		Test.add_func ("/linter/unnecessary_string_template", test_unnecessary_string_template_warning);
		Test.add_func ("/linter/comment_spacing", test_comment_spacing_warning);
		Test.add_func ("/linter/keyword_as_identifier", test_keyword_as_identifier_warning);
		Test.add_func (
				"/linter/no_false_positives_urls_strings_for",
				test_no_false_positives_on_urls_strings_and_for_loops
		);
		Test.add_func ("/linter/errordomain_and_errorcode_naming", test_errordomain_and_errorcode_naming);
		Test.add_func ("/linter/local_const_tuple_and_verbatim_template", test_local_const_tuple_and_verbatim_template);
		Test.add_func (
				"/linter/namespace_naming_and_syntax_error_rejection",
				test_namespace_naming_and_syntax_error_rejection
		);
		return Test.run ();
	}
}
