/* cst_declaration_formatter.vala
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
	internal class CstDeclarationFormatter {
		public unowned CstLayoutContext ctx;
		public unowned CstPrettyPrinter printer;

		public CstDeclarationFormatter (CstLayoutContext ctx, CstPrettyPrinter printer) {
			this.ctx = ctx;
			this.printer = printer;
		}

		private const int BASE_TYPE_WRAP_COLUMN_ESTIMATE = 50;
		public void visit_using_directive (TreeSitter.Node node) {
			ctx.write_indent ();
			ctx.write ("using ");
			bool first = true;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "symbol") {
					if (!first) {
						ctx.write (", ");
					}
					ctx.write (printer.types.format_symbol (child));
					first = false;
				}
			}
			ctx.write (";\n");
		}

		public void visit_member_container (TreeSitter.Node node) {
			var attrs = new GenericArray<string> ();
			printer.types.collect_attributes_and_comments (node, attrs);
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck.has_suffix ("_declaration")) {
					visit_declaration (child, attrs);
				} else if (ck.has_suffix ("_directive")) {
					ctx.emit_preprocessor_directive (child);
				}
			}
		}

		public void visit_declaration (TreeSitter.Node decl, GenericArray<string> attrs) {
			string dk = ctx.kind (decl);
			if (dk == "namespace_declaration") {
				visit_namespace_declaration (decl, attrs);
			} else if (dk == "class_declaration") {
				visit_type_declaration (decl, attrs, "class", "class_member");
			} else if (dk == "interface_declaration") {
				visit_type_declaration (decl, attrs, "interface", "interface_member");
			} else if (dk == "struct_declaration") {
				visit_type_declaration (decl, attrs, "struct", "struct_member");
			} else if (dk == "enum_declaration") {
				visit_enumerated_declaration (decl, attrs, "enum", "enum_value");
			} else if (dk == "errordomain_declaration") {
				visit_enumerated_declaration (decl, attrs, "errordomain", "errorcode");
			} else if (dk == "delegate_declaration") {
				visit_callable_declaration (decl, attrs, "delegate ", true, true);
			} else if (dk == "method_declaration") {
				visit_callable_declaration (decl, attrs, "", true, false);
			} else if (dk == "creation_method_declaration") {
				visit_callable_declaration (decl, attrs, "", false, false);
			} else if (dk == "signal_declaration") {
				visit_callable_declaration (decl, attrs, "signal ", true, false);
			} else if (dk == "field_declaration") {
				visit_typed_member_declaration (decl, attrs, "");
			} else if (dk == "constant_declaration") {
				visit_typed_member_declaration (decl, attrs, "const ");
			} else if (dk == "property_declaration") {
				visit_property_declaration (decl, attrs);
			} else if (dk == "constructor_declaration") {
				visit_constructor_declaration (decl, attrs);
			} else if (dk == "destructor_declaration") {
				visit_destructor_declaration (decl, attrs);
			}
		}

		public void visit_namespace_declaration (TreeSitter.Node decl, GenericArray<string> attrs) {
			ctx.emit_attribute_lines (attrs);
			string sym_name = "";
			bool in_body = false;
			int open_brace_row = -1;
			bool has_emitted = false;
			int last_end_row = -1;
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (!in_body) {
					if (ck == "comment") {
						ctx.emit_comment_node (child);
					} else if (ck == "symbol") {
						sym_name = printer.types.format_symbol (child);
					} else if (ck == "{") {
						open_brace_row = (int) child.end_point.row;
						ctx.write_indent ();
						ctx.write ("namespace ");
						ctx.write (sym_name);
						ctx.write (" {\n");
						ctx.indent_level++;
						in_body = true;
					}
				} else {
					if (ck == "empty_statement") {
						continue;
					}
					if (ck == "comment") {
						ctx.emit_container_comment (child, open_brace_row, ref has_emitted, ref last_end_row);
					} else if (ck == "using_directive") {
						ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
						visit_using_directive (child);
						has_emitted = true;
						last_end_row = (int) child.end_point.row;
					} else if (ck == "namespace_member") {
						ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
						visit_member_container (child);
						has_emitted = true;
						last_end_row = (int) child.end_point.row;
					} else if (ck.has_suffix ("_directive")) {
						ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
						ctx.emit_preprocessor_directive (child);
						has_emitted = true;
						last_end_row = (int) child.end_point.row;
					} else if (ck == "}") {
						ctx.indent_level--;
						ctx.trim_trailing_blank_lines ();
						ctx.write_line ("}");
						ctx.write ("\n");
					}
				}
			}
		}

		private string format_base_types_clause (GenericArray<string> base_types, int current_col) {
			if (base_types.length == 0) {
				return "";
			}
			var inline_sb = new StringBuilder (" : ");
			for (int i = 0; i < base_types.length; i++) {
				if (i > 0) {
					inline_sb.append (", ");
				}
				inline_sb.append (base_types.get (i));
			}
			string inline_str = inline_sb.str;
			if (current_col + CstLayoutContext.measure_utf8_display_width (inline_str) <= ctx.config.line_length) {
				return inline_str;
			}
			var wrap_sb = new StringBuilder (" : ");
			for (int i = 0; i < base_types.length; i++) {
				if (i > 0) {
					wrap_sb.append (",\n");
					wrap_sb.append (ctx.config.get_indent_string (ctx.indent_level + 2));
				}
				wrap_sb.append (base_types.get (i));
			}
			return wrap_sb.str;
		}

		private void visit_type_declaration (
				TreeSitter.Node decl,
				GenericArray<string> attrs,
				string keyword,
				string member_kind
		) {
			ctx.emit_attribute_lines (attrs);
			string mods = printer.types.format_modifiers (decl);
			string name = "";
			var base_types = new GenericArray<string> ();
			bool in_body = false;
			int open_brace_row = -1;
			bool has_emitted = false;
			int last_end_row = -1;
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (!in_body) {
					if (ck == "comment") {
						ctx.emit_comment_node (child);
					} else if (ck == "unqualified_type") {
						name = printer.types.format_unqualified_type (child);
					} else if (ck == "type") {
						base_types.add (printer.types.format_type (child));
					} else if (ck == "{") {
						open_brace_row = (int) child.end_point.row;
						ctx.write_indent ();
						ctx.write (mods);
						ctx.write (keyword + " ");
						ctx.write (name);
						if (base_types.length > 0) {
							ctx.write (format_base_types_clause (base_types, BASE_TYPE_WRAP_COLUMN_ESTIMATE));
						}
						ctx.write (" {\n");
						ctx.indent_level++;
						in_body = true;
					}
				} else {
					if (ck == "empty_statement") {
						continue;
					}
					if (ck == "comment") {
						ctx.emit_container_comment (child, open_brace_row, ref has_emitted, ref last_end_row);
					} else if (ck == member_kind) {
						ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
						visit_member_container (child);
						has_emitted = true;
						last_end_row = (int) child.end_point.row;
					} else if (ck.has_suffix ("_directive")) {
						ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
						ctx.emit_preprocessor_directive (child);
						has_emitted = true;
						last_end_row = (int) child.end_point.row;
					} else if (ck == "}") {
						ctx.indent_level--;
						ctx.trim_trailing_blank_lines ();
						ctx.write_line ("}");
						ctx.write ("\n");
					}
				}
			}
		}

		private void visit_enumerated_declaration (
				TreeSitter.Node decl,
				GenericArray<string> attrs,
				string keyword,
				string item_kind
		) {
			ctx.emit_attribute_lines (attrs);
			string mods = printer.types.format_modifiers (decl);
			string name = "";
			var body_nodes = new GenericArray<TreeSitter.Node?> ();
			var trailing_nodes = new GenericArray<TreeSitter.Node?> ();
			bool has_trailing_decls = false;
			bool in_body = false;
			int open_brace_row = -1;
			bool after_semi = false;
			int total_items = 0;
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (!in_body) {
					if (ck == "comment" && name == "") {
						ctx.emit_comment_node (child);
					} else if (ck == "symbol" && name == "") {
						name = printer.types.format_symbol (child);
					} else if (ck == "{") {
						open_brace_row = (int) child.end_point.row;
						in_body = true;
					}
				} else {
					if (ck == "}") {
						break;
					}
					if (ck == ";") {
						after_semi = true;
					} else if (ck == "attribute") {
						after_semi = true;
						trailing_nodes.add (child);
					} else if (ck.has_suffix ("_declaration")) {
						after_semi = true;
						has_trailing_decls = true;
						trailing_nodes.add (child);
					} else if (ck == item_kind) {
						total_items++;
						body_nodes.add (child);
					} else if (ck == "comment") {
						if (after_semi) {
							trailing_nodes.add (child);
						} else {
							body_nodes.add (child);
						}
					}
				}
			}
			ctx.write_indent ();
			ctx.write (mods);
			ctx.write (keyword + " ");
			ctx.write (name);
			ctx.write (" {\n");
			ctx.indent_level++;
			bool has_emitted = false;
			int last_end_row = -1;
			int seen_items = 0;
			for (int i = 0; i < body_nodes.length; i++) {
				TreeSitter.Node item = body_nodes.get (i);
				string ik = ctx.kind (item);
				if (ik == "comment") {
					ctx.emit_container_comment (item, open_brace_row, ref has_emitted, ref last_end_row);
					continue;
				}
				ctx.maybe_emit_blank_line (has_emitted, last_end_row, item);
				seen_items++;
				var item_attrs = new GenericArray<string> ();
				printer.types.collect_attributes_and_comments (item, item_attrs);
				ctx.emit_attribute_lines (item_attrs);
				string item_name = "";
				string item_val = "";
				var val_tokens = new GenericArray<TreeSitter.Node?> ();
				bool after_eq = false;
				uint32 icount = item.child_count;
				for (uint32 j = 0; j < icount; j++) {
					TreeSitter.Node sub = item.child (j);
					string sck = ctx.kind (sub);
					if (sck == "identifier" && item_name == "") {
						item_name = CstHelpers.format_identifier (ctx.text (sub));
					} else if (sck == "=") {
						after_eq = true;
					} else if (after_eq && (sck == "(" || sck == ")" || sck == "," || (sub.is_named
							&& sck != "attribute"
							&& sck != "comment"))) {
						val_tokens.add (sub);
					}
				}
				if (val_tokens.length > 0) {
					item_val = printer.format_expression_tokens_inline (val_tokens);
				}
				ctx.write_indent ();
				ctx.write (item_name);
				if (item_val != "") {
					ctx.write (" = ");
					ctx.write (item_val);
				}
				if (seen_items < total_items) {
					ctx.write (",\n");
				} else if (has_trailing_decls) {
					ctx.write (";\n");
				} else {
					ctx.write ("\n");
				}
				has_emitted = true;
				last_end_row = (int) item.end_point.row;
			}
			var pending_attrs = new GenericArray<string> ();
			for (int m = 0; m < trailing_nodes.length; m++) {
				TreeSitter.Node tn = trailing_nodes.get (m);
				string tnk = ctx.kind (tn);
				if (tnk == "attribute") {
					if (pending_attrs.length == 0) {
						ctx.maybe_emit_blank_line (has_emitted, last_end_row, tn);
					}
					pending_attrs.add ("[" + printer.types.format_single_attribute (tn) + "]");
					last_end_row = (int) tn.end_point.row;
				} else if (tnk == "comment") {
					if (pending_attrs.length > 0) {
						ctx.emit_attribute_lines (pending_attrs);
						pending_attrs = new GenericArray<string> ();
						has_emitted = true;
					}
					ctx.emit_container_comment (tn, open_brace_row, ref has_emitted, ref last_end_row);
				} else {
					if (pending_attrs.length == 0) {
						ctx.maybe_emit_blank_line (has_emitted, last_end_row, tn);
					}
					visit_declaration (tn, pending_attrs);
					pending_attrs = new GenericArray<string> ();
					has_emitted = true;
					last_end_row = (int) tn.end_point.row;
				}
			}
			if (pending_attrs.length > 0) {
				ctx.emit_attribute_lines (pending_attrs);
			}
			ctx.indent_level--;
			ctx.trim_trailing_blank_lines ();
			ctx.write_line ("}");
			ctx.write ("\n");
		}

		public string format_parameter_node (TreeSitter.Node param) {
			if (ctx.text (param).strip () == "...") {
				return "...";
			}
			var attrs = new GenericArray<string> ();
			printer.types.collect_attributes_and_comments (param, attrs);
			var sb = new StringBuilder ();
			for (int i = 0; i < attrs.length; i++) {
				sb.append (attrs.get (i) + " ");
			}
			bool has_params = false;
			string dir = "";
			string type_str = "";
			string id_str = "";
			string inline_arr = "";
			var init_tokens = new GenericArray<TreeSitter.Node?> ();
			bool after_eq = false;
			uint32 count = param.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = param.child (i);
				string ck = ctx.kind (child);
				if (ck == "params") {
					has_params = true;
				} else if (ck == "parameter_direction_modifier" || ck == "out" || ck == "ref") {
					dir = ctx.text (child).strip ();
				} else if (ck == "type" && type_str == "") {
					type_str = printer.types.format_type (child);
				} else if (ck == "identifier" && id_str == "") {
					id_str = CstHelpers.format_identifier (ctx.text (child));
				} else if (ck == "inline_array_type") {
					inline_arr = printer.exprs.format_inline_array_type (child);
				} else if (ck == "=") {
					after_eq = true;
				} else if (after_eq && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					init_tokens.add (child);
				}
			}
			if (has_params) {
				sb.append ("params ");
			}
			if (dir != "") {
				sb.append (dir + " ");
			}
			if (type_str != "") {
				sb.append (type_str + " ");
			}
			sb.append (id_str + inline_arr);
			if (init_tokens.length > 0) {
				sb.append (" = " + printer.format_expression_tokens_inline (init_tokens));
			}
			return sb.str;
		}

		public string format_parameter_list (
				GenericArray<TreeSitter.Node?> items,
				int current_col = 0,
				int open_paren_row = -1
		) {
			if (items.length == 0) {
				return "()";
			}
			int param_count = 0;
			bool has_comments = false;
			for (int i = 0; i < items.length; i++) {
				if (ctx.kind (items.get (i)) == "comment") {
					has_comments = true;
				} else {
					param_count++;
				}
			}
			if (!has_comments) {
				var inline_sb = new StringBuilder ("(");
				for (int i = 0; i < items.length; i++) {
					if (i > 0) {
						inline_sb.append (", ");
					}
					inline_sb.append (format_parameter_node (items.get (i)));
				}
				inline_sb.append (")");
				string inline_str = inline_sb.str;
				if (current_col + CstLayoutContext.measure_utf8_display_width (inline_str) <= ctx.config.line_length) {
					return inline_str;
				}
				var wrap_sb = new StringBuilder ("(\n");
				int arg_indent = ctx.indent_level + 2;
				for (int i = 0; i < items.length; i++) {
					wrap_sb.append (ctx.config.get_indent_string (arg_indent));
					wrap_sb.append (format_parameter_node (items.get (i)));
					if (i < items.length - 1) {
						wrap_sb.append (",\n");
					}
				}
				wrap_sb.append ("\n");
				wrap_sb.append (ctx.config.get_indent_string (ctx.indent_level));
				wrap_sb.append (")");
				return wrap_sb.str;
			}
			return "("
					+ ctx.format_wrapped_list_with_comments (
							items,
							param_count,
							open_paren_row,
							true,
							(item, item_indent) => format_parameter_node (item)
					)
					+ ")";
		}

		private void emit_throws_clause (GenericArray<string> throws_types) {
			if (throws_types.length > 0) {
				ctx.write (" throws ");
				for (int i = 0; i < throws_types.length; i++) {
					if (i > 0) {
						ctx.write (", ");
					}
					ctx.write (throws_types.get (i));
				}
			}
		}

		private void emit_contract_clauses (GenericArray<TreeSitter.Node?> clauses) {
			for (int i = 0; i < clauses.length; i++) {
				TreeSitter.Node clause = clauses.get (i);
				string kw = "requires";
				var cond_tokens = new GenericArray<TreeSitter.Node?> ();
				var cond_comments = new GenericArray<TreeSitter.Node?> ();
				bool in_cond = false;
				int paren_depth = 0;
				uint32 count = clause.child_count;
				for (uint32 j = 0; j < count; j++) {
					TreeSitter.Node c = clause.child (j);
					string ck = ctx.kind (c);
					if (ck == "requires" || ck == "ensures") {
						kw = ck;
					} else if (!in_cond && ck == "(") {
						in_cond = true;
						paren_depth = 1;
					} else if (in_cond) {
						if (ck == "(") {
							paren_depth++;
							cond_tokens.add (c);
						} else if (ck == ")") {
							paren_depth--;
							if (paren_depth == 0) {
								in_cond = false;
							} else {
								cond_tokens.add (c);
							}
						} else if (ck == "comment") {
							if (cond_tokens.length > 0) {
								cond_comments.add (c);
							}
						} else if (ck == "," || c.is_named) {
							cond_tokens.add (c);
						}
					}
				}
				if (cond_comments.length == 0 && cond_tokens.length > 0) {
					string cond_inline = printer.format_expression_tokens_inline (cond_tokens);
					string clause_str = kw + " (" + cond_inline + ")";
					if (!cond_inline.contains ("\n")
							&& ctx.get_current_line_width ()
									+ 1
									+ CstLayoutContext.measure_utf8_display_width (clause_str) <= ctx.config.line_length) {
						ctx.write (" " + clause_str);
						continue;
					}
					ctx.write ("\n");
					ctx.indent_level += 2;
					ctx.write_indent ();
					ctx.write (kw + " (");
					printer.emit_expression_tokens (cond_tokens);
					ctx.write (")");
					ctx.indent_level -= 2;
				} else {
					if (ctx.get_current_line_width () + 1 + kw.length + 2 > ctx.config.line_length) {
						ctx.write ("\n");
						ctx.indent_level += 2;
						ctx.write_indent ();
						ctx.write (kw + " (");
						printer.stmts.emit_condition_with_comments (cond_tokens, cond_comments);
						ctx.write (")");
						ctx.indent_level -= 2;
					} else {
						ctx.write (" " + kw + " (");
						printer.stmts.emit_condition_with_comments (cond_tokens, cond_comments);
						ctx.write (")");
					}
				}
			}
		}

		private void visit_callable_declaration (
				TreeSitter.Node decl,
				GenericArray<string> attrs,
				string keyword_prefix,
				bool has_return_type,
				bool is_delegate
		) {
			ctx.emit_attribute_lines (attrs);
			string mods = printer.types.format_modifiers (decl);
			string ret_type = "";
			string sym_name = "";
			string type_args = "";
			var parameters = new GenericArray<TreeSitter.Node?> ();
			var throws_types = new GenericArray<string> ();
			var contract_clauses = new GenericArray<TreeSitter.Node?> ();
			bool in_throws = false;
			bool in_params = false;
			bool after_params = false;
			int open_paren_row = -1;
			TreeSitter.Node? body_block = null;
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (ck == "(" && !in_params && !after_params) {
					in_params = true;
					open_paren_row = (int) child.end_point.row;
				} else if (ck == ")" && in_params) {
					in_params = false;
					after_params = true;
				} else if (ck == "comment") {
					if (in_params) {
						parameters.add (child);
					} else {
						ctx.emit_comment_node (child);
					}
				} else if (ck == "type" && has_return_type && !in_throws && ret_type == "") {
					ret_type = printer.types.format_type (child);
				} else if (ck == "symbol" && sym_name == "") {
					sym_name = printer.types.format_symbol (child);
				} else if (ck == "type_arguments" && type_args == "") {
					type_args = printer.types.format_type_arguments (child);
				} else if (ck == "parameter") {
					parameters.add (child);
				} else if (ck == "throws") {
					in_throws = true;
				} else if (ck == "type" && in_throws) {
					throws_types.add (printer.types.format_type (child));
				} else if (ck == "contract_clause") {
					in_throws = false;
					contract_clauses.add (child);
				} else if (ck == "requires" || ck == "ensures") {
					in_throws = false;
				} else if (ck == "block") {
					body_block = child;
				}
			}
			ctx.write_indent ();
			ctx.write (mods);
			ctx.write (keyword_prefix);
			if (has_return_type) {
				ctx.write (ret_type);
				ctx.write (" ");
			}
			ctx.write (sym_name);
			ctx.write (type_args);
			ctx.write (" ");
			ctx.write (format_parameter_list (parameters, ctx.get_current_line_width (), open_paren_row));
			emit_throws_clause (throws_types);
			emit_contract_clauses (contract_clauses);
			if (is_delegate) {
				ctx.write (";\n");
			} else {
				if (body_block != null) {
					printer.stmts.visit_block (body_block);
					ctx.write ("\n");
				} else {
					ctx.write (";\n");
				}
				ctx.write ("\n");
			}
		}

		private void visit_typed_member_declaration (
				TreeSitter.Node decl,
				GenericArray<string> attrs,
				string keyword_prefix
		) {
			ctx.emit_attribute_lines (attrs);
			string mods = printer.types.format_modifiers (decl);
			string member_type = "";
			var assignments = new GenericArray<TreeSitter.Node?> ();
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "type" && member_type == "") {
					member_type = printer.types.format_type (child);
				} else if (ck == "assignment" || ck == "identifier") {
					assignments.add (child);
				}
			}
			for (int i = 0; i < assignments.length; i++) {
				ctx.write_indent ();
				ctx.write (mods);
				ctx.write (keyword_prefix);
				ctx.write (member_type);
				ctx.write (" ");
				ctx.write (printer.stmts.format_assignment (assignments.get (i)));
				ctx.write (";\n");
			}
		}

		public void visit_property_declaration (TreeSitter.Node decl, GenericArray<string> attrs) {
			ctx.emit_attribute_lines (attrs);
			string mods = printer.types.format_modifiers (decl);
			string ptype = "";
			string pname = "";
			var accessors = new GenericArray<TreeSitter.Node?> ();
			bool has_accessor_bodies = false;
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "type" && ptype == "") {
					ptype = printer.types.format_type (child);
				} else if (ck == "symbol" && pname == "") {
					pname = printer.types.format_symbol (child);
				} else if (ck == "property_accessor" || ck == "property_default") {
					accessors.add (child);
					if (ck == "property_accessor") {
						uint32 acount = child.child_count;
						for (uint32 j = 0; j < acount; j++) {
							if (ctx.kind (child.child (j)) == "block") {
								has_accessor_bodies = true;
							}
						}
					}
				}
			}
			ctx.write_indent ();
			ctx.write (mods);
			ctx.write (ptype);
			ctx.write (" ");
			ctx.write (pname);
			if (!has_accessor_bodies) {
				ctx.write (" { ");
				for (int i = 0; i < accessors.length; i++) {
					TreeSitter.Node acc = accessors.get (i);
					string ak = ctx.kind (acc);
					if (ak == "property_default") {
						var def_tokens = new GenericArray<TreeSitter.Node?> ();
						bool after_eq = false;
						uint32 dcount = acc.child_count;
						for (uint32 j = 0; j < dcount; j++) {
							TreeSitter.Node dc = acc.child (j);
							string dck = ctx.kind (dc);
							if (dck == "=") {
								after_eq = true;
							} else if (after_eq && (dck == "(" || dck == ")" || dck == "," || (dc.is_named
									&& dck != "comment"))) {
								def_tokens.add (dc);
							}
						}
						ctx.write ("default = ");
						if (def_tokens.length > 0) {
							ctx.write (printer.format_expression_tokens_inline (def_tokens));
						}
						ctx.write ("; ");
					} else {
						var sb = new StringBuilder ();
						var acc_attrs = new GenericArray<string> ();
						printer.types.collect_attributes_and_comments (acc, acc_attrs);
						for (int a = 0; a < acc_attrs.length; a++) {
							if (sb.len > 0) {
								sb.append (" ");
							}
							sb.append (acc_attrs.get (a));
						}
						uint32 acount = acc.child_count;
						for (uint32 j = 0; j < acount; j++) {
							TreeSitter.Node ac = acc.child (j);
							string ack = ctx.kind (ac);
							if (ack == "access_modifier"
									|| ack == "owned"
									|| ack == "get"
									|| ack == "set"
									|| ack == "construct") {
								if (sb.len > 0) {
									sb.append (" ");
								}
								sb.append (ctx.text (ac).strip ());
							}
						}
						ctx.write (sb.str + "; ");
					}
				}
				ctx.write ("}\n");
			} else {
				ctx.write (" {\n");
				ctx.indent_level++;
				for (int i = 0; i < accessors.length; i++) {
					TreeSitter.Node acc = accessors.get (i);
					string ak = ctx.kind (acc);
					if (ak == "property_default") {
						var def_tokens = new GenericArray<TreeSitter.Node?> ();
						bool after_eq = false;
						uint32 dcount = acc.child_count;
						for (uint32 j = 0; j < dcount; j++) {
							TreeSitter.Node dc = acc.child (j);
							string dck = ctx.kind (dc);
							if (dck == "=") {
								after_eq = true;
							} else if (after_eq && (dck == "(" || dck == ")" || dck == "," || (dc.is_named
									&& dck != "comment"))) {
								def_tokens.add (dc);
							}
						}
						ctx.write_indent ();
						ctx.write ("default = ");
						if (def_tokens.length > 0) {
							printer.emit_expression_tokens (def_tokens);
						}
						ctx.write (";\n");
					} else {
						var acc_attrs = new GenericArray<string> ();
						printer.types.collect_attributes_and_comments (acc, acc_attrs);
						ctx.emit_attribute_lines (acc_attrs);
						var head_sb = new StringBuilder ();
						TreeSitter.Node? acc_block = null;
						uint32 acount = acc.child_count;
						for (uint32 j = 0; j < acount; j++) {
							TreeSitter.Node ac = acc.child (j);
							string ack = ctx.kind (ac);
							if (ack == "access_modifier"
									|| ack == "owned"
									|| ack == "get"
									|| ack == "set"
									|| ack == "construct") {
								if (head_sb.len > 0) {
									head_sb.append (" ");
								}
								head_sb.append (ctx.text (ac).strip ());
							} else if (ack == "block") {
								acc_block = ac;
							}
						}
						ctx.write_indent ();
						ctx.write (head_sb.str);
						if (acc_block != null) {
							printer.stmts.visit_block (acc_block);
							ctx.write ("\n");
						} else {
							ctx.write (";\n");
						}
					}
				}
				ctx.indent_level--;
				ctx.trim_trailing_blank_lines ();
				ctx.write_indent ();
				ctx.write ("}\n");
			}
		}

		public void visit_constructor_declaration (TreeSitter.Node decl, GenericArray<string> attrs) {
			ctx.emit_attribute_lines (attrs);
			string mods = printer.types.format_modifiers (decl);
			TreeSitter.Node? body_block = null;
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "block") {
					body_block = child;
				}
			}
			ctx.write_indent ();
			ctx.write (mods);
			ctx.write ("construct");
			if (body_block != null) {
				printer.stmts.visit_block (body_block);
				ctx.write ("\n");
			}
			ctx.write ("\n");
		}

		public void visit_destructor_declaration (TreeSitter.Node decl, GenericArray<string> attrs) {
			ctx.emit_attribute_lines (attrs);
			string mods = printer.types.format_modifiers (decl);
			string dname = "";
			TreeSitter.Node? body_block = null;
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "identifier" && dname == "") {
					dname = ctx.text (child);
				} else if (ck == "block") {
					body_block = child;
				}
			}
			ctx.write_indent ();
			ctx.write (mods);
			ctx.write ("~" + dname + " ()");
			if (body_block != null) {
				printer.stmts.visit_block (body_block);
				ctx.write ("\n");
			}
			ctx.write ("\n");
		}
	}
}
