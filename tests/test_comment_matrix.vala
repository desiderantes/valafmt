/* test_comment_matrix.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Comprehensive comment preservation & comment-spacing linter matrix test suite.
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
	private static void test_linter_unspaced_comment_detection () {
		string code = """namespace CommentMatrix {
	//unspaced comment line
	public class App {
	}
}
""";
		var diagnostics = TestSupport.lint_or_fail (code);
		assert_cmpint (diagnostics.length, CompareOperator.GT, 0);
		bool found = false;
		for (int i = 0; i < diagnostics.length; i++) {
			if (diagnostics.get (i).rule_id == "comment-spacing") {
				found = true;
				break;
			}
		}
		assert_true (found);
	}

	private static void test_linter_clean_comment_passing () {
		string code = """namespace CommentMatrix {
	// Properly spaced comment line
	public class App {
	}
}
""";
		var diagnostics = TestSupport.lint_or_fail (code);
		assert_cmpint (diagnostics.length, CompareOperator.EQ, 0);
	}

	private static void test_header_comment_preservation () {
		string code = """/*
 * Copyright 2026 ValaPoet Authors
 *
 * Licensed under the Apache License, Version 2.0.
 */

namespace ValaPoet {
	public class ClassName {
	}
}
""";
		string formatted = TestSupport.format_or_fail (code);
		assert_true (formatted.has_prefix ("/*"));
		TestSupport.assert_contains (formatted, "Copyright 2026 ValaPoet Authors");
		TestSupport.assert_not_contains (formatted, "public static void main");
		string pass2 = TestSupport.format_or_fail (formatted);
		TestSupport.assert_equal_with_diff (formatted, pass2, "header comment idempotency");
	}

	private static void test_nested_and_doc_comments () {
		string code = """/**
 * Valadoc block comment for class
 */
public class DocClass {
	public void process () {
		int x = 42;
	}
}
""";
		string formatted = TestSupport.format_or_fail (code);
		TestSupport.assert_contains (formatted, "/**");
		TestSupport.assert_contains (formatted, "Valadoc block comment for class");
		string[] parts = formatted.split ("Valadoc block comment");
		assert_cmpint (parts.length - 1, CompareOperator.EQ, 1);
		string pass2 = TestSupport.format_or_fail (formatted);
		TestSupport.assert_equal_with_diff (formatted, pass2, "doc comment idempotency");
	}

	private static void test_trailing_same_line_comments_across_constructs () {
		string code = """using GLib; // core
namespace TrailTest { // ns open
	public enum Mode { // enum open
		FAST = 1, // fast mode
		SAFE; // safe mode

		public string label () {
			return "x"; // label
		} // end label
	} // end enum

	public class App { // class open
		private int count = 0; // counter

