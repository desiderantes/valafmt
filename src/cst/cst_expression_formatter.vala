/* cst_expression_formatter.vala
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
	[Compact]
	internal class CstExpressionFormatter {
		public unowned CstLayoutContext ctx;
		public unowned CstPrettyPrinter printer;

		public CstExpressionFormatter (CstLayoutContext ctx, CstPrettyPrinter printer) {
			this.ctx = ctx;
			this.printer = printer;
		}

		private bool has_comment_descendant (TreeSitter.Node node) {
			if (ctx.kind (node) == "comment") {
				return true;
			}
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				if (has_comment_descendant (node.child (i))) {
					return true;
				}
			}
			return false;
		}

		public void visit_template_string (TreeSitter.Node node) {
			uint32 cursor = node.start_byte;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				if (ctx.kind (child) == "template_string_expression"
						&& child.child_count >= 3
						&& ctx.kind (child.child (0)) == "$("
						&& child.start_point.row == child.end_point.row
						&& !has_comment_descendant (child)) {
					var inner_tokens = new GenericArray<TreeSitter.Node?> ();
					uint32 tcount = child.child_count;
					for (uint32 j = 1; j + 1 < tcount; j++) {
						TreeSitter.Node tc = child.child (j);
						string tck = ctx.kind (tc);
						if (tck == "(" || tck == ")" || tck == "," || (tc.is_named && tck != "comment")) {
							inner_tokens.add (tc);
						}
					}
					if (inner_tokens.length > 0) {
						string formatted_inner = printer.format_expression_tokens_inline (inner_tokens);
						if (!formatted_inner.contains ("\n")) {
							if (child.start_byte > cursor) {
								ctx.write (ctx.source.substring ((long) cursor, (long) (child.start_byte - cursor)));
							}
							ctx.write ("$(" + formatted_inner + ")");
							cursor = child.end_byte;
						}
					}
				}
			}
			if (node.end_byte > cursor) {
				ctx.write (ctx.source.substring ((long) cursor, (long) (node.end_byte - cursor)));
			}
		}

		public void visit_expression_or_atom (TreeSitter.Node node) {
			string k = ctx.kind (node);
			if (k == "literal") {
				if (node.child_count == 1 && node.child (0).is_named) {
					visit_expression_or_atom (node.child (0));
				} else {
					ctx.write (ctx.text (node));
				}
				return;
			}
			if (k == "string"
					|| k == "verbatim_string"
					|| k == "integer"
					|| k == "real"
					|| k == "boolean"
					|| k == "character"
					|| k == "null"
					|| k == "regex"
					|| k == "this_access"
					|| k == "base_access"
					|| k == "value_access") {
				ctx.write (ctx.text (node));
				return;
			}
			if (k == "template_string" || k == "verbatim_template_string") {
				visit_template_string (node);
				return;
			}
			if (k == "identifier") {
				ctx.write (CstHelpers.format_identifier (ctx.text (node)));
				return;
			}
			if (k == "symbol") {
				ctx.write (printer.types.format_symbol (node));
				return;
			}
			if (k == "type") {
				ctx.write (printer.types.format_type (node));
				return;
			}
			if (k == "type_arguments") {
				ctx.write (printer.types.format_type_arguments (node));
				return;
			}
			if (k == "member_access_expression") {
				visit_member_access_expression (node);
				return;
			}
			if (k == "method_call_expression") {
				visit_method_call_expression (node);
				return;
			}
			if (k == "object_creation_expression") {
				visit_object_creation_expression (node);
				return;
			}
			if (k == "array_creation_expression") {
				visit_array_creation_expression (node);
				return;
			}
			if (k == "initializer") {
				visit_initializer (node);
				return;
			}
			if (k == "element_access_expression") {
				visit_element_access_expression (node);
				return;
			}
			if (k == "slice_expression") {
				visit_slice_expression (node);
				return;
			}
			if (k == "lambda_expression") {
				visit_lambda_expression (node);
				return;
			}
			if (k == "postfix_expression") {
				visit_postfix_expression (node);
				return;
			}
			if (k == "prefix_expression"
					|| k == "logical_negation_expression"
					|| k == "arithmetic_negation_expression"
					|| k == "unary_plus_expression"
					|| k == "bitwise_negation_expression"
					|| k == "dereferencing_expression"
					|| k == "addressof_expression") {
				visit_unary_expression (node);
				return;
			}
			if (k == "static_cast_expression") {
				visit_static_cast_expression (node);
				return;
			}
			if (k == "dynamic_cast_expression") {
				visit_dynamic_cast_expression (node);
				return;
			}
			if (k == "type_relational_expression") {
				visit_type_relational_expression (node);
				return;
			}
			if (k == "typeof_expression" || k == "sizeof_expression") {
				visit_typeof_or_sizeof_expression (node);
				return;
			}
			if (k == "yield_expression") {
				visit_yield_expression (node);
				return;
			}
			if (k == "in_expression") {
				visit_in_expression (node);
				return;
			}
			if (k == "ternary_expression") {
				visit_ternary_expression (node);
				return;
			}
			if (k == "multiplicative_expression"
					|| k == "arithmetic_expression"
					|| k == "bitshift_expression"
					|| k == "relational_expression"
					|| k == "equality_expression"
					|| k == "bitwise_and_expression"
					|| k == "bitwise_xor_expression"
					|| k == "bitwise_or_expression"
					|| k == "logical_and_expression"
					|| k == "logical_or_expression"
					|| k == "null_coalescing_expression"
					|| k == "assignment_expression") {
				visit_binary_or_assignment_expression (node);
				return;
			}
			if (k == "argument") {
				visit_argument (node);
				return;
			}
			// Fallback for parenthesized expression or any uncategorized node
			uint32 count = node.child_count;
			if (count == 3 && ctx.kind (node.child (0)) == "(" && ctx.kind (node.child (2)) == ")") {
				ctx.write ("(");
				visit_expression_or_atom (node.child (1));
				ctx.write (")");
				return;
			}
			ctx.write (ctx.text (node));
		}

		public void visit_member_access_expression (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "." || ck == "?." || ck == "->" || ck == "global::") {
					ctx.write (ck);
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (ck == "type_arguments") {
					ctx.write (printer.types.format_type_arguments (child));
				} else if (ck == "parameter_direction_modifier") {
					ctx.write (ctx.text (child).strip ());
				} else if (ck == "identifier") {
					ctx.write (CstHelpers.format_identifier (ctx.text (child)));
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		public void visit_argument (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "parameter_direction_modifier" || ck == "ref" || ck == "out") {
					ctx.write (ctx.text (child).strip () + " ");
				} else if (ck == ":") {
					ctx.write (": ");
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		private TreeSitter.Node? get_lambda_node_from_arg (TreeSitter.Node arg) {
			if (ctx.kind (arg) == "lambda_expression") {
				return arg;
			}
			uint32 count = arg.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = arg.child (i);
				if (ctx.kind (child) == "lambda_expression") {
					return child;
				}
			}
			return null;
		}

		private bool is_block_lambda_arg (TreeSitter.Node arg) {
			TreeSitter.Node? l = get_lambda_node_from_arg (arg);
			if (l == null) {
				return false;
			}
			uint32 count = l.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = l.child (i);
				if (ctx.kind (child) == "block") {
					return true;
				}
			}
			return false;
		}

		private class ChainedMethodCall {
			public string dot_op;
			public string method_name;
			public TreeSitter.Node? type_arguments;
			public GenericArray<TreeSitter.Node?> args;
			public int open_paren_row;
		}

		private void decompose_method_call (
				TreeSitter.Node call_node,
				GenericArray<TreeSitter.Node?> receiver_tokens,
				out string dot_op,
				out string method_name,
				out TreeSitter.Node? type_arguments,
				GenericArray<TreeSitter.Node?> call_args,
				out int open_paren_row
		) {
			dot_op = ".";
			method_name = "";
			type_arguments = null;
			open_paren_row = -1;
			uint32 count = call_node.child_count;
			for (uint32 i = 0; i < count; i++) {
				if (ctx.kind (call_node.child (i)) == "object_initializers") {
					return;
				}
			}
			bool in_args = false;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = call_node.child (i);
				string ck = ctx.kind (child);
				if (!in_args) {
					if (ck == "(" && i > 0) {
						in_args = true;
						open_paren_row = (int) child.end_point.row;
					} else if (ck == "type_arguments") {
						type_arguments = child;
					} else if (ck == "member_access_expression" || ck == "pointer_member_access_expression") {
						uint32 mcount = child.child_count;
						int dot_idx = -1;
						for (uint32 j = 0; j < mcount; j++) {
							string mck = ctx.kind (child.child (j));
							if (mck == "." || mck == "?." || mck == "->") {
								dot_op = mck;
								dot_idx = (int) j;
							}
						}
						for (uint32 j = 0; j < mcount; j++) {
							TreeSitter.Node mc = child.child (j);
							string mck = ctx.kind (mc);
							if (dot_idx >= 0 && (int) j < dot_idx) {
								if (mck == "(" || mck == ")" || mck == "," || (mc.is_named && mck != "comment")) {
									receiver_tokens.add (mc);
								}
							} else if (mck == "identifier") {
								method_name = CstHelpers.format_identifier (ctx.text (mc));
							} else if (mck == "type_arguments") {
								type_arguments = mc;
							}
						}
					}
				} else {
					if (ck == ")") {
						in_args = false;
					} else if (ck == "argument" || ck == "comment") {
						call_args.add (child);
					}
				}
			}
		}

		private bool collect_method_chain (
				TreeSitter.Node node,
				GenericArray<TreeSitter.Node?> base_receiver_tokens,
				GenericArray<ChainedMethodCall> chain_calls
		) {
			TreeSitter.Node current = node;
			while (true) {
				var rec_tokens = new GenericArray<TreeSitter.Node?> ();
				string dot_op = ".";
				string method_name = "";
				TreeSitter.Node? type_args = null;
				var args = new GenericArray<TreeSitter.Node?> ();
				int open_paren_row = -1;
				decompose_method_call (
						current,
						rec_tokens,
						out dot_op,
						out method_name,
						out type_args,
						args,
						out open_paren_row
				);
				if (method_name == "" || rec_tokens.length == 0) {
					break;
				}
				var seg = new ChainedMethodCall ();
				seg.dot_op = dot_op;
				seg.method_name = method_name;
				seg.type_arguments = type_args;
				seg.args = args;
				seg.open_paren_row = open_paren_row;
				chain_calls.add (seg);
				if (rec_tokens.length == 1 && ctx.kind (rec_tokens.get (0)) == "method_call_expression") {
					current = rec_tokens.get (0);
				} else {
					for (int k = 0; k < rec_tokens.length; k++) {
						base_receiver_tokens.add (rec_tokens.get (k));
					}
					break;
				}
			}
			return chain_calls.length >= 2 && base_receiver_tokens.length > 0;
		}

		private bool is_inner_chain_call (TreeSitter.Node node) {
			TreeSitter.Node? p = node.parent;
			if (p != null) {
				string pk = ctx.kind (p);
				if (pk == "member_access_expression" || pk == "pointer_member_access_expression") {
					TreeSitter.Node? pp = p.parent;
					if (pp != null && ctx.kind (pp) == "method_call_expression") {
						if (p.child_count > 0) {
							TreeSitter.Node c0 = p.child (0);
							if (c0.start_byte == node.start_byte && c0.end_byte == node.end_byte) {
								return true;
							}
						}
					}
				}
			}
			return false;
		}

		public string format_call_arguments (
				GenericArray<TreeSitter.Node?> items,
				int current_col,
				int open_paren_row = -1
		) {
			if (items.length == 0) {
				return "";
			}
			int arg_count = 0;
			bool has_comments = false;
			TreeSitter.Node? last_arg = null;
			for (int i = 0; i < items.length; i++) {
				TreeSitter.Node item = items.get (i);
				if (ctx.kind (item) == "comment") {
					has_comments = true;
				} else {
					arg_count++;
					last_arg = item;
				}
			}
			bool has_trailing_lambda = last_arg != null && is_block_lambda_arg (last_arg);
			if (!has_comments) {
				var inline_sb = new StringBuilder ();
				for (int i = 0; i < items.length; i++) {
					if (i > 0) {
						inline_sb.append (", ");
					}
					string rendered = printer.print_node_inline (items.get (i));
					if (i == items.length - 1 && is_block_lambda_arg (items.get (i))) {
						string[] rlines = rendered.split ("\n");
						inline_sb.append (rlines[0]);
					} else {
						inline_sb.append (rendered);
					}
				}
				string inline_str = inline_sb.str;
				if (current_col + CstLayoutContext.measure_utf8_display_width (inline_str) <= ctx.config.line_length
						|| items.length == 1 && has_trailing_lambda) {
					var final_inline = new StringBuilder ();
					for (int i = 0; i < items.length; i++) {
						if (i > 0) {
							final_inline.append (", ");
						}
						final_inline.append (printer.print_node_inline (items.get (i)));
					}
					return final_inline.str;
				}
				var wrap_sb = new StringBuilder ("\n");
				int arg_indent = ctx.indent_level + 2;
				for (int i = 0; i < items.length; i++) {
					wrap_sb.append (ctx.config.get_indent_string (arg_indent));
					wrap_sb.append (printer.print_node_inline (items.get (i), arg_indent));
					if (i < items.length - 1) {
						wrap_sb.append (",\n");
					}
				}
				if (!has_trailing_lambda) {
					wrap_sb.append ("\n");
					wrap_sb.append (ctx.config.get_indent_string (ctx.indent_level));
				}
				return wrap_sb.str;
			}
			return ctx.format_wrapped_list_with_comments (
					items,
					arg_count,
					open_paren_row,
					!has_trailing_lambda,
					(item, item_indent) => printer.print_node_inline (item, item_indent)
			);
		}

		public void visit_method_call_expression (TreeSitter.Node node) {
			if (!is_inner_chain_call (node)) {
				var base_rec_tokens = new GenericArray<TreeSitter.Node?> ();
				var chain_calls = new GenericArray<ChainedMethodCall> ();
				if (collect_method_chain (node, base_rec_tokens, chain_calls)) {
					var in_order_calls = new GenericArray<ChainedMethodCall> ();
					for (int i = chain_calls.length - 1; i >= 0; i--) {
						in_order_calls.add (chain_calls.get (i));
					}
					bool is_multiline = node.end_point.row > base_rec_tokens.get (0).start_point.row;
					var inline_test = new StringBuilder ();
					inline_test.append (printer.format_expression_tokens_inline (base_rec_tokens));
					for (int i = 0; i < in_order_calls.length; i++) {
						var c = in_order_calls.get (i);
						inline_test.append (c.dot_op + c.method_name);
						if (c.type_arguments != null) {
							inline_test.append (printer.types.format_type_arguments (c.type_arguments));
						}
						inline_test.append (" (");
						inline_test.append (format_call_arguments (c.args, 0, c.open_paren_row));
						inline_test.append (")");
					}
					bool exceeds_limit = inline_test.str.contains ("\n")
							|| ctx.get_current_line_width ()
									+ CstLayoutContext.measure_utf8_display_width (inline_test.str) > ctx.config.line_length;
					if (is_multiline || exceeds_limit) {
						printer.emit_expression_tokens (base_rec_tokens);
						ctx.indent_level++;
						for (int i = 0; i < in_order_calls.length; i++) {
							var c = in_order_calls.get (i);
							ctx.write ("\n");
							ctx.write_indent ();
							ctx.write (c.dot_op + c.method_name);
							if (c.type_arguments != null) {
								ctx.write (printer.types.format_type_arguments (c.type_arguments));
							}
							ctx.write (" (");
							ctx.write (format_call_arguments (c.args, ctx.get_current_line_width (), c.open_paren_row));
							ctx.write (")");
						}
						ctx.indent_level--;
						return;
					}
				}
			}
			var args = new GenericArray<TreeSitter.Node?> ();
			TreeSitter.Node? obj_inits = null;
			int open_paren_row = -1;
			uint32 count = node.child_count;
			int scan_end = (int) count - 1;
			for (int i = (int) count - 1; i >= 0; i--) {
				if (ctx.kind (node.child ((uint32) i)) == "object_initializers") {
					obj_inits = node.child ((uint32) i);
					scan_end = i - 1;
					break;
				}
			}
			int call_open_idx = -1;
			int call_close_idx = -1;
			int depth = 0;
			for (int i = scan_end; i >= 0; i--) {
				string ck = ctx.kind (node.child ((uint32) i));
				if (ck == ")") {
					if (call_close_idx < 0) {
						call_close_idx = i;
					}
					depth++;
				} else if (ck == "(") {
					depth--;
					if (call_close_idx >= 0 && depth == 0) {
						call_open_idx = i;
						open_paren_row = (int) node.child ((uint32) i).end_point.row;
						break;
					}
				}
			}
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "object_initializers") {
					continue;
				}
				if (call_open_idx >= 0 && (int) i < call_open_idx) {
					if (ck == "(" || ck == ")") {
						ctx.write (ck);
					} else if (ck == ",") {
						ctx.write (", ");
					} else if (ck == "type_arguments") {
						ctx.write (printer.types.format_type_arguments (child));
					} else if (child.is_named && ck != "comment") {
						visit_expression_or_atom (child);
					}
				} else if (call_open_idx >= 0 && (int) i > call_open_idx && (int) i < call_close_idx) {
					if (ck == "argument" || ck == "comment") {
						args.add (child);
					}
				} else if (call_open_idx < 0) {
					if (ck == "type_arguments") {
						ctx.write (printer.types.format_type_arguments (child));
					} else if (child.is_named && ck != "comment") {
						visit_expression_or_atom (child);
					}
				}
			}
			ctx.write (" (");
			ctx.write (format_call_arguments (args, ctx.get_current_line_width (), open_paren_row));
			ctx.write (")");
			if (obj_inits != null) {
				emit_object_initializers (obj_inits);
			}
		}

		private void emit_object_initializers (TreeSitter.Node obj_inits) {
			var init_items = new GenericArray<TreeSitter.Node?> ();
			int member_count = 0;
			int open_brace_row = -1;
			uint32 icount = obj_inits.child_count;
			for (uint32 j = 0; j < icount; j++) {
				TreeSitter.Node ic = obj_inits.child (j);
				string ick = ctx.kind (ic);
				if (ick == "{") {
					open_brace_row = (int) ic.end_point.row;
				} else if (ick == "member_initializer") {
					init_items.add (ic);
					member_count++;
				} else if (ick == "comment") {
					init_items.add (ic);
				}
			}
			if (init_items.length == 0) {
				ctx.write (" {}");
			} else {
				ctx.write (" {\n");
				ctx.indent_level++;
				bool has_emitted = false;
				int last_end_row = -1;
				int seen_members = 0;
				for (int m = 0; m < init_items.length; m++) {
					TreeSitter.Node mi = init_items.get (m);
					if (ctx.kind (mi) == "comment") {
						ctx.emit_container_comment (mi, open_brace_row, ref has_emitted, ref last_end_row);
						continue;
					}
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, mi);
					string mname = "";
					var mval_tokens = new GenericArray<TreeSitter.Node?> ();
					bool after_eq = false;
					uint32 mcount = mi.child_count;
					for (uint32 k = 0; k < mcount; k++) {
						TreeSitter.Node mc = mi.child (k);
						string mck = ctx.kind (mc);
						if (mck == "identifier" && mname == "") {
							mname = CstHelpers.format_identifier (ctx.text (mc));
						} else if (mck == "=") {
							after_eq = true;
						} else if (after_eq && (mck == "(" || mck == ")" || mck == "," || (mc.is_named
								&& mck != "comment"))) {
							mval_tokens.add (mc);
						}
					}
					ctx.write_indent ();
					ctx.write (mname + " = ");
					if (mval_tokens.length > 0) {
						printer.emit_expression_tokens (mval_tokens);
					}
					seen_members++;
					if (seen_members < member_count) {
						ctx.write (",");
					}
					ctx.write ("\n");
					has_emitted = true;
					last_end_row = (int) mi.end_point.row;
				}
				ctx.indent_level--;
				ctx.trim_trailing_blank_lines ();
				ctx.write_indent ();
				ctx.write ("}");
			}
		}

		public void visit_object_creation_expression (TreeSitter.Node node) {
			string type_str = "";
			string ctor_suffix = "";
			var args = new GenericArray<TreeSitter.Node?> ();
			TreeSitter.Node? obj_inits = null;
			bool in_args = false;
			bool after_args = false;
			bool after_dot = false;
			int open_paren_row = -1;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "type" && type_str == "") {
					type_str = printer.types.format_type (child);
				} else if (ck == "." && !in_args) {
					after_dot = true;
				} else if (ck == "identifier" && after_dot && !in_args) {
					ctor_suffix = "." + CstHelpers.format_identifier (ctx.text (child));
					after_dot = false;
				} else if (ck == "(" && !in_args && !after_args) {
					in_args = true;
					open_paren_row = (int) child.end_point.row;
				} else if (ck == ")" && in_args) {
					in_args = false;
					after_args = true;
				} else if ((ck == "argument" || ck == "comment") && in_args) {
					args.add (child);
				} else if (ck == "object_initializers") {
					obj_inits = child;
				}
			}
			ctx.write ("new ");
			ctx.write (type_str + ctor_suffix);
			ctx.write (" (");
			ctx.write (format_call_arguments (args, ctx.get_current_line_width (), open_paren_row));
			ctx.write (")");
			if (obj_inits != null) {
				emit_object_initializers (obj_inits);
			}
		}

		public string format_inline_array_type (TreeSitter.Node inline_arr) {
			var sb = new StringBuilder ();
			uint32 acount = inline_arr.child_count;
			for (uint32 j = 0; j < acount; j++) {
				TreeSitter.Node ac = inline_arr.child (j);
				string ack = ctx.kind (ac);
				if (ack == "[" || ack == "]" || ack == ":" || ack == "," || ack == "(" || ack == ")") {
					sb.append (ack);
					if (ack == "," && j + 1 < acount) {
						string next_k = ctx.kind (inline_arr.child (j + 1));
						if (next_k != "]" && next_k != ",") {
							sb.append (" ");
						}
					}
				} else if (ack == "type") {
					sb.append (printer.types.format_type (ac));
				} else if (ac.is_named && ack != "comment") {
					sb.append (printer.print_node_inline (ac));
				}
			}
			return sb.str;
		}

		public void visit_array_creation_expression (TreeSitter.Node node) {
			string type_str = "";
			TreeSitter.Node? inline_arr = null;
			TreeSitter.Node? init_node = null;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "type" && type_str == "") {
					type_str = printer.types.format_type (child);
				} else if (ck == "inline_array_type") {
					inline_arr = child;
				} else if (ck == "initializer") {
					init_node = child;
				}
			}
			ctx.write ("new ");
			ctx.write (type_str);
			if (inline_arr != null) {
				ctx.write (format_inline_array_type (inline_arr));
			} else {
				ctx.write ("[]");
			}
			if (init_node != null) {
				ctx.write (" ");
				visit_initializer (init_node);
			}
		}

		public void visit_initializer (TreeSitter.Node node) {
			var items = new GenericArray<TreeSitter.Node?> ();
			int arg_count = 0;
			bool has_comments = false;
			int open_brace_row = -1;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "{") {
					open_brace_row = (int) child.end_point.row;
				} else if (ck == "argument") {
					items.add (child);
					arg_count++;
				} else if (ck == "comment") {
					items.add (child);
					has_comments = true;
				}
			}
			if (items.length == 0) {
				ctx.write ("{}");
				return;
			}
			// Check if the initializer was authored multi-line or contains nested initializers/argument blocks
			bool is_multiline = has_comments || node.end_point.row > node.start_point.row;
			bool has_nested_initializer = false;
			for (int i = 0; i < items.length; i++) {
				TreeSitter.Node arg = items.get (i);
				if (ctx.kind (arg) == "comment") {
					continue;
				}
				uint32 acount = arg.child_count;
				for (uint32 j = 0; j < acount; j++) {
					if (ctx.kind (arg.child (j)) == "initializer") {
						has_nested_initializer = true;
						break;
					}
				}
				if (has_nested_initializer) {
					break;
				}
			}
			// Format inline if single-line and not a complex multi-entry nested initializer table
			if (!is_multiline && !has_nested_initializer) {
				ctx.write ("{ ");
				for (int i = 0; i < items.length; i++) {
					if (i > 0) {
						ctx.write (", ");
					}
					visit_argument (items.get (i));
				}
				ctx.write (" }");
				return;
			}
			// Multi-line layout for tables, matrices, and large initializers
			ctx.write ("{\n");
			ctx.indent_level++;
			bool has_emitted = false;
			int last_end_row = -1;
			int seen_args = 0;
			for (int i = 0; i < items.length; i++) {
				TreeSitter.Node item = items.get (i);
				if (ctx.kind (item) == "comment") {
					ctx.emit_container_comment (item, open_brace_row, ref has_emitted, ref last_end_row);
					continue;
				}
				ctx.maybe_emit_blank_line (has_emitted, last_end_row, item);
				ctx.write_indent ();
				visit_argument (item);
				seen_args++;
				if (seen_args < arg_count) {
					ctx.write (",\n");
				} else {
					ctx.write ("\n");
				}
				has_emitted = true;
				last_end_row = (int) item.end_point.row;
			}
			ctx.indent_level--;
			ctx.trim_trailing_blank_lines ();
			ctx.write_indent ();
			ctx.write ("}");
		}

		public void visit_element_access_expression (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "element_access") {
					var idx_tokens = new GenericArray<TreeSitter.Node?> ();
					bool has_null_safe = false;
					uint32 ecount = child.child_count;
					for (uint32 j = 0; j < ecount; j++) {
						TreeSitter.Node ec = child.child (j);
						string eck = ctx.kind (ec);
						if (eck == "?") {
							has_null_safe = true;
						} else if (eck == "(" || eck == ")" || eck == "," || (ec.is_named && eck != "comment")) {
							idx_tokens.add (ec);
						}
					}
					if (has_null_safe) {
						ctx.write ("?");
					}
					ctx.write ("[");
					printer.emit_expression_tokens (idx_tokens);
					ctx.write ("]");
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		public void visit_slice_expression (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == ":") {
					ctx.write (":");
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		public void visit_lambda_expression (TreeSitter.Node node) {
			var @params = new GenericArray<string> ();
			var body_tokens = new GenericArray<TreeSitter.Node?> ();
			bool after_arrow = false;
			string current_dir = "";
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "=>") {
					after_arrow = true;
				} else if (!after_arrow && (ck == "parameter_direction_modifier" || ck == "out" || ck == "ref")) {
					current_dir = ctx.text (child).strip () + " ";
				} else if (!after_arrow && ck == "identifier") {
					@params.add (current_dir + CstHelpers.format_identifier (ctx.text (child)));
					current_dir = "";
				} else if (after_arrow && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					body_tokens.add (child);
				}
			}
			var inline_params = new StringBuilder ("(");
			for (int i = 0; i < @params.length; i++) {
				if (i > 0) {
					inline_params.append (", ");
				}
				inline_params.append (@params.get (i));
			}
			inline_params.append (") =>");
			if (@params.length >= 2
					&& ctx.get_current_line_width () + CstLayoutContext.measure_utf8_display_width (inline_params.str) > ctx.config.line_length) {
				ctx.write ("(\n");
				int param_indent = ctx.indent_level + 2;
				for (int i = 0; i < @params.length; i++) {
					ctx.write (ctx.config.get_indent_string (param_indent));
					ctx.write (@params.get (i));
					if (i < @params.length - 1) {
						ctx.write (",\n");
					} else {
						ctx.write ("\n");
					}
				}
				ctx.write_indent ();
				ctx.write (") =>");
			} else {
				ctx.write (inline_params.str);
			}
			if (body_tokens.length == 1 && ctx.kind (body_tokens.get (0)) == "block") {
				printer.stmts.visit_block (body_tokens.get (0));
			} else if (body_tokens.length > 0) {
				ctx.write (" ");
				printer.emit_expression_tokens (body_tokens);
			}
		}

		public void visit_postfix_expression (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "++" || ck == "--") {
					ctx.write (ck);
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		public void visit_unary_expression (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "!"
						|| ck == "~"
						|| ck == "-"
						|| ck == "+"
						|| ck == "*"
						|| ck == "&"
						|| ck == "++"
						|| ck == "--") {
					ctx.write (ck);
				} else if (ck == "not") {
					ctx.write ("not ");
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		public void visit_static_cast_expression (TreeSitter.Node node) {
			string cast_target = "";
			bool after_rparen = false;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (!after_rparen) {
					if (ck == ")") {
						after_rparen = true;
						ctx.write ("(" + cast_target + ") ");
					} else if (ck == "type") {
						cast_target = printer.types.format_type (child);
					} else if (ck == "owned" || ck == "!") {
						cast_target = ck;
					}
				} else {
					if (ck == "(" || ck == ")") {
						ctx.write (ck);
					} else if (ck == ",") {
						ctx.write (", ");
					} else if (child.is_named && ck != "comment") {
						visit_expression_or_atom (child);
					}
				}
			}
		}

		public void visit_dynamic_cast_expression (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "as") {
					ctx.write (" as ");
				} else if (ck == "type") {
					ctx.write (printer.types.format_type (child));
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		public void visit_type_relational_expression (TreeSitter.Node node) {
			bool has_not = false;
			var lhs_tokens = new GenericArray<TreeSitter.Node?> ();
			TreeSitter.Node? rhs_type = null;
			bool after_is = false;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (!after_is) {
					if (ck == "is") {
						after_is = true;
					} else if (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment")) {
						lhs_tokens.add (child);
					}
				} else {
					if (ck == "not") {
						has_not = true;
					} else if (ck == "type") {
						rhs_type = child;
					}
				}
			}
			printer.emit_expression_tokens (lhs_tokens);
			ctx.write (has_not ? " is not " : " is ");
			if (rhs_type != null) {
				ctx.write (printer.types.format_type (rhs_type));
			}
		}

		public void visit_typeof_or_sizeof_expression (TreeSitter.Node node) {
			string kw = ctx.kind (node) == "typeof_expression" ? "typeof" : "sizeof";
			string t_str = "";
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				if (ctx.kind (child) == "type") {
					t_str = printer.types.format_type (child);
				}
			}
			ctx.write (kw + " (" + t_str + ")");
		}

		public void visit_yield_expression (TreeSitter.Node node) {
			ctx.write ("yield ");
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		public void visit_in_expression (TreeSitter.Node node) {
			bool has_not = false;
			var lhs_tokens = new GenericArray<TreeSitter.Node?> ();
			var rhs_tokens = new GenericArray<TreeSitter.Node?> ();
			bool after_in = false;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (!after_in && ck == "not") {
					has_not = true;
				} else if (!after_in && ck == "in") {
					after_in = true;
				} else if (!after_in && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					lhs_tokens.add (child);
				} else if (after_in && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					rhs_tokens.add (child);
				}
			}
			printer.emit_expression_tokens (lhs_tokens);
			ctx.write (has_not ? " not in " : " in ");
			printer.emit_expression_tokens (rhs_tokens);
		}

		public void visit_ternary_expression (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "?") {
					ctx.write (" ? ");
				} else if (ck == ":") {
					ctx.write (" : ");
				} else if (ck == "(" || ck == ")") {
					ctx.write (ck);
				} else if (ck == ",") {
					ctx.write (", ");
				} else if (child.is_named && ck != "comment") {
					visit_expression_or_atom (child);
				}
			}
		}

		private class BinaryGap {
			public GenericArray<TreeSitter.Node?> comments = new GenericArray<TreeSitter.Node?> ();
		}

		private bool has_parens_or_commas (TreeSitter.Node node) {
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node c = node.child (i);
				if (!c.is_named) {
					string ck = ctx.kind (c);
					if (ck == "(" || ck == ")" || ck == ",") {
						return true;
					}
				}
			}
			return false;
		}

		private void collect_binary_operands (
				TreeSitter.Node expr,
				string op,
				GenericArray<TreeSitter.Node?> operands,
				GenericArray<BinaryGap> gaps
		) {
			if (ctx.kind (expr) == "parenthesized_expression" || has_parens_or_commas (expr)) {
				operands.add (expr);
				return;
			}
			bool is_same = false;
			TreeSitter.Node? l = null;
			TreeSitter.Node? r = null;
			var mid_comments = new BinaryGap ();
			uint32 count = expr.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node c = expr.child (i);
				string ck = ctx.kind (c);
				if (!c.is_named && ck == op) {
					is_same = true;
				} else if (ck == "comment") {
					if (l != null && r == null) {
						mid_comments.comments.add (c);
					}
				} else if (c.is_named) {
					if (l == null) {
						l = c;
					} else {
						r = c;
					}
				}
			}
			if (is_same && l != null && r != null) {
				collect_binary_operands (l, op, operands, gaps);
				gaps.add (mid_comments);
				operands.add (r);
			} else {
				operands.add (expr);
			}
		}

		private bool is_inner_binary_node (TreeSitter.Node node, string op) {
			TreeSitter.Node? p = node.parent;
			if (p == null || has_parens_or_commas (p)) {
				return false;
			}
			uint32 count = p.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node c = p.child (i);
				if (!c.is_named && ctx.kind (c) == op) {
					if (p.child_count > 0) {
						TreeSitter.Node c0 = p.child (0);
						if (c0.start_byte == node.start_byte && c0.end_byte == node.end_byte) {
							return true;
						}
					}
				}
			}
			return false;
		}

		public void visit_binary_or_assignment_expression (TreeSitter.Node node) {
			string op = "";
			if (!has_parens_or_commas (node)) {
				uint32 count = node.child_count;
				for (uint32 i = 0; i < count; i++) {
					TreeSitter.Node child = node.child (i);
					string ck = ctx.kind (child);
					if (!child.is_named && (ck == "&&" || ck == "||" || ck == "+")) {
						op = ck;
						break;
					}
				}
			}
			if (op != "") {
				if (is_inner_binary_node (node, op)) {
					return;
				}
				var operands = new GenericArray<TreeSitter.Node?> ();
				var gaps = new GenericArray<BinaryGap> ();
				collect_binary_operands (node, op, operands, gaps);
				if (operands.length >= 2) {
					bool has_comments = false;
					for (int g = 0; g < gaps.length; g++) {
						if (gaps.get (g).comments.length > 0) {
							has_comments = true;
							break;
						}
					}
					bool is_multiline = node.end_point.row > node.start_point.row;
					int total_len = 0;
					for (int i = 0; i < operands.length; i++) {
						if (i > 0) {
							total_len += op.length + 2;
						}
						total_len += printer.measure_node_flat_width (operands.get (i));
					}
					bool exceeds_limit = ctx.get_current_line_width () + total_len > ctx.config.line_length;
					if (has_comments || is_multiline || exceeds_limit) {
						visit_expression_or_atom (operands.get (0));
						for (int i = 1; i < operands.length; i++) {
							BinaryGap gap = gaps.get (i - 1);
							int prev_end_row = (int) operands.get (i - 1).end_point.row;
							for (int c = 0; c < gap.comments.length; c++) {
								TreeSitter.Node cn = gap.comments.get (c);
								if (c == 0
										&& ctx.is_single_line_comment (cn)
										&& (int) cn.start_point.row == prev_end_row) {
									ctx.write (" ");
									ctx.write (ctx.format_single_line_comment (cn));
								} else {
									ctx.write ("\n");
									var csb = new StringBuilder ();
									ctx.append_indented_comment (csb, cn, ctx.indent_level + 2);
									ctx.write (csb.str.chomp ());
								}
							}
							ctx.write ("\n");
							ctx.write (ctx.config.get_indent_string (ctx.indent_level + 2));
							ctx.write (op + " ");
							ctx.indent_level += 2;
							visit_expression_or_atom (operands.get (i));
							ctx.indent_level -= 2;
						}
						return;
					} else {
						for (int i = 0; i < operands.length; i++) {
							if (i > 0) {
								ctx.write (" " + op + " ");
							}
							visit_expression_or_atom (operands.get (i));
						}
						return;
					}
				}
			}
			int last_end_row = -1;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "(" || ck == ")") {
					ctx.write (ck);
					last_end_row = (int) child.end_point.row;
				} else if (ck == ",") {
					ctx.write (", ");
					last_end_row = (int) child.end_point.row;
				} else if (ck == "comment") {
					if (ctx.is_single_line_comment (child)
							&& last_end_row >= 0
							&& (int) child.start_point.row == last_end_row) {
						ctx.write (" ");
						ctx.write (ctx.format_single_line_comment (child));
					} else {
						ctx.write ("\n");
						var csb = new StringBuilder ();
						ctx.append_indented_comment (csb, child, ctx.indent_level + 2);
						ctx.write (csb.str.chomp ());
					}
					if (i + 1 < count) {
						ctx.write ("\n");
						ctx.write (ctx.config.get_indent_string (ctx.indent_level + 2));
					}
				} else if (!child.is_named) {
					ctx.write (" " + ck + " ");
					last_end_row = (int) child.end_point.row;
				} else {
					visit_expression_or_atom (child);
					last_end_row = (int) child.end_point.row;
				}
			}
		}
	}
}
