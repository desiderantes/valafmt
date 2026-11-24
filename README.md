# valafmt

An opinionated, zero-configuration code formatter and linter for **Vala**, built on `tree-sitter-vala` Concrete Syntax
Tree (CST) visitors and multi-pass fixed-point convergence.

`valafmt` has **no style configuration knobs**. It enforces a single canonical code style defined
in [RULES.md](RULES.md).

---

## Canonical Formatting Rules

* **Indentation:** Hardcoded tab characters (`\t`).
* **Line Length Limit:** 120 characters maximum.
* **Idempotent Output:** Guaranteed fixed-point convergence (`format(format(code)) == format(code)`).
* **Forced Braces:** Wraps single-statement `if`, `else`, `for`, `foreach`, `while`, and `do` bodies in `{ ... }`.
* **K&R Braces & Cuddled Keywords:** `{` on same line; cuddled `} else {`, `} catch {`, and `} finally {`.
* **Vala Style Standards:** Space before function parenthesis (`func (arg)`).

---

## Building & Installation

### Dependencies

`valac` (0.56+), `gcc`, `git`, `pkg-config`, `nodejs`, `tree-sitter-cli`, `libtree-sitter-dev`, `libglib2.0-dev`,
`meson`, `ninja`.

### Build Commands

```bash
meson setup build
ninja -C build
meson test -C build
```

---

## Usage

```bash
# Format current directory in-place
valafmt

# Format specific file or directory
valafmt src/main.vala
valafmt --input-dir=src

# CI/CD check mode (exits 1 if unformatted)
valafmt --check

# Static analysis linter (exits 1 on warnings)
valafmt --lint

# Pipe from stdin to stdout
cat input.vala | valafmt --stdin
```

---

## CLI Options

| Option             | Flag      | Description                                                                                               |
|:-------------------|:----------|:----------------------------------------------------------------------------------------------------------|
| `--input-dir`      | `-i DIR`  | Directory to scan recursively for `.vala` files                                                           |
| `--output-dir`     | `-o DIR`  | Output directory preserving subpath hierarchy                                                             |
| `--output-file`    | `-f FILE` | Target output file (single input file only)                                                               |
| `--stdin`          | `-s`      | Read Vala source code from standard input                                                                 |
| `--stdin-filename` | —         | Virtual filename for diagnostics when reading from `--stdin`                                              |
| `--stdout`         | —         | Write output to stdout (single file or `--stdin` only)                                                    |
| `--check`          | `-c`      | Dry-run compliance check; exits `1` if unformatted                                                        |
| `--lint`           | `-l`      | Analysis linter (naming, comments, Valadoc, semicolons, templates, keywords); exits `1` if warnings found |
| `--version`        | `-v`      | Show version information                                                                                  |

---

## Documentation

* [RULES.md](RULES.md): Complete specification of all 42 Vala code style and lint rules and test fixtures.
* [ARCHITECTURE.md](ARCHITECTURE.md): Architectural design doc of the 4-stage pipeline engine.

---

## License

This program is free software: you can redistribute it and/or modify it under the terms of the [GNU General Public
License as published by the Free Software Foundation](COPYING), either version 3 of the License, or (at your option) any
later version.