		public void run (int x) { // method open
			var items = new int[] { // arr open
				1, // first
				2 // second
			}; // arr end
			if (x > 0) { // if open
				switch (x) { // switch open
					case 1: // case one
						break; // end case
					default: // fallback
						break; // end default
				} // end switch
			} // end if
		} // end run
	} // end class
} // end ns
""";
		string formatted = TestSupport.format_or_fail (code);
		string[] expected_snippets = {
			"using GLib; // core",
			"namespace TrailTest { // ns open",
			"\tpublic enum Mode { // enum open",
			"\t\tFAST = 1, // fast mode",
			"\t\tSAFE; // safe mode",
			"\t\t\treturn \"x\"; // label",
			"\t\t} // end label",
			"\t} // end enum",
			"\tpublic class App { // class open",
			"\t\tprivate int count = 0; // counter",
			"\t\tpublic void run (int x) { // method open",
			"\t\t\tvar items = new int[] { // arr open",
			"\t\t\t\t1, // first",
			"\t\t\t\t2 // second",
			"\t\t\t}; // arr end",
			"\t\t\tif (x > 0) { // if open",
			"\t\t\t\tswitch (x) { // switch open",
			"\t\t\t\t\tcase 1: // case one",
			"\t\t\t\t\t\tbreak; // end case",
			"\t\t\t\t\tdefault: // fallback",
			"\t\t\t\t\t\tbreak; // end default",
			"\t\t\t\t} // end switch",
			"\t\t\t} // end if",
			"\t\t} // end run",
			"\t} // end class",
			"} // end ns"
		};
		foreach (unowned string snippet in expected_snippets) {
			TestSupport.assert_contains (formatted, snippet, "trailing comment");
		}
		string pass2 = TestSupport.format_or_fail (formatted);
		TestSupport.assert_equal_with_diff (formatted, pass2, "trailing comment idempotency");
	}

	private static void test_comments_inside_parameters_calls_and_binary_chains () {
		string code = """public class ExprComments {
	public void compute ( // open params
		int first, // first param
		// separator comment
		int second // last param
	) {
		helper ( // open call
			first, // first arg
			// middle arg note
			second // last arg
		);
		if (first > 0 // positive first
			// second must also be positive
			&& second > 0 // positive second
		) {
			helper (first, second);
		}
	}
}
""";
		string formatted = TestSupport.format_or_fail (code);
		string[] markers = {
			"public void compute ( // open params",
			"int first, // first param",
			"// separator comment",
			"int second // last param",
			"helper ( // open call",
			"first, // first arg",
			"// middle arg note",
			"second // last arg",
			"if (first > 0 // positive first",
			"// second must also be positive",
			"&& second > 0 // positive second"
		};
		foreach (unowned string marker in markers) {
			TestSupport.assert_contains (formatted, marker, "in-expression comment");
		}
		string pass2 = TestSupport.format_or_fail (formatted);
		TestSupport.assert_equal_with_diff (formatted, pass2, "in-expression comment idempotency");
	}

	private static void test_control_flow_branch_comments () {
		string code = """void f (bool a, bool b) {
	if (a) {
		g ();
	} // end if
	// before else if
	else if (b) {
		h ();
	} // end else if
	// before else
	else {
		k ();
	}

	if (a) {
		g ();
	} else // check b
	if (b) {
		h ();
	}

	try {
		g ();
	} // end try
	// before catch
	catch (Error e) {
		h ();
	} // end catch
	// before finally
	finally {
		k ();
	}
}
""";
		string formatted = TestSupport.format_or_fail (code);
		string[] markers = {
			"\t} // end if\n\t// before else if\n\telse if (b) {",
			"\t} // end else if\n\t// before else\n\telse {",
			"\t} // check b\n\telse if (b) {",
			"\t} // end try\n\t// before catch\n\tcatch (Error e) {",
			"\t} // end catch\n\t// before finally\n\tfinally {"
		};
		foreach (unowned string marker in markers) {
			TestSupport.assert_contains (formatted, marker, "branch comment");
		}
		string pass2 = TestSupport.format_or_fail (formatted);
		TestSupport.assert_equal_with_diff (formatted, pass2, "branch comment idempotency");
	}

	private static void test_block_and_valadoc_internal_indentation_preserved () {
		string code = """/**
 * Example usage:
 * {{{
 *     var app = new App ();
 *     app.run ();
 * }}}
 */
public class DocIndent {
	/*
	  Diagram:
	    A --> B
	      B --> C
	 */
	public void run () {
	}
}
""";
		string formatted = TestSupport.format_or_fail (code);
		TestSupport.assert_contains (formatted, " *     var app = new App ();", "valadoc code block indentation");
		TestSupport.assert_contains (formatted, " *     app.run ();", "valadoc code block second line");
		TestSupport.assert_contains (
				formatted,
				"\tDiagram:\n\t  A --> B\n\t    B --> C\n",
				"block comment relative indentation"
		);
		string pass2 = TestSupport.format_or_fail (formatted);
		TestSupport.assert_equal_with_diff (formatted, pass2, "block/valadoc indentation idempotency");
		string braced_block_comment = "/*\n{\n\n}\n*/\nvoid run () {\n}\n";
		string formatted_bc = TestSupport.format_or_fail (braced_block_comment);
		TestSupport.assert_contains (formatted_bc, "{\n\n}\n", "blank line inside block comment preserved");
	}

	public static int main (string[] args) {
		Test.init (ref args);
		Test.add_func ("/comments/linter_unspaced_comment", test_linter_unspaced_comment_detection);
		Test.add_func ("/comments/linter_clean_comment", test_linter_clean_comment_passing);
		Test.add_func ("/comments/header_comment_preservation", test_header_comment_preservation);
		Test.add_func ("/comments/nested_and_doc_comments", test_nested_and_doc_comments);
		Test.add_func (
				"/comments/trailing_same_line_comments_across_constructs",
				test_trailing_same_line_comments_across_constructs
		);
		Test.add_func (
				"/comments/inside_parameters_calls_and_binary_chains",
				test_comments_inside_parameters_calls_and_binary_chains
		);
		Test.add_func ("/comments/control_flow_branch_comments", test_control_flow_branch_comments);
		Test.add_func (
				"/comments/block_and_valadoc_internal_indentation",
				test_block_and_valadoc_internal_indentation_preserved
		);
		return Test.run ();
	}
}
