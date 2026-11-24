/* cst_layout_context.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Shared output buffer, indentation/column cursor, and comment/directive emission helpers
 * passed to all CST delegate formatters.
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
	internal delegate string WrappedListItemFormatter (TreeSitter.Node item, int item_indent);

	[Compact]
	internal class CstLayoutContext {
		public unowned Config config;
		public unowned string source;
		public int indent_level = 0;
		public int current_column = 0;
		public StringBuilder builder = new StringBuilder ();

		public CstLayoutContext (Config config, string source) {
			this.config = config;
			this.source = source;
		}

		public StringBuilder push_inline_buffer (int new_indent, int new_col, out int saved_indent, out int saved_col) {
			saved_indent = indent_level;
			saved_col = current_column;
			StringBuilder saved = (owned) builder;
			builder = new StringBuilder ();
			indent_level = new_indent;
			current_column = new_col;
			return saved;
		}

		public string pop_inline_buffer_stripped (owned StringBuilder saved, int saved_indent, int saved_col) {
			string captured = builder.str.strip ();
			builder = (owned) saved;
			indent_level = saved_indent;
			current_column = saved_col;
			return captured;
		}

		public string finalize_document () {
			if (builder.len == 0) {
				return "";
			}
			trim_trailing_blank_lines ();
			string out_str = builder.str;
			while (out_str.has_prefix ("\n")) {
				out_str = out_str.substring (1);
			}
			if (out_str.strip ().length == 0) {
				return "";
			}
			if (!out_str.has_suffix ("\n")) {
				out_str += "\n";
			}
			return out_str;
		}

		public void trim_trailing_blank_lines () {
			while (builder.len >= 2
					&& builder.str[builder.len - 1] == '\n'
					&& builder.str[builder.len - 2] == '\n') {
				builder.truncate (builder.len - 1);
			}
			if (builder.len > 0 && builder.str[builder.len - 1] == '\n') {
				current_column = 0;
			}
		}

		public static int measure_utf8_display_width (string text, int start_offset = 0) {
			return CstWidthMeasurer.measure_utf8_display_width (text, start_offset);
		}

		public void write (string text) {
			builder.append (text);
			int last_nl = text.last_index_of_char ('\n');
			if (last_nl >= 0) {
				current_column = measure_utf8_display_width (text, last_nl + 1);
			} else {
				current_column += measure_utf8_display_width (text, 0);
			}
		}

		public void write_indent () {
			write (config.get_indent_string (indent_level));
		}

		public void write_line (string text = "") {
			if (text.length > 0) {
				write_indent ();
				write (text);
			}
			write ("\n");
		}

		public int get_current_line_width () {
			return current_column;
		}

		public string text (TreeSitter.Node node) {
			return CstHelpers.node_text (node, source);
		}

		public string kind (TreeSitter.Node node) {
			return CstHelpers.node_type (node);
		}

		public bool is_single_line_comment (TreeSitter.Node node) {
			return CstCommentFormatter.is_single_line_comment (node);
		}

		public string format_single_line_comment (TreeSitter.Node node) {
			return CstCommentFormatter.format_single_line_comment (node, source);
		}

		public bool can_attach_trailing_comment (TreeSitter.Node node, int anchor_row) {
			return anchor_row >= 0
					&& is_single_line_comment (node)
					&& (int) node.start_point.row == anchor_row
					&& builder.len > 0
					&& builder.str[builder.len - 1] == '\n';
		}

		public void emit_trailing_comment (TreeSitter.Node node) {
			long len = builder.len;
			int nl_count = 0;
			while (len > 0 && builder.str[len - 1] == '\n') {
				len--;
				nl_count++;
			}
			builder.truncate (len);
			write (" ");
			write (format_single_line_comment (node));
			for (int i = 0; i < nl_count; i++) {
				write ("\n");
			}
		}

		public void maybe_emit_blank_line (bool has_emitted, int last_end_row, TreeSitter.Node next_node) {
			if (has_emitted
					&& last_end_row >= 0
					&& (int) next_node.start_point.row - last_end_row > 1
					&& !builder.str.has_suffix ("\n\n")) {
				write ("\n");
			}
		}

		public void emit_container_comment (
				TreeSitter.Node comment,
				int open_anchor_row,
				ref bool has_emitted,
				ref int last_end_row
		) {
			if (!has_emitted && can_attach_trailing_comment (comment, open_anchor_row)) {
				emit_trailing_comment (comment);
			} else if (has_emitted && can_attach_trailing_comment (comment, last_end_row)) {
				emit_trailing_comment (comment);
			} else {
				maybe_emit_blank_line (has_emitted, last_end_row, comment);
				emit_comment_node (comment);
				has_emitted = true;
				last_end_row = (int) comment.end_point.row;
			}
		}

		public string format_wrapped_list_with_comments (
				GenericArray<TreeSitter.Node?> items,
				int item_count,
				int open_paren_row,
				bool close_on_new_line,
				WrappedListItemFormatter format_item
		) {
			var wrap_sb = new StringBuilder ();
			int arg_indent = indent_level + 2;
			bool wrote_nl_after_open = false;
			int seen_items = 0;
			int last_item_end_row = open_paren_row;
			bool line_open = false;
			for (int i = 0; i < items.length; i++) {
				TreeSitter.Node item = items.get (i);
				if (kind (item) == "comment") {
					if (!line_open
							&& !wrote_nl_after_open
							&& is_single_line_comment (item)
							&& open_paren_row >= 0
							&& (int) item.start_point.row == open_paren_row) {
						wrap_sb.append (" " + format_single_line_comment (item) + "\n");
						wrote_nl_after_open = true;
					} else if (line_open
							&& is_single_line_comment (item)
							&& last_item_end_row >= 0
							&& (int) item.start_point.row == last_item_end_row) {
						wrap_sb.append (" " + format_single_line_comment (item) + "\n");
						line_open = false;
					} else {
						if (!wrote_nl_after_open) {
							wrap_sb.append ("\n");
							wrote_nl_after_open = true;
						}
						if (line_open) {
							wrap_sb.append ("\n");
							line_open = false;
						}
						append_indented_comment (wrap_sb, item, arg_indent);
						last_item_end_row = (int) item.end_point.row;
					}
				} else {
					if (!wrote_nl_after_open) {
						wrap_sb.append ("\n");
						wrote_nl_after_open = true;
					}
					if (line_open) {
						wrap_sb.append ("\n");
						line_open = false;
					}
					wrap_sb.append (config.get_indent_string (arg_indent));
					wrap_sb.append (format_item (item, arg_indent));
					seen_items++;
					if (seen_items < item_count) {
						wrap_sb.append (",");
					}
					line_open = true;
					last_item_end_row = (int) item.end_point.row;
				}
			}
			if (!wrote_nl_after_open) {
				wrap_sb.append ("\n");
			}
			if (line_open) {
				if (close_on_new_line) {
					wrap_sb.append ("\n");
					wrap_sb.append (config.get_indent_string (indent_level));
				}
			} else {
				wrap_sb.append (config.get_indent_string (indent_level));
			}
			return wrap_sb.str;
		}

		public void append_indented_comment (StringBuilder sb, TreeSitter.Node node, int target_indent) {
			sb.append (CstCommentFormatter.format_comment_lines (node, source, config, target_indent));
		}

		public void emit_comment_node (TreeSitter.Node node) {
			string formatted = CstCommentFormatter.format_comment_lines (node, source, config, indent_level);
			if (formatted.length > 0) {
				write (formatted);
			}
		}

		public void emit_preprocessor_directive (TreeSitter.Node node) {
			string t = kind (node);
			write ("#" + t.replace ("_directive", ""));
			bool wrote_space = false;
			string prev_tok = "";
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = kind (child);
				if (ck == "if" || ck == "elif" || ck == "else" || ck == "endif") {
					continue;
				}
				string tok = text (child).strip ();
				if (tok.length == 0) {
					continue;
				}
				if (!wrote_space) {
					write (" ");
					wrote_space = true;
				} else if (prev_tok != "!" && prev_tok != "(" && tok != ")") {
					write (" ");
				}
				write (tok);
				prev_tok = tok;
			}
			write ("\n");
		}

		public void emit_attribute_lines (GenericArray<string> attrs) {
			for (int i = 0; i < attrs.length; i++) {
				write_line (attrs.get (i));
			}
		}
	}
}
