# valafmt Architecture

`valafmt` is an opinionated, zero-configuration CST-based code formatter and linter for **Vala**, built on top of
`tree-sitter-vala` Concrete Syntax Tree (CST) parsing, custom CST pretty-printing visitors, static analysis linting, and
multi-pass convergence. The architectural pipeline and fixed-point convergence model of `valafmt` are inspired by the
Prince of Space Java formatting engine.

---

## Table of Contents

- [Pipeline Overview](#pipeline-overview)
- [Component Breakdown](#component-breakdown)
- [File & Module Structure](#file--module-structure)
- [Zero-Configuration Model](#zero-configuration-model)
- [Static Analysis & Linting Architecture](#static-analysis--linting-architecture)
- [Testing Architecture](#testing-architecture)
- [Design Principles](#design-principles)

---

## Pipeline Overview

`valafmt` processes Vala source code through a 4-stage pipeline managed by `Valafmt.Engine`:

```text
         .vala source
              |
              v
  +------------------------+
  | 1. Parse               |  tree-sitter-vala CST
  +------------------------+
          |        |
 (format) |        +------------------------+ (--lint)
          v                                 v
  +------------------------+    +------------------------+
  | 2. CstPrettyPrinter    |    | 4. Linter              |
  |    layout + delegates  |    |    static analysis     |
  +------------------------+    +------------------------+
          |                                 |
          v                                 v
  +------------------------+           diagnostics
  | 3. Convergence loop    |
  |    + leaf safety check |
  +------------------------+
          |
          v
     formatted .vala
```

---

## Component Breakdown

### 1. Parsing (`tree-sitter-vala` CST)

The engine reads raw Vala source text and parses it into a Concrete Syntax Tree (`TreeSitter.Tree` / `TreeSitter.Node`)
using `tree-sitter-vala` without requiring external VAPI packages or cross-file semantic resolution. If
`root.has_error()` is true, execution halts early with a `FormattingError` to protect the user's source file.

### 2. Pretty-Printing Visitor (`Valafmt.CstPrettyPrinter`)

`Valafmt.CstPrettyPrinter` traverses CST nodes directly and emits formatted Vala source text according
to [RULES.md](RULES.md):

* **Forced Control Flow Braces:** Normalizes single-statement `if`, `else`, `for`, `foreach`, `while`, and `do` bodies
  into explicit `{ ... }` blocks.
* **Space before parenthesis:** Enforces `func (arg)` and `stdout.printf ("...")`.
* **K&R Brace placement:** `{` stays on the same line for namespaces, classes, methods, and blocks.
* **Cuddled control flow:** `} else {`, `} catch {`, and `} finally {` stay cuddled on closing brace lines.
* **Canonical Modifier Order:** Normalizes symbol declaration modifiers in
  `[accessibility] [member-type] [ownership] [type]` order.
* **Deterministic Attribute Formatting:** Sorts multi-argument attribute parameters alphabetically
  (`[CCode (array_length = false, array_null_terminated = true)]`) for 100% idempotent fixed-point formatting.
* **Faithful CST Preservation:** Preserves only the declarations and statements actually written in the source file (no
  synthetic default constructors or stripped unresolvable bodies), along with comments, preprocessor directives (`#if`,
  `#elif`, `#else`, `#endif`), and multiline verbatim strings (`"""..."""` / `@"""..."""`). Enforces blank-line
  boundaries (`no-padded-blocks`, `no-multiple-empty-lines`, `eol-last`) directly at emission time via
  `trim_trailing_blank_lines` and `finalize_document`.
* **Low-Overhead Delegate Architecture:** `CstPrettyPrinter`, `CstLayoutContext`, and the four delegate formatters
  (`CstTypeFormatter`, `CstDeclarationFormatter`, `CstStatementFormatter`, `CstExpressionFormatter`) are internal
  `[Compact]` classes with direct field access and `unowned` source slices. Speculative inline formatting
  (`print_node_inline`, `format_expression_tokens_inline`) re-entrantly swaps `CstLayoutContext`'s output buffer
  (`push_inline_buffer` / `pop_inline_buffer_stripped`) instead of allocating sub-printers.

### 3. Multi-Pass Convergence & Safety Net (`Valafmt.Engine`)

To guarantee strict idempotency (`format(format(x)) == format(x)`), `Valafmt.Engine` reuses a `TreeSitter.Parser` per
call and formats in a bounded convergence loop:

```text
pass 0 -> pass 1 -> ... -> pass N (until output(N) == output(N-1))
```

Once consecutive passes produce identical strings (the fixed point), the engine verifies that no semantic CST leaf
tokens were dropped between the input and output trees, then returns the formatted source (or throws
`FormattingError.NON_CONVERGENT`, mapped to exit code `3` by the CLI). A `format_single_pass` entry point is also
exposed for single-pass convergence verification in tests.

### 4. Static Analysis & Linting Visitor (`Valafmt.Linter`)

When invoked with `-l` / `--lint`, `Valafmt.Engine` runs `Valafmt.Linter`, a CST visitor that inspects declaration
identifiers, comments, semicolons, and template strings for compliance without mutating source code.

---

## File & Module Structure

All core implementation files reside in `src/`:

| File                                                                               | Class / Module                    | Purpose                                                                                                                                                                                                                                |
|:-----------------------------------------------------------------------------------|:----------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`src/main.vala`](src/main.vala)                                                   | `main()`                          | CLI entry point with `CliOptions` encapsulation, parallel `GLib.ThreadPool` multi-file execution, deterministic output ordering, and exit code `3` for `NON_CONVERGENT`.                                                               |
| [`src/config.vala.in`](src/config.vala.in)                                         | `Valafmt.VERSION`                 | Meson-configured version constant matching `meson.project_version()`.                                                                                                                                                                  |
| [`src/engine/config.vala`](src/engine/config.vala)                                 | `Valafmt.Config`                  | Public zero-configuration style constants (tabs, 120 display-column line length).                                                                                                                                                      |
| [`src/engine/formatting_engine.vala`](src/engine/formatting_engine.vala)           | `Valafmt.Engine`                  | Public API orchestrating the Tree-sitter CST pipeline, multi-pass convergence, `format_single_pass`, and semantic-leaf code-loss verification.                                                                                         |
| [`src/cst/cst_helpers.vala`](src/cst/cst_helpers.vala)                             | `Valafmt.CstHelpers`              | Internal CST node byte-slice helpers, Vala keyword escaping (`@`), and comment spacing normalization.                                                                                                                                  |
| [`src/cst/cst_comment_formatter.vala`](src/cst/cst_comment_formatter.vala)         | `Valafmt.CstCommentFormatter`     | Internal stateless comment formatting and block/Valadoc indentation preservation helpers.                                                                                                                                              |
| [`src/cst/cst_width_measurer.vala`](src/cst/cst_width_measurer.vala)               | `Valafmt.CstWidthMeasurer`        | Internal allocation-free UTF-8 display width and flat CST expression width estimator.                                                                                                                                                  |
| [`src/cst/cst_layout_context.vala`](src/cst/cst_layout_context.vala)               | `Valafmt.CstLayoutContext`        | Shared output buffer, indentation/column cursor, wrapped-list formatter, comment/directive emission, and document finalization helpers passed to all CST delegates.                                                                    |
| [`src/cst/cst_type_formatter.vala`](src/cst/cst_type_formatter.vala)               | `Valafmt.CstTypeFormatter`        | Internal delegate formatting Vala symbols, types, type arguments, array types, attributes, and canonical modifiers.                                                                                                                    |
| [`src/cst/cst_declaration_formatter.vala`](src/cst/cst_declaration_formatter.vala) | `Valafmt.CstDeclarationFormatter` | Internal delegate formatting Vala declaration nodes (namespaces, classes, interfaces, structs, enums, error domains, delegates, methods, signals, fields, constants, properties, constructors, destructors).                           |
| [`src/cst/cst_statement_formatter.vala`](src/cst/cst_statement_formatter.vala)     | `Valafmt.CstStatementFormatter`   | Internal delegate formatting Vala statement nodes (blocks, forced braces on control flow `if`, `while`, `for`, `foreach`, `do`, `switch`, `try`, `lock`, `with`, `return`, local declarations).                                        |
| [`src/cst/cst_expression_formatter.vala`](src/cst/cst_expression_formatter.vala)   | `Valafmt.CstExpressionFormatter`  | Internal delegate formatting Vala expression nodes (method calls, member access, object/array creation, initializers, lambdas, casts, binary/unary/ternary expressions, literals).                                                     |
| [`src/cst/cst_pretty_printer.vala`](src/cst/cst_pretty_printer.vala)               | `Valafmt.CstPrettyPrinter`        | Thin internal coordinator wiring `CstLayoutContext` and the four delegate formatters, plus top-level `visit_source_file` and inline measurement helpers.                                                                               |
| [`src/linter/linter.vala`](src/linter/linter.vala)                                 | `Valafmt.Linter`                  | CST visitor that checks code for naming convention compliance (`PascalCase`, `snake_case`, `ALL_CAPS_SNAKE`), `comment-spacing`, `no-valadoc-in-body`, `double-semicolon`, `unnecessary-string-template`, and `keyword-as-identifier`. |

---

## Zero-Configuration Model

`valafmt` enforces a single, unconfigurable code style as defined in `Valafmt.Config`:

| Property      | Value                           | Description                                                     |
|:--------------|:--------------------------------|:----------------------------------------------------------------|
| Indentation   | Tabs (`\t`)                     | One tab character per indentation level                         |
| `line_length` | `120`                           | Target maximum line width (in display columns) before wrapping  |
| Wrapping      | Narrow + closing `)` on newline | Canonical line wrapping for parameter/argument lists and chains |

---

## Static Analysis & Linting Architecture

`Valafmt.Linter` (`src/linter/linter.vala`) provides CST-based static analysis checks without mutating source code:

1. **Rule Classification**:
    - **`naming-convention`**:
        - **`PascalCase`**: Classes, Structs, Interfaces, Enums, Error Domains, Delegates, Namespaces.
        - **`snake_case`**: Methods, Fields, Properties, Signals, Parameters, Local Variables. Private field prefix `_`
          is permitted.
        - **`ALL_CAPS_SNAKE`**: Constants, Enum Values, Error Codes.
    - **`comment-spacing`**: Detects single-line comment markers missing a trailing space (`//comment` vs `// comment`).
    - **`no-valadoc-in-body`**: Detects Valadoc doc-comments (`/** ... */`) placed inside statement blocks or method
      bodies that cannot be exported to Valadoc API documentation.
    - **`double-semicolon`**: Detects redundant double semicolons (`;;`) in statements and declarations.
    - **`unnecessary-string-template`**: Detects redundant template string interpolations like `@"$(name)"` when a
      single variable reference can be used directly.
    - **`keyword-as-identifier`**: Detects unescaped Vala keywords used as identifiers without a leading `@` prefix.

2. **CST Traversal**:
    - Walks the `TreeSitter.Node` tree directly to inspect declarations, `block` nodes, `comment` nodes, and
      `template_string` nodes with 1-based line and column coordinates.

3. **Diagnostic Reporting**:
    - Emits structured compiler-style warnings (`file:line:col: warning: [rule-id] message`).
    - Skips file formatting and exits with status `1` when `--lint` detects any warnings.

---

## Testing Architecture

`valafmt` uses a Vala + GLib (`GLib.Test` / TAP) + Meson test framework where **each rule fixture and integration suite
is registered as a discrete Meson test target**:

```
test/
*  test_support.vala             # Shared Vala test helpers (subprocess runner, temp files, diff assertions)
*  check_golden.vala             # Single-fixture runner checking byte-for-byte output & idempotency
*  test_cli.vala                 # Integration test suite for CLI options and flags
*  test_linter.vala              # Integration test suite for --lint static analysis checks
*  test_regressions.vala         # Integration test suite for CST correctness & bug regressions
*  test_performance.vala         # Single-pass convergence & execution throughput benchmark
*  test_concurrency.vala         # Multi-thread parallel formatting concurrency suite
*  test_idempotency_sampler.vala # Sweeping idempotency sampler with diff diagnostics
*  test_comment_matrix.vala      # Comment preservation & comment-spacing linter matrix
*  meson.build                   # Meson test definitions (TAP protocol)
*  fixtures/                     # 38 atomic rule test fixtures (input.vala vs expected.vala)
```

---

## Design Principles

1. **Idempotency is Mandatory:** Running `valafmt` on code that is already formatted must produce 0 diffs
   (`format(format(x)) == format(x)`).
2. **Stand-Alone Single-File CST Parsing:** Uses `tree-sitter-vala` so individual `.vala` files format deterministically
   without needing project build graphs or external `.vapi` packages.
3. **Zero-Configuration Precision:** Eliminates style debates by enforcing a single canonical code style as defined
   in [RULES.md](RULES.md).
4. **Non-Destructive Linting:** Keeps formatting and linting decoupled—formatting changes layout safely while linting
   warns about naming conventions without breaking C symbol bindings or API contracts.
