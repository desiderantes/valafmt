/* cst_pretty_printer.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Coordinator for CST pretty-printing, wiring CstLayoutContext to focused delegate formatters.
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
	internal class CstPrettyPrinter {
		public CstLayoutContext ctx;
		public CstTypeFormatter types;
		public CstDeclarationFormatter decls;
		public CstStatementFormatter stmts;
		public CstExpressionFormatter exprs;

		public CstPrettyPrinter (Config config, string source) {
			this.ctx = new CstLayoutContext (config, source);
			this.types = new CstTypeFormatter (this.ctx, this);
			this.decls = new CstDeclarationFormatter (this.ctx, this);
			this.stmts = new CstStatementFormatter (this.ctx, this);
			this.exprs = new CstExpressionFormatter (this.ctx, this);
		}

		public string finalize_document () {
			return ctx.finalize_document ();
		}

		public int measure_node_flat_width (TreeSitter.Node node) {
			int w = CstWidthMeasurer.flat_width (node, ctx.source);
			if (w >= 0) {
				return w;
			}
			return CstLayoutContext.measure_utf8_display_width (print_node_inline (node));
		}

		public string print_node_inline (TreeSitter.Node node, int base_indent = -1, int initial_col = -1) {
			int new_indent = base_indent >= 0 ? base_indent : ctx.indent_level;
			int new_col = initial_col >= 0 ? initial_col : new_indent * CstCommentFormatter.TAB_DISPLAY_WIDTH;
			int saved_indent;
			int saved_col;
			StringBuilder saved = ctx.push_inline_buffer (new_indent, new_col, out saved_indent, out saved_col);
			exprs.visit_expression_or_atom (node);
			return ctx.pop_inline_buffer_stripped ((owned) saved, saved_indent, saved_col);
		}

		public void emit_expression_tokens (GenericArray<TreeSitter.Node?> tokens) {
			for (int i = 0; i < tokens.length; i++) {
				TreeSitter.Node tok = tokens.get (i);
				string tk = ctx.kind (tok);
				if (tk == "(" || tk == ")") {
					ctx.write (tk);
				} else if (tk == ",") {
					ctx.write (", ");
				} else if (tok.is_named && tk != "comment") {
					exprs.visit_expression_or_atom (tok);
				}
			}
		}

		public string format_expression_tokens_inline (
				GenericArray<TreeSitter.Node?> tokens,
				int base_indent = -1,
				int initial_col = -1
		) {
			int new_indent = base_indent >= 0 ? base_indent : ctx.indent_level;
			int new_col = initial_col >= 0 ? initial_col : new_indent * CstCommentFormatter.TAB_DISPLAY_WIDTH;
			int saved_indent;
			int saved_col;
			StringBuilder saved = ctx.push_inline_buffer (new_indent, new_col, out saved_indent, out saved_col);
			emit_expression_tokens (tokens);
			return ctx.pop_inline_buffer_stripped ((owned) saved, saved_indent, saved_col);
		}

		public void visit_source_file (TreeSitter.Node root) {
			bool has_emitted = false;
			int last_end_row = -1;
			uint32 count = root.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = root.child (i);
				string ck = ctx.kind (child);
				if (ck == "empty_statement") {
					continue;
				}
				if (ck == "comment") {
					ctx.emit_container_comment (child, -1, ref has_emitted, ref last_end_row);
				} else if (ck == "using_directive") {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					decls.visit_using_directive (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				} else if (ck == "namespace_member") {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					decls.visit_member_container (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				} else if (ck.has_suffix ("_directive")) {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					ctx.emit_preprocessor_directive (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				} else if (child.is_named) {
					ctx.maybe_emit_blank_line (has_emitted, last_end_row, child);
					stmts.visit_statement (child);
					has_emitted = true;
					last_end_row = (int) child.end_point.row;
				}
			}
		}
	}
}
