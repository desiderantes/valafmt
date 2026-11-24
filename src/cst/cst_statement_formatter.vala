/* cst_statement_formatter.vala
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
	internal class CstStatementFormatter {
		public unowned CstLayoutContext ctx;
		public unowned CstPrettyPrinter printer;

		public CstStatementFormatter (CstLayoutContext ctx, CstPrettyPrinter printer) {
			this.ctx = ctx;
			this.printer = printer;
		}

		public void visit_block (TreeSitter.Node block) {
			ctx.write (" {\n");
			ctx.indent_level++;
			int open_brace_row = -1;
			bool has_emitted = false;
			int last_end_row = -1;
			uint32 count = block.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = block.child (i);
				string ck = ctx.kind (child);
				if (ck == "{") {
					open_brace_row = (int) child.end_point.row;
					continue;
				}
				if (ck == "}" || ck == "empty_statement") {
					continue;
				}
				if (ck == "comment") {
					ctx.emit_container_comment (child, open_brace_row, ref has_emitted, ref last_end_row);
				} else if (ck.has_suffix ("_directive")) {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					ctx.emit_preprocessor_directive (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				} else if (child.is_named) {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					visit_statement (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				}
			}
			ctx.indent_level--;
			ctx.trim_trailing_blank_lines ();
			ctx.write_indent ();
			ctx.write ("}");
		}

		private void write_body_in_block (TreeSitter.Node body) {
			if (ctx.kind (body) == "block") {
				visit_block (body);
			} else {
				ctx.write (" {\n");
				ctx.indent_level++;
				visit_statement (body);
				ctx.indent_level--;
				ctx.trim_trailing_blank_lines ();
				ctx.write_indent ();
				ctx.write ("}");
			}
		}

		public void visit_statement (TreeSitter.Node stmt) {
			string sk = ctx.kind (stmt);
			if (sk == "comment") {
				ctx.emit_comment_node (stmt);
			} else if (sk == "block") {
				ctx.write_indent ();
				visit_block (stmt);
				ctx.write ("\n");
			} else if (sk == "empty_statement") {
				// Remove stray empty semicolons
			} else if (sk == "local_declaration") {
				visit_local_declaration (stmt);
			} else if (sk == "local_function_declaration") {
				visit_local_function_declaration (stmt);
			} else if (sk == "expression_statement") {
				visit_expression_statement (stmt);
			} else if (sk == "return_statement") {
				visit_return_statement (stmt);
			} else if (sk == "if_statement") {
				ctx.write_indent ();
				visit_if_statement (stmt);
			} else if (sk == "while_statement") {
				visit_paren_expr_block_statement (stmt, "while");
			} else if (sk == "do_statement") {
				visit_do_statement (stmt);
			} else if (sk == "for_statement") {
				visit_for_statement (stmt);
			} else if (sk == "foreach_statement") {
				visit_foreach_statement (stmt);
			} else if (sk == "try_statement") {
				visit_try_statement (stmt);
			} else if (sk == "switch_statement") {
				visit_switch_statement (stmt);
			} else if (sk == "lock_statement") {
				visit_paren_expr_block_statement (stmt, "lock");
			} else if (sk == "unlock_statement") {
				visit_unlock_statement (stmt);
			} else if (sk == "with_statement") {
				visit_paren_expr_block_statement (stmt, "with");
			} else if (sk == "keyword_assignment_statement") {
				visit_keyword_assignment_statement (stmt);
			} else if (sk == "break_statement") {
				ctx.write_line ("break;");
			} else if (sk == "continue_statement") {
				ctx.write_line ("continue;");
			} else if (sk == "delete_statement") {
				visit_keyword_expr_statement (stmt, "delete");
			} else if (sk == "throw_statement") {
				visit_keyword_expr_statement (stmt, "throw");
			} else if (sk == "yield_statement") {
				visit_yield_statement (stmt);
			}
		}

		public void visit_keyword_assignment_statement (TreeSitter.Node stmt) {
			string lhs = "";
			string op = "=";
			bool after_op = false;
			var rhs_tokens = new GenericArray<TreeSitter.Node?> ();
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "identifier" && lhs == "") {
					lhs = CstHelpers.format_identifier (ctx.text (child));
				} else if (lhs != "" && !after_op && !child.is_named && ck != ";") {
					op = ctx.text (child).strip ();
					after_op = true;
				} else if (after_op && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					rhs_tokens.add (child);
				}
			}
			ctx.write_indent ();
			ctx.write (lhs + " " + op + " ");
			if (rhs_tokens.length > 0) {
				printer.emit_expression_tokens (rhs_tokens);
			}
			ctx.write (";\n");
		}

		public void visit_unlock_statement (TreeSitter.Node stmt) {
			var expr_tokens = new GenericArray<TreeSitter.Node?> ();
			bool in_parens = false;
			int paren_depth = 0;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (!in_parens && ck == "(") {
					in_parens = true;
					paren_depth = 1;
				} else if (in_parens) {
					if (ck == "(") {
						paren_depth++;
						expr_tokens.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth == 0) {
							in_parens = false;
						} else {
							expr_tokens.add (child);
						}
					} else if (ck == "," || child.is_named) {
						expr_tokens.add (child);
					}
				}
			}
			ctx.write_indent ();
			ctx.write ("unlock (");
			if (expr_tokens.length > 0) {
				printer.emit_expression_tokens (expr_tokens);
			}
			ctx.write (");\n");
		}

		public string format_assignment (TreeSitter.Node assign_node) {
			if (ctx.kind (assign_node) == "identifier") {
				return CstHelpers.format_identifier (ctx.text (assign_node));
			}
			string id_str = "";
			string inline_arr = "";
			var init_tokens = new GenericArray<TreeSitter.Node?> ();
			bool after_eq = false;
			uint32 count = assign_node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = assign_node.child (i);
				string ck = ctx.kind (child);
				if (ck == "identifier" && id_str == "") {
					id_str = CstHelpers.format_identifier (ctx.text (child));
				} else if (ck == "inline_array_type") {
					inline_arr = printer.exprs.format_inline_array_type (child);
				} else if (ck == "=") {
					after_eq = true;
				} else if (after_eq && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					init_tokens.add (child);
				}
			}
			var sb = new StringBuilder ();
			sb.append (id_str + inline_arr);
			if (init_tokens.length > 0) {
				sb.append (" = ");
				int rhs_col = ctx.get_current_line_width () + CstLayoutContext.measure_utf8_display_width (sb.str);
				sb.append (printer.format_expression_tokens_inline (init_tokens, -1, rhs_col));
			}
			return sb.str;
		}

		public void visit_local_declaration (TreeSitter.Node stmt) {
			bool is_const = false;
			bool is_tuple = false;
			bool after_eq = false;
			string ltype = "";
			var assignments = new GenericArray<TreeSitter.Node?> ();
			var tuple_ids = new GenericArray<string> ();
			var tuple_rhs_tokens = new GenericArray<TreeSitter.Node?> ();
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "const") {
					is_const = true;
				} else if (ck == "var") {
					is_tuple = true;
				} else if (ck == "=") {
					after_eq = true;
				} else if (ck == "type" && ltype == "") {
					ltype = printer.types.format_type (child);
				} else if (ck == "assignment") {
					assignments.add (child);
				} else if (is_tuple && !after_eq && ck == "identifier") {
					tuple_ids.add (CstHelpers.format_identifier (ctx.text (child)));
				} else if (is_tuple && after_eq && (ck == "(" || ck == ")" || ck == "," || (child.is_named
						&& ck != "comment"))) {
					tuple_rhs_tokens.add (child);
				}
			}
			if (assignments.length == 0 && tuple_ids.length > 0) {
				ctx.write_indent ();
				ctx.write ("var (");
				for (int i = 0; i < tuple_ids.length; i++) {
					if (i > 0) {
						ctx.write (", ");
					}
					ctx.write (tuple_ids.get (i));
				}
				ctx.write (") = ");
				if (tuple_rhs_tokens.length > 0) {
					printer.emit_expression_tokens (tuple_rhs_tokens);
				}
				ctx.write (";\n");
				return;
			}
			// Rule `one-var-per-declaration`: emit each variable declaration on its own statement line
			for (int i = 0; i < assignments.length; i++) {
				ctx.write_indent ();
				if (is_const) {
					ctx.write ("const ");
				}
				ctx.write (ltype);
				ctx.write (" ");
				ctx.write (format_assignment (assignments.get (i)));
				ctx.write (";\n");
			}
		}

		public void visit_local_function_declaration (TreeSitter.Node stmt) {
			var mods = new StringBuilder ();
			string rtype = "";
			string fname = "";
			var parameters = new GenericArray<TreeSitter.Node?> ();
			bool in_params = false;
			bool after_params = false;
			int open_paren_row = -1;
			TreeSitter.Node? body_block = null;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
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
				} else if ((ck == "static" || ck == "extern") && rtype == "") {
					mods.append (ck + " ");
				} else if (ck == "type" && rtype == "") {
					rtype = printer.types.format_type (child);
				} else if (ck == "identifier" && fname == "") {
					fname = CstHelpers.format_identifier (ctx.text (child));
				} else if (ck == "parameter") {
					parameters.add (child);
				} else if (ck == "block") {
					body_block = child;
				}
			}
			ctx.write_indent ();
			ctx.write (mods.str + rtype + " " + fname + " ");
			ctx.write (printer.decls.format_parameter_list (parameters, ctx.get_current_line_width (), open_paren_row));
			if (body_block != null) {
				visit_block (body_block);
			}
			ctx.write ("\n");
		}

		public void visit_expression_statement (TreeSitter.Node stmt) {
			var expr_tokens = new GenericArray<TreeSitter.Node?> ();
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "(" || ck == ")" || ck == "," || child.is_named) {
					expr_tokens.add (child);
				}
			}
			if (expr_tokens.length > 0) {
				ctx.write_indent ();
				printer.emit_expression_tokens (expr_tokens);
				ctx.write (";\n");
			}
		}

		public void visit_return_statement (TreeSitter.Node stmt) {
			var expr_tokens = new GenericArray<TreeSitter.Node?> ();
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "(" || ck == ")" || ck == "," || child.is_named) {
					expr_tokens.add (child);
				}
			}
			ctx.write_indent ();
			ctx.write ("return");
			if (expr_tokens.length > 0) {
				ctx.write (" ");
				printer.emit_expression_tokens (expr_tokens);
			}
			ctx.write (";\n");
		}

		public void emit_condition_with_comments (
				GenericArray<TreeSitter.Node?> cond_tokens,
				GenericArray<TreeSitter.Node?> cond_trailing_comments
		) {
			if (cond_tokens.length > 0) {
				printer.emit_expression_tokens (cond_tokens);
			}
			if (cond_trailing_comments.length > 0) {
				for (int c = 0; c < cond_trailing_comments.length; c++) {
					TreeSitter.Node comment_node = cond_trailing_comments.get (c);
					if (ctx.is_single_line_comment (comment_node)) {
						ctx.write (" ");
						ctx.write (ctx.format_single_line_comment (comment_node));
						ctx.write ("\n");
					} else {
						ctx.write ("\n");
						ctx.indent_level += 2;
						ctx.emit_comment_node (comment_node);
						ctx.indent_level -= 2;
					}
				}
				ctx.write_indent ();
			}
		}

		public void visit_if_statement (TreeSitter.Node stmt) {
			var cond_tokens = new GenericArray<TreeSitter.Node?> ();
			var cond_trailing_comments = new GenericArray<TreeSitter.Node?> ();
			TreeSitter.Node? true_stmt = null;
			var after_true_nodes = new GenericArray<TreeSitter.Node?> ();
			bool in_cond = false;
			int paren_depth = 0;
			bool after_rparen = false;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (!in_cond && !after_rparen && ck == "(") {
					in_cond = true;
					paren_depth = 1;
				} else if (in_cond) {
					if (ck == "(") {
						paren_depth++;
						cond_tokens.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth == 0) {
							in_cond = false;
							after_rparen = true;
						} else {
							cond_tokens.add (child);
						}
					} else if (ck == "comment") {
						if (cond_tokens.length > 0) {
							cond_trailing_comments.add (child);
						}
					} else if (ck == "," || child.is_named) {
						cond_tokens.add (child);
					}
				} else if (after_rparen) {
					if (ck == "elseif_statement" || ck == "else_statement") {
						after_true_nodes.add (child);
					} else if (ck == "comment") {
						if (true_stmt != null) {
							after_true_nodes.add (child);
						}
					} else if (child.is_named && true_stmt == null) {
						true_stmt = child;
					}
				}
			}
			ctx.write ("if (");
			emit_condition_with_comments (cond_tokens, cond_trailing_comments);
			ctx.write (")");
			int last_end_row = -1;
			if (true_stmt != null) {
				write_body_in_block (true_stmt);
				last_end_row = (int) true_stmt.end_point.row;
			}
			bool line_open = true;
			for (int i = 0; i < after_true_nodes.length; i++) {
				TreeSitter.Node child = after_true_nodes.get (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					if (line_open
							&& ctx.is_single_line_comment (child)
							&& last_end_row >= 0
							&& (int) child.start_point.row == last_end_row) {
						ctx.write (" " + ctx.format_single_line_comment (child) + "\n");
						line_open = false;
					} else {
						if (line_open) {
							ctx.write ("\n");
							line_open = false;
						}
						ctx.emit_comment_node (child);
						last_end_row = (int) child.end_point.row;
					}
				} else if (ck == "elseif_statement") {
					var econd_tokens = new GenericArray<TreeSitter.Node?> ();
					var pre_econd_comments = new GenericArray<TreeSitter.Node?> ();
					var econd_trailing_comments = new GenericArray<TreeSitter.Node?> ();
					TreeSitter.Node? ebody = null;
					bool e_in_cond = false;
					int e_paren_depth = 0;
					bool e_after_rparen = false;
					uint32 ecount = child.child_count;
					for (uint32 j = 0; j < ecount; j++) {
						TreeSitter.Node ec = child.child (j);
						string eck = ctx.kind (ec);
						if (!e_in_cond && !e_after_rparen && eck == "(") {
							e_in_cond = true;
							e_paren_depth = 1;
						} else if (e_in_cond) {
							if (eck == "(") {
								e_paren_depth++;
								econd_tokens.add (ec);
							} else if (eck == ")") {
								e_paren_depth--;
								if (e_paren_depth == 0) {
									e_in_cond = false;
									e_after_rparen = true;
								} else {
									econd_tokens.add (ec);
								}
							} else if (eck == "comment") {
								if (econd_tokens.length > 0) {
									econd_trailing_comments.add (ec);
								} else {
									pre_econd_comments.add (ec);
								}
							} else if (eck == "," || ec.is_named) {
								econd_tokens.add (ec);
							}
						} else if (!e_after_rparen && eck == "comment") {
							pre_econd_comments.add (ec);
						} else if (e_after_rparen && ec.is_named && eck != "comment" && ebody == null) {
							ebody = ec;
						}
					}
					for (int c = 0; c < pre_econd_comments.length; c++) {
						TreeSitter.Node pc = pre_econd_comments.get (c);
						if (line_open
								&& ctx.is_single_line_comment (pc)
								&& last_end_row >= 0
								&& (int) pc.start_point.row == last_end_row) {
							ctx.write (" " + ctx.format_single_line_comment (pc) + "\n");
							line_open = false;
						} else {
							if (line_open) {
								ctx.write ("\n");
								line_open = false;
							}
							ctx.emit_comment_node (pc);
							last_end_row = (int) pc.end_point.row;
						}
					}
					if (line_open) {
						ctx.write (" ");
					} else {
						ctx.write_indent ();
					}
					ctx.write ("else if (");
					emit_condition_with_comments (econd_tokens, econd_trailing_comments);
					ctx.write (")");
					if (ebody != null) {
						write_body_in_block (ebody);
						last_end_row = (int) ebody.end_point.row;
					}
					line_open = true;
				} else if (ck == "else_statement") {
					TreeSitter.Node? ebody = null;
					var pre_ebody_comments = new GenericArray<TreeSitter.Node?> ();
					uint32 ecount = child.child_count;
					for (uint32 j = 0; j < ecount; j++) {
						TreeSitter.Node ec = child.child (j);
						string eck = ctx.kind (ec);
						if (eck == "comment" && ebody == null) {
							pre_ebody_comments.add (ec);
						} else if (ec.is_named && eck != "comment" && ebody == null) {
							ebody = ec;
						}
					}
					if (ebody != null && ctx.kind (ebody) == "if_statement") {
						if (line_open) {
							ctx.write (" ");
						} else {
							ctx.write_indent ();
						}
						ctx.write ("else");
						if (pre_ebody_comments.length > 0) {
							int else_row = (int) child.start_point.row;
							bool else_line_open = true;
							for (int c = 0; c < pre_ebody_comments.length; c++) {
								TreeSitter.Node pc = pre_ebody_comments.get (c);
								if (else_line_open
										&& ctx.is_single_line_comment (pc)
										&& (int) pc.start_point.row == else_row) {
									ctx.write (" " + ctx.format_single_line_comment (pc) + "\n");
									else_line_open = false;
								} else {
									if (else_line_open) {
										ctx.write ("\n");
										else_line_open = false;
									}
									ctx.emit_comment_node (pc);
									else_row = (int) pc.end_point.row;
								}
							}
							if (else_line_open) {
								ctx.write (" ");
							} else {
								ctx.write_indent ();
							}
						} else {
							ctx.write (" ");
						}
						visit_if_statement (ebody);
						return;
					}
					for (int c = 0; c < pre_ebody_comments.length; c++) {
						TreeSitter.Node pc = pre_ebody_comments.get (c);
						if (line_open
								&& ctx.is_single_line_comment (pc)
								&& last_end_row >= 0
								&& (int) pc.start_point.row == last_end_row) {
							ctx.write (" " + ctx.format_single_line_comment (pc) + "\n");
							line_open = false;
						} else {
							if (line_open) {
								ctx.write ("\n");
								line_open = false;
							}
							ctx.emit_comment_node (pc);
							last_end_row = (int) pc.end_point.row;
						}
					}
					if (line_open) {
						ctx.write (" ");
					} else {
						ctx.write_indent ();
					}
					ctx.write ("else");
					if (ebody != null) {
						write_body_in_block (ebody);
						last_end_row = (int) ebody.end_point.row;
					}
					line_open = true;
				}
			}
			if (line_open) {
				ctx.write ("\n");
			}
		}

		private void visit_paren_expr_block_statement (TreeSitter.Node stmt, string keyword) {
			TreeSitter.Node? decl_type = null;
			var expr_tokens = new GenericArray<TreeSitter.Node?> ();
			var expr_trailing_comments = new GenericArray<TreeSitter.Node?> ();
			TreeSitter.Node? body = null;
			bool in_parens = false;
			int paren_depth = 0;
			bool after_rparen = false;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (!in_parens && !after_rparen && ck == "(") {
					in_parens = true;
					paren_depth = 1;
				} else if (in_parens) {
					if (ck == "(") {
						paren_depth++;
						expr_tokens.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth == 0) {
							in_parens = false;
							after_rparen = true;
						} else {
							expr_tokens.add (child);
						}
					} else if (ck == "comment") {
						if (expr_tokens.length > 0) {
							expr_trailing_comments.add (child);
						}
					} else if (ck == "type" && decl_type == null && expr_tokens.length == 0) {
						decl_type = child;
					} else if (ck == "," || child.is_named) {
						expr_tokens.add (child);
					}
				} else if (after_rparen && child.is_named && ck != "comment" && body == null) {
					body = child;
				}
			}
			ctx.write_indent ();
			ctx.write (keyword + " (");
			if (decl_type != null && expr_tokens.length == 1 && ctx.kind (expr_tokens.get (0)) == "assignment") {
				ctx.write (printer.types.format_type (decl_type) + " " + format_assignment (expr_tokens.get (0)));
				var empty_tokens = new GenericArray<TreeSitter.Node?> ();
				emit_condition_with_comments (empty_tokens, expr_trailing_comments);
			} else {
				emit_condition_with_comments (expr_tokens, expr_trailing_comments);
			}
			ctx.write (")");
			if (body != null) {
				write_body_in_block (body);
			}
			ctx.write ("\n");
		}

		public void visit_do_statement (TreeSitter.Node stmt) {
			TreeSitter.Node? body = null;
			var cond_tokens = new GenericArray<TreeSitter.Node?> ();
			bool after_while = false;
			bool in_cond = false;
			int paren_depth = 0;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "while") {
					after_while = true;
				} else if (!after_while && child.is_named && ck != "comment" && body == null) {
					body = child;
				} else if (after_while) {
					if (!in_cond && ck == "(") {
						in_cond = true;
						paren_depth = 1;
					} else if (in_cond) {
						if (ck == "(") {
							paren_depth++;
							cond_tokens.add (child);
						} else if (ck == ")") {
							paren_depth--;
							if (paren_depth == 0) {
								in_cond = false;
							} else {
								cond_tokens.add (child);
							}
						} else if (ck == "," || (child.is_named && ck != "comment")) {
							cond_tokens.add (child);
						}
					}
				}
			}
			ctx.write_indent ();
			ctx.write ("do");
			if (body != null) {
				write_body_in_block (body);
			}
			ctx.write (" while (");
			if (cond_tokens.length > 0) {
				printer.emit_expression_tokens (cond_tokens);
			}
			ctx.write (");\n");
		}

		private string format_local_declaration_inline (TreeSitter.Node decl) {
			bool is_const = false;
			string ltype = "";
			var assignments = new GenericArray<string> ();
			uint32 count = decl.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl.child (i);
				string ck = ctx.kind (child);
				if (ck == "const") {
					is_const = true;
				} else if (ck == "type" && ltype == "") {
					ltype = printer.types.format_type (child);
				} else if (ck == "assignment") {
					assignments.add (format_assignment (child));
				}
			}
			var sb = new StringBuilder ((is_const ? "const " : "") + ltype + " ");
			for (int i = 0; i < assignments.length; i++) {
				if (i > 0) {
					sb.append (", ");
				}
				sb.append (assignments.get (i));
			}
			return sb.str;
		}

		public void visit_for_statement (TreeSitter.Node stmt) {
			string init_str = "";
			string cond_str = "";
			var init_tokens = new GenericArray<TreeSitter.Node?> ();
			var cond_tokens = new GenericArray<TreeSitter.Node?> ();
			var current_iter = new GenericArray<TreeSitter.Node?> ();
			var iters = new GenericArray<string> ();
			TreeSitter.Node? body = null;
			int section = 0;
			int paren_depth = 0;
			// 0 = before (, 1 = init, 2 = cond, 3 = iter, 4 = body
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (section == 0) {
					if (ck == "(") {
						section = 1;
						paren_depth = 1;
					}
				} else if (section == 1) {
					if (ck == "local_declaration") {
						init_str = format_local_declaration_inline (child);
						section = 2;
						// local_declaration includes its own ';'
					} else if (ck == ";") {
						if (init_tokens.length > 0) {
							init_str = printer.format_expression_tokens_inline (init_tokens);
						}
						section = 2;
					} else if (ck == "(") {
						paren_depth++;
						init_tokens.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth > 0) {
							init_tokens.add (child);
						}
					} else if (ck == "," || (child.is_named && ck != "comment")) {
						init_tokens.add (child);
					}
				} else if (section == 2) {
					if (ck == ";") {
						if (cond_tokens.length > 0) {
							cond_str = printer.format_expression_tokens_inline (cond_tokens);
						}
						section = 3;
					} else if (ck == "(") {
						paren_depth++;
						cond_tokens.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth > 0) {
							cond_tokens.add (child);
						}
					} else if (ck == "," || (child.is_named && ck != "comment")) {
						cond_tokens.add (child);
					}
				} else if (section == 3) {
					if (ck == "(") {
						paren_depth++;
						current_iter.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth == 0) {
							if (current_iter.length > 0) {
								iters.add (printer.format_expression_tokens_inline (current_iter));
								current_iter = new GenericArray<TreeSitter.Node?> ();
							}
							section = 4;
						} else {
							current_iter.add (child);
						}
					} else if (ck == "," && paren_depth == 1) {
						if (current_iter.length > 0) {
							iters.add (printer.format_expression_tokens_inline (current_iter));
							current_iter = new GenericArray<TreeSitter.Node?> ();
						}
					} else if (ck == "," || (child.is_named && ck != "comment")) {
						current_iter.add (child);
					}
				} else if (section == 4) {
					if (child.is_named && ck != "comment" && body == null) {
						body = child;
					}
				}
			}
			ctx.write_indent ();
			ctx.write ("for (");
			ctx.write (init_str);
			ctx.write ("; ");
			ctx.write (cond_str);
			ctx.write ("; ");
			for (int i = 0; i < iters.length; i++) {
				if (i > 0) {
					ctx.write (", ");
				}
				ctx.write (iters.get (i));
			}
			ctx.write (")");
			if (body != null) {
				write_body_in_block (body);
			}
			ctx.write ("\n");
		}

		public void visit_foreach_statement (TreeSitter.Node stmt) {
			string ftype = "var";
			string fname = "";
			var collection_tokens = new GenericArray<TreeSitter.Node?> ();
			TreeSitter.Node? body = null;
			int paren_depth = 0;
			bool after_in = false;
			bool after_rparen = false;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "(" && !after_in && paren_depth == 0) {
					paren_depth = 1;
				} else if (ck == "in" && !after_in) {
					after_in = true;
				} else if (!after_in && !after_rparen) {
					if (ck == "type") {
						ftype = printer.types.format_type (child);
					} else if (ck == "identifier") {
						fname = CstHelpers.format_identifier (ctx.text (child));
					}
				} else if (after_in && !after_rparen) {
					if (ck == "(") {
						paren_depth++;
						collection_tokens.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth == 0) {
							after_rparen = true;
						} else {
							collection_tokens.add (child);
						}
					} else if (ck == "," || (child.is_named && ck != "comment")) {
						collection_tokens.add (child);
					}
				} else if (after_rparen) {
					if (child.is_named && ck != "comment" && body == null) {
						body = child;
					}
				}
			}
			ctx.write_indent ();
			ctx.write ("foreach (");
			ctx.write (ftype + " " + fname + " in ");
			if (collection_tokens.length > 0) {
				printer.emit_expression_tokens (collection_tokens);
			}
			ctx.write (")");
			if (body != null) {
				write_body_in_block (body);
			}
			ctx.write ("\n");
		}

		public void visit_try_statement (TreeSitter.Node stmt) {
			ctx.write_indent ();
			ctx.write ("try");
			bool line_open = false;
			int last_end_row = -1;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "block") {
					visit_block (child);
					last_end_row = (int) child.end_point.row;
					line_open = true;
				} else if (ck == "comment") {
					if (line_open
							&& ctx.is_single_line_comment (child)
							&& last_end_row >= 0
							&& (int) child.start_point.row == last_end_row) {
						ctx.write (" " + ctx.format_single_line_comment (child) + "\n");
						line_open = false;
					} else {
						if (line_open) {
							ctx.write ("\n");
							line_open = false;
						}
						ctx.emit_comment_node (child);
						last_end_row = (int) child.end_point.row;
					}
				} else if (ck == "catch_clause") {
					if (line_open) {
						ctx.write (" ");
					} else {
						ctx.write_indent ();
					}
					visit_catch_clause (child, false);
					last_end_row = (int) child.end_point.row;
					line_open = true;
				} else if (ck == "finally_clause") {
					if (line_open) {
						ctx.write (" ");
					} else {
						ctx.write_indent ();
					}
					visit_finally_clause (child, false);
					last_end_row = (int) child.end_point.row;
					line_open = true;
				}
			}
			if (line_open) {
				ctx.write ("\n");
			}
		}

		public void visit_catch_clause (TreeSitter.Node clause, bool leading_space = true) {
			string err_type = "";
			string err_id = "";
			TreeSitter.Node? body_block = null;
			uint32 count = clause.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = clause.child (i);
				string ck = ctx.kind (child);
				if (ck == "type") {
					err_type = printer.types.format_type (child);
				} else if (ck == "identifier") {
					err_id = CstHelpers.format_identifier (ctx.text (child));
				} else if (ck == "block") {
					body_block = child;
				}
			}
			ctx.write (leading_space ? " catch" : "catch");
			if (err_id != "") {
				if (err_type == "") {
					err_type = "GLib.Error";
				}
				ctx.write (" (" + err_type + " " + err_id + ")");
			}
			if (body_block != null) {
				visit_block (body_block);
			}
		}

		public void visit_finally_clause (TreeSitter.Node clause, bool leading_space = true) {
			ctx.write (leading_space ? " finally" : "finally");
			uint32 count = clause.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = clause.child (i);
				if (ctx.kind (child) == "block") {
					visit_block (child);
				}
			}
		}

		public void visit_switch_statement (TreeSitter.Node stmt) {
			var expr_tokens = new GenericArray<TreeSitter.Node?> ();
			var expr_trailing_comments = new GenericArray<TreeSitter.Node?> ();
			var body_nodes = new GenericArray<TreeSitter.Node?> ();
			bool in_cond = false;
			int paren_depth = 0;
			bool in_braces = false;
			bool after_rparen = false;
			int open_brace_row = -1;
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (!in_braces && !in_cond && !after_rparen && ck == "(") {
					in_cond = true;
					paren_depth = 1;
				} else if (!in_braces && in_cond) {
					if (ck == "(") {
						paren_depth++;
						expr_tokens.add (child);
					} else if (ck == ")") {
						paren_depth--;
						if (paren_depth == 0) {
							in_cond = false;
							after_rparen = true;
						} else {
							expr_tokens.add (child);
						}
					} else if (ck == "comment") {
						if (expr_tokens.length > 0) {
							expr_trailing_comments.add (child);
						}
					} else if (ck == "," || child.is_named) {
						expr_tokens.add (child);
					}
				} else if (ck == "{") {
					in_braces = true;
					open_brace_row = (int) child.end_point.row;
				} else if (in_braces && (ck == "switch_section" || ck == "comment")) {
					body_nodes.add (child);
				}
			}
			ctx.write_indent ();
			ctx.write ("switch (");
			emit_condition_with_comments (expr_tokens, expr_trailing_comments);
			ctx.write (") {\n");
			ctx.indent_level++;
			bool has_emitted = false;
			int last_end_row = -1;
			for (int i = 0; i < body_nodes.length; i++) {
				TreeSitter.Node child = body_nodes.get (i);
				if (ctx.kind (child) == "comment") {
					ctx.emit_container_comment (child, open_brace_row, ref has_emitted, ref last_end_row);
				} else {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					visit_switch_section (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				}
			}
			ctx.indent_level--;
			ctx.trim_trailing_blank_lines ();
			ctx.write_line ("}");
		}

		public void visit_switch_section (TreeSitter.Node section) {
			bool is_default = false;
			var case_tokens = new GenericArray<TreeSitter.Node?> ();
			var stmts = new GenericArray<TreeSitter.Node?> ();
			bool after_colon = false;
			int colon_row = -1;
			uint32 count = section.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = section.child (i);
				string ck = ctx.kind (child);
				if (ck == "default" && !after_colon) {
					is_default = true;
				} else if (ck == ":" && !after_colon) {
					after_colon = true;
					colon_row = (int) child.end_point.row;
				} else if (!after_colon && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					case_tokens.add (child);
				} else if (after_colon && child.is_named && ck != "empty_statement") {
					stmts.add (child);
				}
			}
			ctx.write_indent ();
			if (is_default) {
				ctx.write ("default:\n");
			} else {
				ctx.write ("case ");
				printer.emit_expression_tokens (case_tokens);
				ctx.write (":\n");
			}
			ctx.indent_level++;
			bool has_emitted = false;
			int last_end_row = -1;
			for (int i = 0; i < stmts.length; i++) {
				TreeSitter.Node child = stmts.get (i);
				if (ctx.kind (child) == "comment") {
					ctx.emit_container_comment (child, colon_row, ref has_emitted, ref last_end_row);
				} else {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					visit_statement (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				}
			}
			ctx.indent_level--;
		}

		private void visit_keyword_expr_statement (TreeSitter.Node stmt, string keyword) {
			var expr_tokens = new GenericArray<TreeSitter.Node?> ();
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment")) {
					expr_tokens.add (child);
				}
			}
			ctx.write_indent ();
			ctx.write (keyword + " ");
			printer.emit_expression_tokens (expr_tokens);
			ctx.write (";\n");
		}

		public void visit_yield_statement (TreeSitter.Node stmt) {
			bool has_return = false;
			var expr_tokens = new GenericArray<TreeSitter.Node?> ();
			uint32 count = stmt.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = stmt.child (i);
				string ck = ctx.kind (child);
				if (ck == "return") {
					has_return = true;
				} else if (has_return && (ck == "(" || ck == ")" || ck == "," || (child.is_named && ck != "comment"))) {
					expr_tokens.add (child);
				}
			}
			ctx.write_indent ();
			ctx.write ("yield");
			if (has_return && expr_tokens.length > 0) {
				ctx.write (" return ");
				printer.emit_expression_tokens (expr_tokens);
			}
			ctx.write (";\n");
		}
	}
}
