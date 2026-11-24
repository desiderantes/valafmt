/* cst_type_formatter.vala
 *
 * Copyright (C) 2026 valafmt contributors
 *
 * CST formatting for Vala symbols, types, type arguments, array types, attributes, and modifiers.
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
	internal class CstTypeFormatter {
		public unowned CstLayoutContext ctx;
		public unowned CstPrettyPrinter printer;

		public CstTypeFormatter (CstLayoutContext ctx, CstPrettyPrinter printer) {
			this.ctx = ctx;
			this.printer = printer;
		}

		public string format_symbol (TreeSitter.Node node) {
			string k = ctx.kind (node);
			if (k == "identifier") {
				return CstHelpers.format_identifier (ctx.text (node));
			}
			if (k == "symbol") {
				var sb = new StringBuilder ();
				uint32 count = node.child_count;
				for (uint32 i = 0; i < count; i++) {
					TreeSitter.Node child = node.child (i);
					string ck = ctx.kind (child);
					if (ck == "symbol") {
						sb.append (format_symbol (child));
					} else if (ck == "identifier") {
						sb.append (CstHelpers.format_identifier (ctx.text (child)));
					} else {
						sb.append (ctx.text (child));
					}
				}
				return sb.str;
			}
			return ctx.text (node).strip ();
		}

		public string format_type_arguments (TreeSitter.Node node) {
			var sb = new StringBuilder ();
			sb.append ("<");
			bool first = true;
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "type") {
					if (!first) {
						sb.append (", ");
					}
					sb.append (format_type (child));
					first = false;
				}
			}
			sb.append (">");
			return sb.str;
		}

		public string format_unqualified_type (TreeSitter.Node node) {
			var sb = new StringBuilder ();
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "symbol") {
					sb.append (format_symbol (child));
				} else if (ck == "type_arguments") {
					sb.append (format_type_arguments (child));
				}
			}
			return sb.str;
		}

		public string format_array_type (TreeSitter.Node node) {
			var sb = new StringBuilder ();
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "[" || ck == "]" || ck == "?" || ck == ":" || ck == "," || ck == "(" || ck == ")") {
					sb.append (ck);
					if (ck == "," && i + 1 < count) {
						string next_k = ctx.kind (node.child (i + 1));
						if (next_k != "]" && next_k != ",") {
							sb.append (" ");
						}
					}
				} else if (ck == "type") {
					sb.append (format_type (child));
				} else if (child.is_named && ck != "comment") {
					sb.append (printer.print_node_inline (child));
				}
			}
			return sb.str;
		}

		public string format_type (TreeSitter.Node node) {
			var sb = new StringBuilder ();
			uint32 count = node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = node.child (i);
				string ck = ctx.kind (child);
				if (ck == "dynamic" || ck == "unowned" || ck == "owned" || ck == "weak") {
					sb.append (ck + " ");
				} else if (ck == "var" || ck == "void") {
					sb.append (ck);
				} else if (ck == "(") {
					sb.append ("(");
				} else if (ck == ")") {
					sb.append (")");
				} else if (ck == "type") {
					sb.append (format_type (child));
				} else if (ck == "symbol") {
					sb.append (format_symbol (child));
				} else if (ck == "type_arguments") {
					sb.append (format_type_arguments (child));
				} else if (ck == "*") {
					sb.append ("*");
				} else if (ck == "?") {
					sb.append ("?");
				} else if (ck == "array_type") {
					sb.append (format_array_type (child));
				}
			}
			return sb.str;
		}

		private void parse_attribute_argument (
				TreeSitter.Node arg_node,
				GenericArray<string> arg_keys,
				GLib.HashTable<string, string> arg_map
		) {
			string key = "";
			var val_tokens = new GenericArray<TreeSitter.Node?> ();
			bool after_eq = false;
			uint32 acount = arg_node.child_count;
			for (uint32 j = 0; j < acount; j++) {
				TreeSitter.Node ac = arg_node.child (j);
				string ack = ctx.kind (ac);
				if (ack == "identifier" && key == "") {
					key = ctx.text (ac);
				} else if (ack == "=") {
					after_eq = true;
				} else if (after_eq && (ack == "(" || ack == ")" || ack == "," || (ac.is_named && ack != "comment"))) {
					val_tokens.add (ac);
				}
			}
			if (key != "") {
				arg_keys.add (key);
				arg_map.insert (key, val_tokens.length > 0 ? printer.format_expression_tokens_inline (val_tokens) : "");
			}
		}

		public string format_single_attribute (TreeSitter.Node attr_node) {
			string attr_name = "";
			var arg_keys = new GenericArray<string> ();
			var arg_map = new GLib.HashTable<string, string> (GLib.str_hash, GLib.str_equal);
			bool has_parens = false;
			uint32 count = attr_node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = attr_node.child (i);
				string ck = ctx.kind (child);
				if (ck == "identifier" && attr_name == "") {
					attr_name = ctx.text (child);
				} else if (ck == "(") {
					has_parens = true;
				} else if (ck == "attribute_argument_list") {
					has_parens = true;
					uint32 lcount = child.child_count;
					for (uint32 j = 0; j < lcount; j++) {
						TreeSitter.Node ac = child.child (j);
						if (ctx.kind (ac) == "attribute_argument") {
							parse_attribute_argument (ac, arg_keys, arg_map);
						}
					}
				} else if (ck == "attribute_argument") {
					parse_attribute_argument (child, arg_keys, arg_map);
				}
			}
			var sb = new StringBuilder ();
			sb.append (attr_name);
			if (arg_keys.length > 0) {
				arg_keys.sort ((a, b) => strcmp (a, b));
				sb.append (" (");
				for (int k = 0; k < arg_keys.length; k++) {
					if (k > 0) {
						sb.append (", ");
					}
					string key = arg_keys.get (k);
					sb.append (key);
					sb.append (" = ");
					sb.append (arg_map.lookup (key));
				}
				sb.append (")");
			} else if (has_parens) {
				sb.append (" ()");
			}
			return sb.str;
		}

		public void collect_attributes_and_comments (TreeSitter.Node container, GenericArray<string> formatted_attrs) {
			bool in_attr_list = false;
			var current_group = new GenericArray<string> ();
			uint32 count = container.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = container.child (i);
				string ck = ctx.kind (child);
				if (ck == "comment") {
					ctx.emit_comment_node (child);
				} else if (ck == "[") {
					in_attr_list = true;
					current_group = new GenericArray<string> ();
				} else if (ck == "attribute" && in_attr_list) {
					current_group.add (format_single_attribute (child));
				} else if (ck == "]" && in_attr_list) {
					in_attr_list = false;
					var sb = new StringBuilder ("[");
					for (int a = 0; a < current_group.length; a++) {
						if (a > 0) {
							sb.append (", ");
						}
						sb.append (current_group.get (a));
					}
					sb.append ("]");
					formatted_attrs.add (sb.str);
				}
			}
		}

		public string format_modifiers (TreeSitter.Node decl_node) {
			string access = "";
			bool has_static = false;
			bool has_class_mod = false;
			bool has_extern = false;
			bool has_new = false;
			bool has_abstract = false;
			bool has_virtual = false;
			bool has_override = false;
			bool has_inline = false;
			bool has_async = false;
			bool has_compact = false;
			bool has_sealed = false;
			bool has_partial = false;
			uint32 count = decl_node.child_count;
			for (uint32 i = 0; i < count; i++) {
				TreeSitter.Node child = decl_node.child (i);
				string ck = ctx.kind (child);
				if (ck == "access_modifier") {
					access = ctx.text (child).strip ();
				} else if (ck == "type_declaration_modifier"
						|| ck == "member_declaration_modifier"
						|| ck == "delegate_declaration_modifier"
						|| ck == "signal_declaration_modifier"
						|| ck == "constructor_declaration_modifier") {
					string m = ctx.text (child).strip ();
					if (m == "public" || m == "protected" || m == "private" || m == "internal") {
						access = m;
					} else if (m == "static") {
						has_static = true;
					} else if (m == "class") {
						has_class_mod = true;
					} else if (m == "extern") {
						has_extern = true;
					} else if (m == "new") {
						has_new = true;
					} else if (m == "abstract") {
						has_abstract = true;
					} else if (m == "virtual") {
						has_virtual = true;
					} else if (m == "override") {
						has_override = true;
					} else if (m == "inline") {
						has_inline = true;
					} else if (m == "async") {
						has_async = true;
					} else if (m == "compact") {
						has_compact = true;
					} else if (m == "sealed") {
						has_sealed = true;
					} else if (m == "partial") {
						has_partial = true;
					}
				}
			}
			var sb = new StringBuilder ();
			if (access != "") {
				sb.append (access + " ");
			}
			if (has_static) {
				sb.append ("static ");
			}
			if (has_class_mod) {
				sb.append ("class ");
			}
			if (has_extern) {
				sb.append ("extern ");
			}
			if (has_new) {
				sb.append ("new ");
			}
			if (has_abstract) {
				sb.append ("abstract ");
			}
			if (has_virtual) {
				sb.append ("virtual ");
			}
			if (has_override) {
				sb.append ("override ");
			}
			if (has_inline) {
				sb.append ("inline ");
			}
			if (has_async) {
				sb.append ("async ");
			}
			if (has_compact) {
				sb.append ("compact ");
			}
			if (has_sealed) {
				sb.append ("sealed ");
			}
			if (has_partial) {
				sb.append ("partial ");
			}
			return sb.str;
		}
	}
}
