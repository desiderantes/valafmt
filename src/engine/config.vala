/* config.vala
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
namespace Valafmt {
	public class Config : GLib.Object {
		public int line_length { get; default = 120; }
		public string get_indent_string (int level) {
			if (level <= 0) {
				return "";
			}
			var builder = new StringBuilder ();
			for (int i = 0; i < level; i++) {
				builder.append ("\t");
			}
			return builder.str;
		}

		public static Config get_default () {
			return new Config ();
		}
	}
}
