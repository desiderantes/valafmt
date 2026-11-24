/* cst_comment_formatter.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * Stateless comment formatting and block/Valadoc indentation helpers for the CST pretty-printer.
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
	internal class CstCommentFormatter : GLib.Object {
		public const int TAB_DISPLAY_WIDTH = 4;

		public static bool is_single_line_comment (TreeSitter.Node node) {
			return CstHelpers.node_type (node) == "comment" && node.start_point.row == node.end_point.row;
		}

		public static string format_single_line_comment (TreeSitter.Node node, string source) {
			string trimmed = CstHelpers.node_text (node, source).strip ();
			if (trimmed.has_prefix ("/*") || trimmed.has_prefix ("//")) {
				return CstHelpers.normalize_comment_line (trimmed);
			}
			return "// " + trimmed;
		}

		private static string strip_leading_whitespace (string line) {
			int i = 0;
			while (i < line.length && (line[i] == ' ' || line[i] == '\t')) {
				i++;
			}
			return line.substring (i);
		}

		private static string strip_prefix_columns (string line, int cols) {
			int i = 0;
			int removed = 0;
			while (i < line.length && removed < cols) {
				if (line[i] == '\t') {
					removed += TAB_DISPLAY_WIDTH;
					i++;
				} else if (line[i] == ' ') {
					removed++;
					i++;
				} else {
					break;
				}
			}
			return line.substring (i);
		}

		private static int measure_leading_columns (string line) {
			int cols = 0;
			for (int i = 0; i < line.length; i++) {
				if (line[i] == '\t') {
					cols += TAB_DISPLAY_WIDTH;
				} else if (line[i] == ' ') {
					cols++;
				} else {
					break;
				}
			}
			return cols;
		}

		public static string format_comment_lines (
				TreeSitter.Node node,
				string source,
				Config config,
				int target_indent
		) {
			string content = CstHelpers.node_text (node, source);
			string trimmed = content.strip ();
			if (trimmed.length == 0) {
				return "";
			}
			string indent_str = config.get_indent_string (target_indent);
			var sb = new StringBuilder ();
			if (!trimmed.has_prefix ("/*") && !trimmed.has_prefix ("//")) {
				sb.append (indent_str);
				sb.append ("// ");
				sb.append (trimmed);
				sb.append ("\n");
				return sb.str;
			}
			string[] lines = content.split ("\n");
			if (lines.length == 1) {
				sb.append (indent_str);
				sb.append (CstHelpers.normalize_comment_line (lines[0].strip ()));
				sb.append ("\n");
				return sb.str;
			}
			int min_non_star_indent = int.MAX;
			for (int i = 1; i < lines.length; i++) {
				string line_no_cr = lines[i].replace ("\r", "").chomp ();
				if (line_no_cr.strip ().length == 0) {
					continue;
				}
				string no_lead = strip_leading_whitespace (line_no_cr);
				if (no_lead.has_prefix ("*")) {
					continue;
				}
				int cols = measure_leading_columns (line_no_cr);
				if (cols < min_non_star_indent) {
					min_non_star_indent = cols;
				}
			}
			if (min_non_star_indent == int.MAX) {
				min_non_star_indent = 0;
			}
			for (int i = 0; i < lines.length; i++) {
				string line_no_cr = lines[i].replace ("\r", "").chomp ();
				if (i == 0) {
					sb.append (indent_str);
					sb.append (CstHelpers.normalize_comment_line (line_no_cr.strip ()));
					sb.append ("\n");
					continue;
				}
				if (line_no_cr.strip ().length == 0) {
					sb.append ("\n");
					continue;
				}
				string no_lead = strip_leading_whitespace (line_no_cr);
				if (no_lead.has_prefix ("*")) {
					sb.append (indent_str);
					sb.append (" ");
					sb.append (no_lead);
					sb.append ("\n");
				} else {
					sb.append (indent_str);
					sb.append (strip_prefix_columns (line_no_cr, min_non_star_indent));
					sb.append ("\n");
				}
			}
			return sb.str;
		}
	}
}
