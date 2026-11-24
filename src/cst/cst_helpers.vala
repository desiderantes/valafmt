/* cst_helpers.vala
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
	internal class CstHelpers : GLib.Object {
		public static string node_text (TreeSitter.Node node, string source) {
			if (node.is_null) {
				return "";
			}
			uint32 start = node.start_byte;
			uint32 end = node.end_byte;
			if (start >= end || end > source.length) {
				return "";
			}
			return source.substring ((long) start, (long) (end - start));
		}

		public static string node_type (TreeSitter.Node node) {
			if (node.is_null) {
				return "";
			}
			unowned string? t = node.type;
			return t != null ? t : "";
		}

		private const string[] VALA_KEYWORDS = { "abstract", "as", "async", "base", "break", "case", "catch", "class", "const", "construct", "continue", "default", "delegate", "delete", "do", "dynamic", "else", "ensures", "enum", "errordomain", "extern", "false", "finally", "for", "foreach", "get", "global", "if", "in", "inline", "interface", "internal", "is", "lock", "namespace", "new", "null", "out", "override", "owned", "params", "private", "protected", "public", "ref", "requires", "return", "sealed", "set", "signal", "sizeof", "static", "struct", "switch", "this", "throw", "throws", "true", "try", "typeof", "unlock", "unowned", "using", "value", "var", "virtual", "void", "volatile", "weak", "while", "with", "yield" };
		public static bool is_vala_keyword (string word) {
			foreach (unowned string kw in VALA_KEYWORDS) {
				if (word == kw) {
					return true;
				}
			}
			return false;
		}

		public static bool is_contextual_keyword (string word) {
			return word == "get"
					|| word == "set"
					|| word == "construct"
					|| word == "default"
					|| word == "value";
		}

		public static string format_identifier (string? raw) {
			if (raw == null || raw.length == 0) {
				return "";
			}
			string s = raw.has_prefix ("@") ? raw.substring (1) : raw;
			if (is_contextual_keyword (s)) {
				return s;
			}
			if (is_vala_keyword (s) || s.get_char (0).isdigit ()) {
				return "@" + s;
			}
			return s;
		}

		public static string normalize_comment_line (string line) {
			string trimmed = line.strip ();
			if (trimmed.has_prefix ("//") && !trimmed.has_prefix ("///") && !trimmed.has_prefix ("// ")) {
				int idx = line.index_of ("//");
				if (idx >= 0 && idx + 2 < line.length && line[idx + 2] != '/' && line[idx + 2] != ' ') {
					return line.substring (0, idx + 2) + " " + line.substring (idx + 2);
				}
			}
			return line;
		}
	}
}
