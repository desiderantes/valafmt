/* formatting_engine.vala
 *
 * Copyright 2026 Mario Daniel Ruiz Saavedra
 *
 * Core engine managing the CST parse -> print -> normalize -> convergence loop pipeline.
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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
using TreeSitter;
namespace Valafmt {
	public errordomain FormattingError {
		UNPARSEABLE_FILE,
		NON_CONVERGENT
	}

	public class Engine : GLib.Object {
		private Config config;
		private int max_convergence_passes = 10;
		public Engine (Config config) {
			this.config = config;
		}

		private static int count_semantic_leaves (TreeSitter.Node node) {
			uint32 count = node.child_count;
			if (count == 0) {
				if (!node.is_named) {
					return 0;
				}
				string k = CstHelpers.node_type (node);
				if (k == "comment" || k == "empty_statement") {
					return 0;
				}
				return 1;
			}
			int total = 0;
			for (uint32 i = 0; i < count; i++) {
				total += count_semantic_leaves (node.child (i));
			}
			return total;
		}

		private static TreeSitter.Parser create_parser () {
			var parser = new TreeSitter.Parser ();
			parser.set_language (TreeSitter.vala_language ());
			return parser;
		}

		private static void assert_no_dropped_leaves (string filename, int initial_leaves, int output_leaves) throws FormattingError {
			if (initial_leaves > 0 && output_leaves < initial_leaves) {
				throw new FormattingError.UNPARSEABLE_FILE (
						"CST formatter dropped semantic tokens in %s (%d -> %d); formatting aborted to protect file against code loss".printf (
								filename,
								initial_leaves,
								output_leaves
						)
				);
			}
		}

		public string format_single_pass (string source_code, string filename = "input.vala") throws GLib.Error {
			var parser = create_parser ();
			int initial_leaves = 0;
			string formatted = single_pass_format (parser, source_code, filename, out initial_leaves);
			if (initial_leaves > 0) {
				TreeSitter.Tree? verify_tree = parser.parse_string (formatted);
				if (verify_tree == null || verify_tree.root_node ().has_error) {
					throw new FormattingError.UNPARSEABLE_FILE (
							"CST formatter produced unparseable output in %s; formatting aborted to protect file".printf (
									filename
							)
					);
				}
				assert_no_dropped_leaves (filename, initial_leaves, count_semantic_leaves (verify_tree.root_node ()));
			}
			return formatted;
		}

		public string format (string source_code, string filename = "input.vala") throws GLib.Error {
			var parser = create_parser ();
			string current = source_code;
			bool converged = false;
			int initial_leaves = -1;
			int final_leaves = -1;
			// shortcut: re-parses and re-prints once more on changed files to guarantee fixed-point idempotency; add a fast-path if single-pass corpus throughput ever matters
			for (int pass = 0; pass <= max_convergence_passes; pass++) {
				int pass_leaves = 0;
				string next = single_pass_format (parser, current, filename, out pass_leaves);
				if (pass == 0) {
					initial_leaves = pass_leaves;
				}
				final_leaves = pass_leaves;
				if (next == current) {
					current = next;
					converged = true;
					break;
				}
				current = next;
			}
			if (!converged) {
				throw new FormattingError.NON_CONVERGENT (
						"Formatting did not converge within %d passes in %s; fixed point not reached".printf (
								max_convergence_passes + 1,
								filename
						)
				);
			}
			assert_no_dropped_leaves (filename, initial_leaves, final_leaves);
			return current;
		}

		public GenericArray<Diagnostic> lint (string source_code, string filename = "input.vala") throws GLib.Error {
			var parser = create_parser ();
			TreeSitter.Tree? tree = parser.parse_string (source_code);
			if (tree == null) {
				throw new FormattingError.UNPARSEABLE_FILE ("tree-sitter failed to parse source file");
			}
			TreeSitter.Node root = tree.root_node ();
			check_parse_errors (root, source_code, filename, "linting aborted");
			var linter = new Linter (filename, source_code);
			linter.check_tree (root);
			return linter.get_diagnostics ();
		}

		private static TreeSitter.Node? find_first_error (TreeSitter.Node node) {
			if (node.is_error || node.is_missing) {
				return node;
			}
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				if (child.has_error) {
					TreeSitter.Node? res = find_first_error (child);
					if (res != null) {
						return res;
					}
				}
			}
			return null;
		}

		private const string[] VALA_STATEMENT_KEYWORDS = {
			"if",
			"switch",
			"while",
			"do",
			"for",
			"foreach",
			"return",
			"yield",
			"throw",
			"try",
			"lock",
			"unlock",
			"delete",
			"with",
			"break",
			"continue"
		};
		private static string check_statement_keyword_hint (string snippet) {
			string trimmed = snippet.strip ();
			foreach (unowned string kw in VALA_STATEMENT_KEYWORDS) {
				if (trimmed == kw) {
					return "; statement keyword '%s' cannot be used as an identifier without '@' escaping (use '@%s')".printf (
							kw,
							kw
					);
				}
				if (trimmed.has_prefix (kw)) {
					long kw_len = kw.length;
					if (trimmed.length > kw_len) {
						char next_char = trimmed[(int) kw_len];
						if (!next_char.isalnum () && next_char != '_') {
							return "; statement keyword '%s' cannot be used as an identifier without '@' escaping (use '@%s')".printf (
									kw,
									kw
							);
						}
					}
				}
			}
			return "";
		}

		private static void check_parse_errors (
				TreeSitter.Node root,
				string source_code,
				string filename,
				string action
		) throws FormattingError {
			if (!root.has_error) {
				return;
			}
			TreeSitter.Node? err = find_first_error (root);
			if (err != null) {
				Point sp = err.start_point;
				string snippet = err.text (source_code);
				string hint = check_statement_keyword_hint (snippet);
				if (snippet.length > 30) {
					snippet = snippet.substring (0, 30) + "...";
				}
				throw new FormattingError.UNPARSEABLE_FILE (
						"tree-sitter reported syntax error in %s at %u:%u (near '%s'%s); %s".printf (
								filename,
								sp.row + 1,
								sp.column + 1,
								snippet,
								hint,
								action
						)
				);
			}
			throw new FormattingError.UNPARSEABLE_FILE (
					"tree-sitter reported syntax error(s) in %s; %s".printf (filename, action)
			);
		}

		private string single_pass_format (
				TreeSitter.Parser parser,
				string source_code,
				string filename,
				out int semantic_leaves
		) throws GLib.Error {
			semantic_leaves = 0;
			TreeSitter.Tree? tree = parser.parse_string (source_code);
			if (tree == null) {
				throw new FormattingError.UNPARSEABLE_FILE ("tree-sitter failed to parse source file");
			}
			TreeSitter.Node root = tree.root_node ();
			check_parse_errors (root, source_code, filename, "formatting aborted to protect the source file");
			semantic_leaves = count_semantic_leaves (root);
			var printer = new CstPrettyPrinter (config, source_code);
			printer.visit_source_file (root);
			return printer.finalize_document ();
		}
	}
}
