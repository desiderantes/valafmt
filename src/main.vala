/* main.vala
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
using Valafmt;
namespace Valafmt {
	private class CliOptions : GLib.Object {
		public string? input_dir = null;
		public string? output_dir = null;
		public string? output_file = null;
		public string? stdin_filename = null;
		public bool use_stdin = false;
		public bool use_stdout = false;
		public bool check_only = false;
		public bool lint_only = false;
		public bool show_version = false;

		public OptionEntry[] build_entries () {
			return {
				{ "input-dir", 'i', 0, OptionArg.FILENAME, ref this.input_dir, "Directory to scan recursively for .vala files", "DIR" },
				{ "output-dir", 'o', 0, OptionArg.FILENAME, ref this.output_dir, "Directory to write formatted files into", "DIR" },
				{ "output-file", 'f', 0, OptionArg.FILENAME, ref this.output_file, "File to write formatted output into (single file only)", "FILE" },
				{ "stdin", 's', 0, OptionArg.NONE, ref this.use_stdin, "Read Vala source code from standard input", null },
				{ "stdin-filename", 0, 0, OptionArg.FILENAME, ref this.stdin_filename, "Virtual filename for diagnostics when reading from --stdin", "NAME" },
				{ "stdout", 0, 0, OptionArg.NONE, ref this.use_stdout, "Write output to stdout (single file or --stdin only)", null },
				{ "check", 'c', 0, OptionArg.NONE, ref this.check_only, "Check if files are formatted (exits 1 if unformatted)", null },
				{ "lint", 'l', 0, OptionArg.NONE, ref this.lint_only, "Lint files for naming conventions and code quality", null },
				{ "version", 'v', 0, OptionArg.NONE, ref this.show_version, "Show version information", null },
				{ null }
			};
		}
	}

	private class FileJob : GLib.Object {
		public string file_path;
		public string stdout_text = "";
		public string stderr_text = "";
		public bool failed = false;
		public bool non_convergent = false;

		public FileJob (string file_path) {
			this.file_path = file_path;
		}
	}

	private static bool is_ignored_dir (string name) {
		return name.has_prefix (".")
				|| name == "build"
				|| name == "_build"
				|| name == "build-dir"
				|| name == "buildDir"
				|| name == "node_modules"
				|| name == "subprojects"
				|| name == "flatpak-builder";
	}

	private static void add_unique_file (GenericArray<string> result, HashTable<string, bool> seen, string file_path) {
		string key = normalize_rel_path (file_path);
		if (!seen.contains (key)) {
			seen.insert (key, true);
			result.add (file_path);
		}
	}

	private static void scan_directory (string dir_path, GenericArray<string> result, HashTable<string, bool> seen) {
		try {
			var dir = Dir.open (dir_path);
			string? name = null;
			while ((name = dir.read_name ()) != null) {
				string full_path = Path.build_filename (dir_path, name);
				if (FileUtils.test (full_path, FileTest.IS_SYMLINK)) {
					continue;
				}
				if (FileUtils.test (full_path, FileTest.IS_DIR)) {
					if (!is_ignored_dir (name)) {
						scan_directory (full_path, result, seen);
					}
				} else if (name.has_suffix (".vala")) {
					add_unique_file (result, seen, full_path);
				}
			}
		} catch (Error e) {
			stderr.printf ("valafmt: Warning scanning directory %s: %s\n", dir_path, e.message);
		}
	}

	private static string normalize_rel_path (string path) {
		string p = path;
		while (p.has_prefix ("./")) {
			p = p.substring (2);
		}
		while (p.length > 1 && p.has_suffix (Path.DIR_SEPARATOR_S)) {
			p = p.substring (0, p.length - 1);
		}
		return p.length == 0 ? "." : p;
	}

	private static string get_relative_subpath (string base_dir, string file_path) {
		string norm_base = normalize_rel_path (base_dir);
		string norm_file = normalize_rel_path (file_path);
		if (norm_base == "." && !Path.is_absolute (norm_file) && !norm_file.has_prefix ("..")) {
			return norm_file;
		}
		if (norm_file.has_prefix (norm_base + Path.DIR_SEPARATOR_S)) {
			return norm_file.substring (norm_base.length + 1);
		}
		return Path.get_basename (norm_file);
	}

	private static string resolve_symlink_target (string path) throws FileError {
		string current = path;
		for (int hops = 0; hops < 40; hops++) {
			if (!FileUtils.test (current, FileTest.IS_SYMLINK)) {
				return current;
			}
			string target = FileUtils.read_link (current);
			if (Path.is_absolute (target)) {
				current = target;
			} else {
				current = Path.build_filename (Path.get_dirname (current), target);
			}
		}
		throw new FileError.LOOP ("Too many levels of symbolic links: %s", path);
	}

	private static void warn_ignored_output_options (CliOptions opts, string mode_flag) {
		if (opts.output_file != null) {
			stderr.printf ("valafmt: Warning: Output option '--output-file' is ignored in %s mode.\n", mode_flag);
		}
		if (opts.output_dir != null) {
			stderr.printf ("valafmt: Warning: Output option '--output-dir' is ignored in %s mode.\n", mode_flag);
		}
		if (opts.use_stdout) {
			stderr.printf ("valafmt: Warning: Output option '--stdout' is ignored in %s mode.\n", mode_flag);
		}
	}

	private static bool validate_output_destinations (CliOptions opts) {
		if (opts.output_file != null && opts.output_dir != null) {
			stderr.printf ("valafmt: Error: --output-file and --output-dir are mutually exclusive.\n");
			return false;
		}
		if (opts.use_stdout && opts.output_file != null) {
			stderr.printf ("valafmt: Error: --stdout and --output-file are mutually exclusive.\n");
			return false;
		}
		if (opts.use_stdout && opts.output_dir != null) {
			stderr.printf ("valafmt: Error: --stdout and --output-dir are mutually exclusive.\n");
			return false;
		}
		return true;
	}

	private static int run_stdin_mode (Engine engine, CliOptions opts) {
		if (opts.lint_only) {
			warn_ignored_output_options (opts, "--lint");
		} else if (opts.check_only) {
			warn_ignored_output_options (opts, "--check");
		} else {
			if (opts.output_dir != null) {
				stderr.printf ("valafmt: Error: --output-dir cannot be used with --stdin.\n");
				return 1;
			}
			if (!validate_output_destinations (opts)) {
				return 1;
			}
		}
		var builder = new StringBuilder ();
		char[] buf = new char[4096];
		while (stdin.gets (buf) != null) {
			builder.append ((string) buf);
		}
		string virtual_name = (opts.stdin_filename != null && opts.stdin_filename.length > 0) ? opts.stdin_filename : "stdin.vala";
		try {
			if (opts.lint_only) {
				var diagnostics = engine.lint (builder.str, virtual_name);
				for (int d = 0; d < diagnostics.length; d++) {
					var diag = diagnostics.get (d);
					stdout.printf ("%s\n", diag.to_string ());
				}
				return diagnostics.length > 0 ? 1 : 0;
			}
			string formatted = engine.format (builder.str, virtual_name);
			if (opts.check_only) {
				if (builder.str != formatted) {
					string label = (opts.stdin_filename != null && opts.stdin_filename.length > 0) ? opts.stdin_filename : "stdin";
					stdout.printf ("Unformatted: %s\n", label);
					return 1;
				}
				return 0;
			}
			if (opts.output_file != null && opts.output_file != "-") {
				string target_dir = Path.get_dirname (opts.output_file);
				if (target_dir.length > 0 && target_dir != ".") {
					DirUtils.create_with_parents (target_dir, 0755);
				}
				FileUtils.set_contents (opts.output_file, formatted);
			} else {
				stdout.printf ("%s", formatted);
			}
			return 0;
		} catch (Error e) {
			stderr.printf ("valafmt: %s\n", e.message);
			if (e is FormattingError.NON_CONVERGENT) {
				return 3;
			}
			return 1;
		}
	}

	private static void process_file_job (
			FileJob job,
			Engine engine,
			CliOptions opts,
			string base_scan_dir,
			int total_files
	) {
		string file_path = job.file_path;
		try {
			string content;
			FileUtils.get_contents (file_path, out content);
			if (opts.lint_only) {
				var diagnostics = engine.lint (content, file_path);
				if (diagnostics.length > 0) {
					job.failed = true;
					var out_sb = new StringBuilder ();
					for (int d = 0; d < diagnostics.length; d++) {
						out_sb.append (diagnostics.get (d).to_string ());
						out_sb.append_c ('\n');
					}
					job.stdout_text = out_sb.str;
				}
				return;
			}
			string formatted = engine.format (content, file_path);
			if (opts.check_only) {
				if (content != formatted) {
					job.stdout_text = "Unformatted: %s\n".printf (file_path);
					job.failed = true;
				}
				return;
			}
			if (opts.use_stdout || (opts.output_file != null
					&& total_files == 1
					&& !opts.use_stdout
					&& opts.output_file == "-")) {
				job.stdout_text = formatted;
			} else if (opts.output_file != null) {
				string target_dir = Path.get_dirname (opts.output_file);
				if (target_dir.length > 0 && target_dir != ".") {
					DirUtils.create_with_parents (target_dir, 0755);
				}
				FileUtils.set_contents (opts.output_file, formatted);
				job.stdout_text = "Formatted %s -> %s\n".printf (file_path, opts.output_file);
			} else if (opts.output_dir != null) {
				string rel_path = get_relative_subpath (base_scan_dir, file_path);
				string target_path = Path.build_filename (opts.output_dir, rel_path);
				string target_parent = Path.get_dirname (target_path);
				if (target_parent.length > 0 && target_parent != ".") {
					DirUtils.create_with_parents (target_parent, 0755);
				}
				FileUtils.set_contents (target_path, formatted);
				job.stdout_text = "Formatted %s -> %s\n".printf (file_path, target_path);
			} else {
				// Default: In-place formatting (preserve symlinks by writing to target)
				if (content != formatted) {
					string write_target = resolve_symlink_target (file_path);
					FileUtils.set_contents (write_target, formatted);
					job.stdout_text = "Formatted: %s\n".printf (file_path);
				}
			}
		} catch (Error e) {
			job.stderr_text = "valafmt: Error processing %s: %s\n".printf (file_path, e.message);
			job.failed = true;
			if (e is FormattingError.NON_CONVERGENT) {
				job.non_convergent = true;
			}
		}
	}

	public static int main (string[] args) {
		Intl.setlocale (LocaleCategory.ALL, "");
		var opts = new CliOptions ();
		var context = new OptionContext ("[PATH...]");
		context.set_help_enabled (true);
		context.add_main_entries (opts.build_entries (), null);
		context.set_summary ("valafmt — Zero-configuration opinionated code formatter for Vala");
		try {
			context.parse (ref args);
		} catch (OptionError e) {
			stderr.printf ("valafmt: %s\n", e.message);
			stderr.printf ("Run '%s --help' to see full usage.\n", args[0]);
			return 1;
		}
		if (opts.show_version) {
			stdout.printf ("valafmt %s\n", Valafmt.VERSION);
			return 0;
		}
		if (opts.check_only && opts.lint_only) {
			stderr.printf ("valafmt: Error: --check and --lint are mutually exclusive.\n");
			return 1;
		}
		int dash_count = 0;
		int non_dash_args = 0;
		for (int i = 1; i < args.length; i++) {
			if (args[i] == "-") {
				dash_count++;
			} else {
				non_dash_args++;
			}
		}
		bool stdin_mode = opts.use_stdin || dash_count > 0;
		if (stdin_mode) {
			if (opts.input_dir != null) {
				stderr.printf ("valafmt: Error: --stdin cannot be used with --input-dir.\n");
				return 1;
			}
			if (non_dash_args > 0 || dash_count > 1) {
				stderr.printf ("valafmt: Error: --stdin cannot be used with positional file/directory arguments.\n");
				return 1;
			}
		} else if (opts.stdin_filename != null) {
			stderr.printf ("valafmt: Error: --stdin-filename can only be used with --stdin.\n");
			return 1;
		}
		var config = Config.get_default ();
		var engine = new Engine (config);
		// Mode 1: Standard Input (--stdin)
		if (stdin_mode) {
			return run_stdin_mode (engine, opts);
		}
		// Collect target files
		var input_files = new GenericArray<string> ();
		var seen_inputs = new HashTable<string, bool> (str_hash, str_equal);
		string base_scan_dir = opts.input_dir != null ? opts.input_dir : ".";
		if (opts.input_dir != null) {
			if (!FileUtils.test (opts.input_dir, FileTest.IS_DIR)) {
				stderr.printf (
						"valafmt: Error: --input-dir '%s' does not exist or is not a directory.\n",
						opts.input_dir
				);
				return 1;
			}
			scan_directory (opts.input_dir, input_files, seen_inputs);
		}
		if (args.length > 1) {
			for (int i = 1; i < args.length; i++) {
				string arg = args[i];
				if (FileUtils.test (arg, FileTest.IS_DIR)) {
					scan_directory (arg, input_files, seen_inputs);
				} else {
					add_unique_file (input_files, seen_inputs, arg);
				}
			}
		} else if (opts.input_dir == null) {
			scan_directory (base_scan_dir, input_files, seen_inputs);
		}
		if (input_files.length == 0) {
			stderr.printf ("valafmt: No .vala files found to format.\n");
			return 0;
		}
		// Flag Validation
		if (opts.lint_only) {
			warn_ignored_output_options (opts, "--lint");
		} else if (opts.check_only) {
			warn_ignored_output_options (opts, "--check");
		} else {
			if (!validate_output_destinations (opts)) {
				return 1;
			}
			if (opts.output_file != null && input_files.length > 1) {
				stderr.printf ("valafmt: Error: --output-file can only be used when formatting a single file.\n");
				return 1;
			}
			if (opts.use_stdout && input_files.length > 1) {
				stderr.printf ("valafmt: Error: --stdout can only be used with a single input file or --stdin.\n");
				return 1;
			}
			if (opts.output_dir != null && input_files.length > 1) {
				var seen_targets = new HashTable<string, bool> (str_hash, str_equal);
				for (int i = 0; i < input_files.length; i++) {
					string rel_path = get_relative_subpath (base_scan_dir, input_files[i]);
					string target_path = Path.build_filename (opts.output_dir, rel_path);
					if (seen_targets.contains (target_path)) {
						stderr.printf ("valafmt: Error: --output-dir target collision on '%s'.\n", target_path);
						return 1;
					}
					seen_targets.insert (target_path, true);
				}
			}
		}
		int total_files = (int) input_files.length;
		var jobs = new FileJob[total_files];
		for (int i = 0; i < total_files; i++) {
			jobs[i] = new FileJob (input_files[i]);
		}
		if (total_files == 1) {
			process_file_job (jobs[0], engine, opts, base_scan_dir, total_files);
		} else {
			int max_threads = (int) GLib.get_num_processors ();
			if (max_threads < 1) {
				max_threads = 1;
			}
			if (max_threads > total_files) {
				max_threads = total_files;
			}
			try {
				var pool = new ThreadPool<FileJob>.with_owned_data (
						(job) => {
							process_file_job (job, engine, opts, base_scan_dir, total_files);
						},
						max_threads,
						false
				);
				for (int i = 0; i < total_files; i++) {
					pool.add (jobs[i]);
				}
				ThreadPool.free ((owned) pool, false, true);
			} catch (ThreadError e) {
				// Fallback to sequential processing if ThreadPool creation fails
				for (int i = 0; i < total_files; i++) {
					process_file_job (jobs[i], engine, opts, base_scan_dir, total_files);
				}
			}
		}
		bool has_failures = false;
		bool has_non_convergent = false;
		for (int i = 0; i < total_files; i++) {
			if (jobs[i].stdout_text.length > 0) {
				stdout.printf ("%s", jobs[i].stdout_text);
			}
			if (jobs[i].stderr_text.length > 0) {
				stderr.printf ("%s", jobs[i].stderr_text);
			}
			if (jobs[i].failed) {
				has_failures = true;
			}
			if (jobs[i].non_convergent) {
				has_non_convergent = true;
			}
		}
		if (has_non_convergent) {
			return 3;
		}
		return has_failures ? 1 : 0;
	}
}
