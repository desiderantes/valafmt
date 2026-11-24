/* test_regressions.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Unit/integration test suite for valafmt CST correctness and bug regressions.
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
	private static void test_generic_type_parameter_preservation () {
		string code = """
namespace Test {
	public abstract class Map<K, V> {
		public abstract V? get (K key);
		public abstract void put<T> (K key, V val, T metadata);
	}
	public interface Iterable<G> {
		public abstract Iterator<G> iterator ();
	}
	public struct Entry<K, V> {
		public K key;
		public V value;
	}
	public delegate void ProcessFunc<T> (T item);
}
""";
		string formatted = TestSupport.format_or_fail (code);
		TestSupport.assert_contains (formatted, "class Map<K, V>");
		TestSupport.assert_contains (formatted, "void put<T>");
		TestSupport.assert_contains (formatted, "interface Iterable<G>");
		TestSupport.assert_contains (formatted, "Iterator<G> iterator ()");
		TestSupport.assert_contains (formatted, "struct Entry<K, V>");
		TestSupport.assert_contains (formatted, "delegate void ProcessFunc<T>");
	}

	private static void test_class_modifiers_preservation () {
		string code = """
namespace Test {
	public abstract class AbstractWidget : Object {
	}
	public sealed class FinalNode {
	}
}
""";
		string formatted = TestSupport.format_or_fail (code);
		TestSupport.assert_contains (formatted, "public abstract class AbstractWidget");
		TestSupport.assert_contains (formatted, "public sealed class FinalNode");
	}

	private static void test_attribute_key_deterministic_sorting () {
		string code = """
namespace Test {
	public class Service {
		[CCode (array_null_terminated = true, array_length = false)]
		private static string[] sources;
	}
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "attribute sorting idempotency");
		TestSupport.assert_contains (formatted1, "array_length = false, array_null_terminated = true");
	}

	private static void test_trailing_lambda_layout () {
		string code = """void main () {
	button.connect (("clicked"), (s) => {
		do_work ();
	});
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "trailing lambda idempotency");
		TestSupport.assert_contains (formatted1, "});\n");
		TestSupport.assert_not_contains (formatted1, "}\n\t);");
	}

	private static void test_method_chain_wrapping () {
		string code = """void main () {
	items.filter ((item) => item.is_active ()).filter ((item) => item.has_permissions ()).map ((item) => item.get_display_name ()).collect_as_list ();
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "method chain wrapping idempotency");
		TestSupport.assert_contains (formatted1, "\n\t\t.filter (");
		TestSupport.assert_contains (formatted1, "\n\t\t.map (");
		TestSupport.assert_contains (formatted1, "\n\t\t.collect_as_list ();");
	}

	private static void test_binary_operator_wrapping () {
		string code = """void main () {
	if (very_long_condition_name_number_one () && very_long_condition_name_number_two () && very_long_condition_name_number_three ()) {
		print ("ok");
	}
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "binary operator wrapping idempotency");
		TestSupport.assert_contains (formatted1, "\n\t\t\t&& very_long_condition_name_number_two ()");
		TestSupport.assert_contains (formatted1, "\n\t\t\t&& very_long_condition_name_number_three ()");
	}

	private static void test_enum_comment_preservation () {
		string code = """public enum State {
	// idle state
	IDLE,
	// running state
	RUNNING
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "enum comments idempotency");
		TestSupport.assert_contains (formatted1, "// idle state");
		TestSupport.assert_contains (formatted1, "// running state");
	}

	private static void test_long_signature_prefix_parameter_wrapping () {
		string code = """namespace Test {
	public class Service {
		public async override GLib.HashTable<string, GLib.GenericArray<string>> build_extremely_long_method_signature_name (string first_arg, int second_arg) {
		}
	}
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "long signature wrapping idempotency");
		TestSupport.assert_contains (formatted1, "build_extremely_long_method_signature_name (\n");
		TestSupport.assert_contains (formatted1, "\t\t\t\tstring first_arg,\n");
		TestSupport.assert_contains (formatted1, "\t\t\t\tint second_arg\n");
	}

	private static void test_intentional_blank_lines_preserved_with_no_padded_blocks () {
		string code = """public class Grouping {
	private int a = 1;
	private int b = 2;

	private int c = 3;

	public void run () { // padded check below

		int x = 1;

		int y = 2;

		int z = 3;
	}
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "blank line preservation idempotency");
		string expected = """public class Grouping {
	private int a = 1;
	private int b = 2;

	private int c = 3;

	public void run () { // padded check below
		int x = 1;

		int y = 2;

		int z = 3;
	}
}
""";
		TestSupport.assert_equal_with_diff (expected, formatted1, "blank line preservation");
	}

	private static void test_object_initializer_and_chain_comments () {
		string code = """void main () {
	var widget = new Gtk.Box () { // box init
		orientation = Gtk.Orientation.VERTICAL, // vertical
		// spacing note
		spacing = 6 // six px
	};
	items.filter ( // filter open
		(item) => item.is_active () // active check
	).collect ();
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "object initializer/chain comment idempotency");
		string[] expected_snippets = {
			"new Gtk.Box () { // box init",
			"orientation = Gtk.Orientation.VERTICAL, // vertical",
			"// spacing note",
			"spacing = 6 // six px",
			".filter ( // filter open",
			"(item) => item.is_active () // active check"
		};
		foreach (unowned string snippet in expected_snippets) {
			TestSupport.assert_contains (formatted1, snippet);
		}
	}

	private static void test_contract_clauses_preserved () {
		string code = """public class Calc {
	public Calc (int seed) requires (seed > 0) {
	}

	public int divide (int a, int b) throws Error requires (b != 0) ensures (result >= 0) {
		return a / b;
	}

	public int divide_with_a_really_long_method_signature (int numerator_value, int denominator_value) throws GLib.Error requires (denominator_value != 0) ensures (result >= 0) {
		return numerator_value / denominator_value;
	}
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "contract clause idempotency");
		TestSupport.assert_contains (formatted1, "public Calc (int seed) requires (seed > 0) {");
		TestSupport.assert_contains (
				formatted1,
				"public int divide (int a, int b) throws Error requires (b != 0) ensures (result >= 0) {"
		);
		TestSupport.assert_contains (formatted1, "\n\t\t\trequires (denominator_value != 0) ensures (result >= 0) {");
	}

	private static void test_wrapped_multi_arg_trailing_lambda_indentation () {
		string code = """void f () {
	very_long_receiver.very_long_method_call_name ("first_argument", "second_argument", "third_argument", "fourth_argument", (s) => {
		do_work (s);
	});
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "wrapped lambda idempotency");
		string expected = """void f () {
	very_long_receiver.very_long_method_call_name (
			"first_argument",
			"second_argument",
			"third_argument",
			"fourth_argument",
			(s) => {
				do_work (s);
			});
}
""";
		TestSupport.assert_equal_with_diff (expected, formatted1, "wrapped lambda indentation");
	}

	private static void test_preserved_declarations_and_control_flow () {
		string code = """#if FOO && ! BAR
void demo () {
	const int MAX_X = 1;
	var (first_val, second_val) = get_pair ();
	int[, ] matrix = new int[, ];
	int signed_val = + 5;
	global::GLib.stdout.printf ("hi");
	var mapped = items.get<string,int> ("k");
	var chained = items.get_map<string,int> ().filter ((item) => item != null).collect ();
	with (var obj = get_obj ()) {
		obj.run ();
	}
	static int helper (int n) {
		return n + 1;
	}
	switch (signed_val) {
		case 1, 2:
			break;
		default:
			break;
	}
}
#endif
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "preserved declarations idempotency");
		string expected = """#if FOO && !BAR
void demo () {
	const int MAX_X = 1;
	var (first_val, second_val) = get_pair ();
	int[,] matrix = new int[,];
	int signed_val = +5;
	global::GLib.stdout.printf ("hi");
	var mapped = items.get<string, int> ("k");
	var chained = items.get_map<string, int> ().filter ((item) => item != null).collect ();
	with (var obj = get_obj ()) {
		obj.run ();
	}
	static int helper (int n) {
		return n + 1;
	}
	switch (signed_val) {
		case 1, 2:
			break;
		default:
			break;
	}
}

#endif
""";
		TestSupport.assert_equal_with_diff (expected, formatted1, "preserved declarations and control flow");
	}

	private static void test_interpolated_template_string_formatting () {
		string code = "void demo () {\n"
				+ "\tstring s1 = @\"hi $name $(a+b) $(foo(1,2))\";\n"
				+ "\tstring s2 = @\"\"\"hello $(a+b) $name\"\"\";\n"
				+ "\tstring s3 = @\"cost $$100 \\\"$(a+b)\\\" \\n $name $(a ? @\"$(x+1)\" : \"no\")\";\n"
				+ "}\n";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "template string interpolation idempotency");
		string expected = "void demo () {\n"
				+ "\tstring s1 = @\"hi $name $(a + b) $(foo (1, 2))\";\n"
				+ "\tstring s2 = @\"\"\"hello $(a + b) $name\"\"\";\n"
				+ "\tstring s3 = @\"cost $$100 \\\"$(a + b)\\\" \\n $name $(a ? @\"$(x + 1)\" : \"no\")\";\n"
				+ "}\n";
		TestSupport.assert_equal_with_diff (expected, formatted1, "template string interpolation formatting");
	}

	private static void test_parentheses_comma_inline_arrays_and_keyword_assignment () {
		string code = """void demo (int arr[1+2], int x = (1, 2)) requires ((x > 0)) {
	if = 1;
	unlock = 1;
	int @unlock = 0;
	unlock ((mutex));
	bool x5 = (a || b) && c;
	int r1 = (a + b) + c;
	int x8 = (a + b) + (c + d);
	int g = (1, 2) + 3;
	int b = (1, 2);
	(1, 2);
	if ((a + b)) {
		return (1, 2);
	}
	while ((a, b)) {
		break;
	}
	bool f = (1 + 2) is int;
	int y[2,3] = {};
	for ((i = 0); (i < 10); (i++, j++)) {
		a[(1, 2)] = 1;
	}
	switch ((x)) {
		case (1, 2), 3:
			break;
	}
	var fn = (x) => ((x + 1));
	var res = ((get_fn ())) (1);
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "parentheses and inline array idempotency");
		string expected = """void demo (int arr[1 + 2], int x = (1, 2)) requires ((x > 0)) {
	@if = 1;
	@unlock = 1;
	int @unlock = 0;
	unlock ((mutex));
	bool x5 = (a || b) && c;
	int r1 = (a + b) + c;
	int x8 = (a + b) + (c + d);
	int g = (1, 2) + 3;
	int b = (1, 2);
	(1, 2);
	if ((a + b)) {
		return (1, 2);
	}
	while ((a, b)) {
		break;
	}
	bool f = (1 + 2) is int;
	int y[2, 3] = {};
	for ((i = 0); (i < 10); (i++, j++)) {
		a[(1, 2)] = 1;
	}
	switch ((x)) {
		case (1, 2), 3:
			break;
	}
	var fn = (x) => ((x + 1));
	var res = ((get_fn ())) (1);
}
""";
		TestSupport.assert_equal_with_diff (
				expected,
				formatted1,
				"parentheses, comma expressions, inline arrays, and keyword assignment"
		);
	}

	private static void test_grammar_audit_edge_cases () {
		string code = """[Demo (val = (1 + 2))]
void demo (int[(1 + 2)] sized_param) {
	int[(1 + 2)] sized_type = {};
	int sized_decl[(1 + 2)] = {};
	var arr = new int[(1, 2)];
	string t1 = @"$((a + b))";
	string t2 = @"$((1, 2))";
	(a ?? b).first_long_step_name ().second_long_step_name ().third_long_step_name ().fourth_step_with_a_very_long_name_to_wrap ();
	make_obj () { prop = (1, 2) };
	if.foo ();
	unlock ();
	unlock++;
	if[0]++;
	lock (m).foo ();
	int not = 1;
	int is = 2;
	obj.not ();
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "grammar audit edge cases idempotency");
		string expected = """[Demo (val = (1 + 2))]
void demo (int[(1 + 2)] sized_param) {
	int[(1 + 2)] sized_type = {};
	int sized_decl[(1 + 2)] = {};
	var arr = new int[(1, 2)];
	string t1 = @"$((a + b))";
	string t2 = @"$((1, 2))";
	(a ?? b)
		.first_long_step_name ()
		.second_long_step_name ()
		.third_long_step_name ()
		.fourth_step_with_a_very_long_name_to_wrap ();
	make_obj () {
		prop = (1, 2)
	};
	@if.foo ();
	@unlock ();
	@unlock++;
	@if[0]++;
	@lock (m).foo ();
	int not = 1;
	int @is = 2;
	obj.not ();
}
""";
		TestSupport.assert_equal_with_diff (expected, formatted1, "grammar audit edge cases");
	}

	private static void test_verbatim_string_and_empty_file_preservation () {
		string verbatim = "void main () {\n\tstring s = \"\"\"line1   \n\n\nline2   \n{\n\n}\n\"\"\";\n\tstring t = @\"\"\"a  \n\n\n$(1 + 2)\n{\n\n}\n\"\"\";\n}\n";
		string formatted1 = TestSupport.format_or_fail (verbatim);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (verbatim, formatted1, "verbatim string preservation");
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "verbatim string idempotency");
		string empty_formatted = TestSupport.format_or_fail ("");
		TestSupport.assert_equal_with_diff ("", empty_formatted, "empty file stays empty");
		string ws_formatted = TestSupport.format_or_fail ("   \n\t\n");
		TestSupport.assert_equal_with_diff ("", ws_formatted, "whitespace-only file normalizes to empty");
	}

	private static void test_utf8_display_width_line_wrapping () {
		// 98 display chars (under 120), but > 120 UTF-8 bytes due to multi-byte accented characters.
		string code = "void demo () {\n\tcall_with_utf8 (\"áéíóúáéíóúáéíóúáéíóúáéíóúáéíóúáéíóúáéíóú\", \"áéíóúáéíóúáéíóú\");\n}\n";
		string formatted = TestSupport.format_or_fail (code);
		TestSupport.assert_equal_with_diff (code, formatted, "utf8 display width does not wrap prematurely");
	}

	private static void test_lambda_param_wrap_and_chain_in_binary () {
		// Lambda RHS alone is 113 chars (< 120), but with "\tvar handler = " (18 cols) it is 131 cols (> 120) and must wrap.
		string code = """void demo () {
	var handler = (very_long_first_parameter_name, very_long_second_parameter_name, very_long_third_parameter_name, fourth_param) => {
		run ();
	};
	if (is_ready ()
		&& service.first_long_step_name ().second_long_step_name ().third_long_step_name ().fourth_long_step_name_exceeding_limit ()) {
		run ();
	}
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "lambda param wrap and chain in binary idempotency");
		string expected = """void demo () {
	var handler = (
			very_long_first_parameter_name,
			very_long_second_parameter_name,
			very_long_third_parameter_name,
			fourth_param
	) => {
		run ();
	};
	if (is_ready ()
			&& service
				.first_long_step_name ()
				.second_long_step_name ()
				.third_long_step_name ()
				.fourth_long_step_name_exceeding_limit ()) {
		run ();
	}
}
""";
		TestSupport.assert_equal_with_diff (expected, formatted1, "lambda param wrap and chain in binary");
	}

	private static void test_property_accessor_attrs_and_method_only_errordomain () {
		string code = """namespace Gdk {
	public class Event {
		public EventAny any { [CCode (cname = "(GdkEventAny *)")] get; }
	}

	public errordomain DBusError {
		[CCode (error_pos = 0.8, sentinel = "")]
		public static void set_dbus_error (string name) throws DBusError;
	}

	public enum Mode {
		FAST,
		SAFE;

		[CCode (cname = "mode_to_str")]
		public string to_str ();
	}
}
""";
		string formatted1 = TestSupport.format_or_fail (code);
		string formatted2 = TestSupport.format_or_fail (formatted1);
		TestSupport.assert_equal_with_diff (code, formatted1, "property accessor attrs and method-only errordomain");
		TestSupport.assert_equal_with_diff (formatted1, formatted2, "property accessor attrs idempotency");
	}

	public static int main (string[] args) {
		Test.init (ref args);
		Test.add_func ("/regressions/generic_type_parameters", test_generic_type_parameter_preservation);
		Test.add_func ("/regressions/class_modifiers", test_class_modifiers_preservation);
		Test.add_func ("/regressions/attribute_key_sorting", test_attribute_key_deterministic_sorting);
		Test.add_func ("/regressions/trailing_lambda_layout", test_trailing_lambda_layout);
		Test.add_func ("/regressions/method_chain_wrapping", test_method_chain_wrapping);
		Test.add_func ("/regressions/binary_operator_wrapping", test_binary_operator_wrapping);
		Test.add_func ("/regressions/enum_comment_preservation", test_enum_comment_preservation);
		Test.add_func (
				"/regressions/long_signature_prefix_parameter_wrapping",
				test_long_signature_prefix_parameter_wrapping
		);
		Test.add_func (
				"/regressions/intentional_blank_lines_and_no_padded_blocks",
				test_intentional_blank_lines_preserved_with_no_padded_blocks
		);
		Test.add_func ("/regressions/object_initializer_and_chain_comments", test_object_initializer_and_chain_comments);
		Test.add_func ("/regressions/contract_clauses_preserved", test_contract_clauses_preserved);
		Test.add_func (
				"/regressions/wrapped_multi_arg_trailing_lambda_indentation",
				test_wrapped_multi_arg_trailing_lambda_indentation
		);
		Test.add_func (
				"/regressions/preserved_declarations_and_control_flow",
				test_preserved_declarations_and_control_flow
		);
		Test.add_func (
				"/regressions/interpolated_template_string_formatting",
				test_interpolated_template_string_formatting
		);
		Test.add_func (
				"/regressions/parentheses_comma_inline_arrays_and_keyword_assignment",
				test_parentheses_comma_inline_arrays_and_keyword_assignment
		);
		Test.add_func ("/regressions/grammar_audit_edge_cases", test_grammar_audit_edge_cases);
		Test.add_func (
				"/regressions/verbatim_string_and_empty_file_preservation",
				test_verbatim_string_and_empty_file_preservation
		);
		Test.add_func ("/regressions/utf8_display_width_line_wrapping", test_utf8_display_width_line_wrapping);
		Test.add_func ("/regressions/lambda_param_wrap_and_chain_in_binary", test_lambda_param_wrap_and_chain_in_binary);
		Test.add_func (
				"/regressions/property_accessor_attrs_and_method_only_errordomain",
				test_property_accessor_attrs_and_method_only_errordomain
		);
		return Test.run ();
	}
}
