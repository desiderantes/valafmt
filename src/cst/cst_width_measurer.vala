/* cst_width_measurer.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Allocation-free UTF-8 display width and flat CST node width estimation.
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
	internal class CstWidthMeasurer : GLib.Object {
		public static int measure_utf8_display_width (string text, int start_offset = 0) {
			int width = 0;
			int idx = start_offset;
			unichar uc;
			while (text.get_next_char (ref idx, out uc)) {
				if (uc == '\t') {
					width += CstCommentFormatter.TAB_DISPLAY_WIDTH;
				} else {
					width++;
				}
			}
			return width;
		}

		/**
		 * Estimates single-line display width of a CST expression node without spawning a sub-printer.
		 * Returns -1 when the node contains newlines, comments, or complex constructs that require
		 * full pretty-printing to measure accurately.
		 */
		public static int flat_width (TreeSitter.Node node, string source) {
			string k = CstHelpers.node_type (node);
			if (k == "comment") {
				return -1;
			}
			if (k == "identifier") {
				return measure_utf8_display_width (CstHelpers.format_identifier (CstHelpers.node_text (node, source)));
			}
			if (k == "integer"
					|| k == "real"
					|| k == "boolean"
					|| k == "null"
					|| k == "character"
					|| k == "string"
					|| k == "this"
					|| k == "base") {
				string raw = CstHelpers.node_text (node, source);
				if (raw.contains ("\n")) {
					return -1;
				}
				return measure_utf8_display_width (raw);
			}
			if (k == "member_access_expression") {
				int w = 0;
				uint32 count = node.child_count;
				for (uint32 i = 0; i < count; i++) {
					TreeSitter.Node c = node.child (i);
					string ck = CstHelpers.node_type (c);
					if (ck == "comment" || ck == "type_arguments") {
						return -1;
					} else if (ck == "." || ck == "?." || ck == "->" || ck == "global::" || ck == "(" || ck == ")") {
						w += ck.length;
					} else if (ck == ",") {
						w += 2;
					} else if (ck == "identifier") {
						w += measure_utf8_display_width (CstHelpers.format_identifier (CstHelpers.node_text (c, source)));
					} else if (ck == "parameter_direction_modifier") {
						w += measure_utf8_display_width (CstHelpers.node_text (c, source).strip ());
					} else if (c.is_named) {
						int cw = flat_width (c, source);
						if (cw < 0) {
							return -1;
						}
						w += cw;
					}
				}
				return w;
			}
			if (k == "argument") {
				int w = 0;
				uint32 count = node.child_count;
				for (uint32 i = 0; i < count; i++) {
					TreeSitter.Node c = node.child (i);
					string ck = CstHelpers.node_type (c);
					if (ck == "comment") {
						return -1;
					} else if (ck == "parameter_direction_modifier" || ck == "out" || ck == "ref" || ck == "owned") {
						w += measure_utf8_display_width (CstHelpers.node_text (c, source).strip ()) + 1;
					} else if (ck == "(" || ck == ")") {
						w += 1;
					} else if (ck == ",") {
						w += 2;
					} else if (c.is_named) {
						int cw = flat_width (c, source);
						if (cw < 0) {
							return -1;
						}
						w += cw;
					}
				}
				return w;
			}
			if (k == "method_call_expression") {
				int w = 0;
				int arg_idx = 0;
				bool in_args = false;
				uint32 count = node.child_count;
				for (uint32 i = 0; i < count; i++) {
					TreeSitter.Node c = node.child (i);
					string ck = CstHelpers.node_type (c);
					if (ck == "comment" || ck == "object_initializers") {
						return -1;
					} else if (!in_args && ck == "(") {
						in_args = true;
						w += 2;
					} else if (in_args && ck == ")") {
						in_args = false;
						w += 1;
					} else if (in_args && ck == "argument") {
						int aw = flat_width (c, source);
						if (aw < 0) {
							return -1;
						}
						if (arg_idx > 0) {
							w += 2;
						}
						w += aw;
						arg_idx++;
					} else if (!in_args && (ck == "(" || ck == ")")) {
						w += 1;
					} else if (!in_args && ck == ",") {
						w += 2;
					} else if (!in_args && c.is_named) {
						int fw = flat_width (c, source);
						if (fw < 0) {
							return -1;
						}
						w += fw;
					}
				}
				return w;
			}
			if (k == "unary_expression"
					|| k == "arithmetic_negation_expression"
					|| k == "bitwise_negation_expression"
					|| k == "logical_negation_expression"
					|| k == "prefix_expression"
					|| k == "dereferencing_expression"
					|| k == "addressof_expression"
					|| k == "postfix_expression") {
				int w = 0;
				uint32 count = node.child_count;
				for (uint32 i = 0; i < count; i++) {
					TreeSitter.Node c = node.child (i);
					string ck = CstHelpers.node_type (c);
					if (ck == "comment") {
						return -1;
					} else if (ck == "not") {
						w += 4;
					} else if (!c.is_named) {
						w += ck == "," ? 2 : ck.length;
					} else {
						int cw = flat_width (c, source);
						if (cw < 0) {
							return -1;
						}
						w += cw;
					}
				}
				return w;
			}
			if (k == "binary_expression"
					|| k == "relational_expression"
					|| k == "in_expression"
					|| k == "assignment_expression") {
				int w = 0;
				uint32 count = node.child_count;
				for (uint32 i = 0; i < count; i++) {
					TreeSitter.Node c = node.child (i);
					string ck = CstHelpers.node_type (c);
					if (ck == "comment") {
						return -1;
					} else if (ck == "(" || ck == ")") {
						w += 1;
					} else if (ck == ",") {
						w += 2;
					} else if (!c.is_named) {
						w += ck.length + 2;
					} else {
						int cw = flat_width (c, source);
						if (cw < 0) {
							return -1;
						}
						w += cw;
					}
				}
				return w;
			}
			return -1;
		}
	}
}
