/* linter.vala
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
using TreeSitter;
namespace Valafmt {
	public enum Severity {
		WARNING,
		ERROR
	}

	public class Diagnostic : GLib.Object {
		public string file { get; set; }
		public int line { get; set; }
		public int column { get; set; }
		public string rule_id { get; set; }
		public string message { get; set; }
		public Severity severity { get; set; }
		public Diagnostic (
				string file,
				int line,
				int column,
				string rule_id,
				string message,
				Severity severity = Severity.WARNING
		) {
			this.file = file;
			this.line = line;
			this.column = column;
			this.rule_id = rule_id;
			this.message = message;
			this.severity = severity;
		}

		public string to_string () {
			string sev_str = severity == Severity.ERROR ? "error" : "warning";
			if (line > 0 && column > 0) {
				return @"$file:$line:$column: $sev_str: [$rule_id] $message";
			} else if (line > 0) {
				return @"$file:$line: $sev_str: [$rule_id] $message";
			}
			return @"$file: $sev_str: [$rule_id] $message";
		}
	}

	internal class Linter : GLib.Object {
		private GenericArray<Diagnostic> diagnostics;
		private string file_name;
		private string source_code;
		public Linter (string file_name, string source_code) {
			this.file_name = file_name;
			this.source_code = source_code;
			this.diagnostics = new GenericArray<Diagnostic> ();
		}

		public GenericArray<Diagnostic> get_diagnostics () {
			return diagnostics;
		}

		public static bool is_pascal_case (string name) {
			if (name.length == 0) {
				return true;
			}
			unichar c = name.get_char (0);
			if (!c.isupper ()) {
				return false;
			}
			if (name.contains ("_")) {
				return false;
			}
			return true;
		}

		public static bool is_snake_case (string name) {
			if (name.length == 0) {
				return true;
			}
			string s = name;
			if (s.has_prefix ("_")) {
				s = s.substring (1);
			}
			if (s.length == 0) {
				return true;
			}
			for (int i = 0; i < s.length; i++) {
				unichar c = s.get_char (i);
				if (c.isupper ()) {
					return false;
				}
			}
			return true;
		}

		public static bool is_all_caps (string name) {
			if (name.length == 0) {
				return true;
			}
			for (int i = 0; i < name.length; i++) {
				unichar c = name.get_char (i);
				if (c.islower ()) {
					return false;
				}
			}
			return true;
		}

		private void add_diagnostic (TreeSitter.Node node, string rule_id, string message) {
			Point pt = node.start_point;
			int line = (int) pt.row + 1;
			int col = (int) pt.column + 1;
			diagnostics.add (new Diagnostic (file_name, line, col, rule_id, message));
		}

		private string extract_last_identifier (TreeSitter.Node node) {
			string k = CstHelpers.node_type (node);
			if (k == "identifier") {
				string raw = CstHelpers.node_text (node, source_code);
				return raw.has_prefix ("@") ? raw.substring (1) : raw;
			}
			uint32 count = node.child_count;
			for (int i = (int) count - 1; i >= 0; i--) {
				TreeSitter.Node child = node.child ((uint32) i);
				string ck = CstHelpers.node_type (child);
				if (ck == "identifier" || ck == "symbol") {
					string res = extract_last_identifier (child);
					if (res != "") {
						return res;
					}
				}
			}
			return "";
		}

		public void check_tree (TreeSitter.Node root) {
			walk_node (root, false);
		}

		private void check_keyword_identifier (TreeSitter.Node node) {
			string raw = CstHelpers.node_text (node, source_code);
			if (raw.length == 0 || raw.has_prefix ("@")) {
				return;
			}
			if (CstHelpers.is_vala_keyword (raw) && !CstHelpers.is_contextual_keyword (raw)) {
				add_diagnostic (
						node,
						"keyword-as-identifier",
						@"keyword '$raw' used as identifier without '@' escaping; use '@$raw'"
				);
			}
		}

		private void check_comment (TreeSitter.Node node, bool in_block) {
			string raw = CstHelpers.node_text (node, source_code);
			if (raw.has_prefix ("//") && raw.length > 2) {
				char c = raw[2];
				if (c != '/' && c != ' ') {
					add_diagnostic (node, "comment-spacing", "missing space after comment marker '//'");
				}
			} else if (in_block && raw.has_prefix ("/**") && raw != "/**/") {
				add_diagnostic (
						node,
						"no-valadoc-in-body",
						"Valadoc comment '/** ... */' inside statement block will not be exported; use standard '/* ... */' comment"
				);
			}
		}

		private void walk_node (TreeSitter.Node node, bool in_block) {
			string k = CstHelpers.node_type (node);
			if (k == "identifier") {
				check_keyword_identifier (node);
			} else if (k == "comment") {
				check_comment (node, in_block);
			} else if (k == "empty_statement") {
				add_diagnostic (node, "double-semicolon", "unnecessary double semicolon ';;'");
			} else if (k == "template_string" || k == "verbatim_template_string") {
				check_template_string (node);
			} else if (k == "namespace_declaration") {
				check_symbol_decl_name (node, "namespace", true);
			} else if (k == "class_declaration") {
				check_type_decl_name (node, "class");
			} else if (k == "struct_declaration") {
				check_type_decl_name (node, "struct");
			} else if (k == "interface_declaration") {
				check_type_decl_name (node, "interface");
			} else if (k == "enum_declaration") {
				check_symbol_decl_name (node, "enum", true);
			} else if (k == "errordomain_declaration") {
				check_symbol_decl_name (node, "error domain", true);
			} else if (k == "delegate_declaration") {
				check_symbol_decl_name (node, "delegate", true);
			} else if (k == "method_declaration") {
				check_symbol_decl_name (node, "method", false);
			} else if (k == "property_declaration") {
				check_symbol_decl_name (node, "property", false);
			} else if (k == "signal_declaration") {
				check_symbol_decl_name (node, "signal", false);
			} else if (k == "field_declaration") {
				check_identifier_decl_name (node, "field", false);
			} else if (k == "constant_declaration") {
				check_identifier_decl_name (node, "constant", true);
			} else if (k == "enum_value") {
				check_identifier_decl_name (node, "enum value", true);
			} else if (k == "errorcode") {
				check_identifier_decl_name (node, "error code", true);
			} else if (k == "parameter") {
				check_identifier_decl_name (node, "parameter", false);
			} else if (k == "local_declaration") {
				bool is_const = false;
				bool is_tuple = false;
				uint32 lcount = node.child_count;
				for (uint32 i = 0; i < lcount; i++) {
					string ck = CstHelpers.node_type (node.child (i));
					if (ck == "const") {
						is_const = true;
					} else if (ck == "var") {
						is_tuple = true;
					}
				}
				string label = is_const ? "local constant" : "local variable";
				bool after_eq = false;
				for (uint32 i = 0; i < lcount; i++) {
					TreeSitter.Node child = node.child (i);
					string ck = CstHelpers.node_type (child);
					if (ck == "=") {
						after_eq = true;
					} else if (ck == "assignment") {
						check_identifier_decl_name (child, label, is_const);
					} else if (is_tuple && !after_eq && ck == "identifier") {
						validate_identifier_name (child, node, label, is_const);
					}
				}
			}
			bool child_in_block = in_block || k == "block";
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				walk_node (node.child (i), child_in_block);
			}
		}

		private void check_template_string (TreeSitter.Node node) {
			int expr_count = 0;
			uint32 expr_start = 0;
			uint32 expr_end = 0;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				if (CstHelpers.node_type (child) == "template_string_expression") {
					expr_count++;
					expr_start = child.start_byte;
					expr_end = child.end_byte;
				}
			}
			if (expr_count == 1) {
				uint32 str_start = node.start_byte;
				uint32 str_end = node.end_byte;
				bool is_verbatim = CstHelpers.node_type (node) == "verbatim_template_string";
				uint32 prefix_len = is_verbatim ? 4 : 2;
				uint32 suffix_len = is_verbatim ? 3 : 1;
				if (expr_start == str_start + prefix_len && expr_end == str_end - suffix_len) {
					add_diagnostic (
							node,
							"unnecessary-string-template",
							"unnecessary template string interpolation for single expression"
					);
				}
			}
		}

		private void check_type_decl_name (TreeSitter.Node decl, string label) {
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				if (CstHelpers.node_type (child) == "unqualified_type") {
					string name = extract_last_identifier (child);
					if (name != "" && !is_pascal_case (name)) {
						add_diagnostic (decl, "naming-convention", @"$label name '$name' should use PascalCase");
					}
					break;
				}
			}
		}

		private void check_symbol_decl_name (TreeSitter.Node decl, string label, bool pascal) {
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				if (CstHelpers.node_type (child) == "symbol") {
					string name = extract_last_identifier (child);
					if (name != "") {
						if (pascal && !is_pascal_case (name)) {
							add_diagnostic (decl, "naming-convention", @"$label name '$name' should use PascalCase");
						} else if (!pascal && !is_snake_case (name)) {
							add_diagnostic (decl, "naming-convention", @"$label name '$name' should use snake_case");
						}
					}
					break;
				}
			}
		}

		private void validate_identifier_name (TreeSitter.Node node, TreeSitter.Node decl, string label, bool all_caps) {
			string name = extract_last_identifier (node);
			if (name != "") {
				if (all_caps && !is_all_caps (name)) {
					add_diagnostic (decl, "naming-convention", @"$label name '$name' should use ALL_CAPS_SNAKE");
				} else if (!all_caps && !is_snake_case (name)) {
					add_diagnostic (decl, "naming-convention", @"$label name '$name' should use snake_case");
				}
			}
		}

		private void check_identifier_decl_name (TreeSitter.Node decl, string label, bool all_caps) {
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ct = CstHelpers.node_type (child);
				if (ct == "assignment") {
					uint32 acount = child.child_count;
					for (uint32 j = 0; j < acount; j++) {
						TreeSitter.Node ac = child.child (j);
						if (CstHelpers.node_type (ac) == "identifier") {
							validate_identifier_name (ac, decl, label, all_caps);
							break;
						}
					}
				} else if (ct == "identifier") {
					validate_identifier_name (child, decl, label, all_caps);
					break;
				}
			}
		}
	}
}
