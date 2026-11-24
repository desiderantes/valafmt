# Valafmt Code Style Rules

This document outlines the canonical code style rules for **Vala**, enforced by `valafmt`.

`valafmt` is an **opinionated, zero-configuration code formatter**. It enforces a single, deterministic code style
across all Vala projects:

* **Indentation:** Tab characters (`\t`).
* **Line Width:** 120 characters maximum.
* **Brace Placement:** K&R style (`{` on same line).
* **Control Flow Bodies:** Forced braces around all `if`, `else`, `for`, `foreach`, `while`, and `do` bodies.
* **Cuddled Control Flow:** `} else {`, `} catch (Error e) {`, and `} finally {` on closing brace lines.
* **Function Invocations:** Space before parenthesis: `func (arg)`.
* **Idempotency:** Re-formatting compliant code produces 0 diffs (`format(format(code)) == format(code)`).

---

## Rule Registry & Test Matrix

Each rule has a formal **Rule ID** (used in tests, URLs, and redirection slugs) and a human-readable **Rule Name**:

| Rule ID                                                       | Rule Name                                       | Category          | Test Fixture                                 |
|:--------------------------------------------------------------|:------------------------------------------------|:------------------|:---------------------------------------------|
| [`indent`](#indent)                                           | Use Tabs for Indentation                        | Indentation       | `tests/fixtures/indent`                      |
| [`max-len`](#max-len)                                         | Fixed Line Length Limit (120 Chars)             | Line Layout       | `tests/fixtures/max_len`                     |
| [`no-trailing-spaces`](#no-trailing-spaces)                   | No Trailing Whitespace                          | Line Layout       | `tests/fixtures/no_trailing_spaces`          |
| [`eol-last`](#eol-last)                                       | File Single Ending Newline                      | Line Layout       | `tests/fixtures/eol_last`                    |
| [`no-multiple-empty-lines`](#no-multiple-empty-lines)         | No Multiple Blank Lines                         | Line Layout       | `tests/fixtures/no_multiple_empty_lines`     |
| [`continuation-indent`](#continuation-indent)                 | Continuation Indentation                        | Line Layout       | `tests/fixtures/continuation_indent`         |
| [`brace-style`](#brace-style)                                 | K&R Opening Brace Placement                     | Braces            | `tests/fixtures/brace_style`                 |
| [`cuddled-else-catch`](#cuddled-else-catch)                   | Cuddled Control Flow Braces                     | Braces            | `tests/fixtures/cuddled_else_catch`          |
| [`space-before-blocks`](#space-before-blocks)                 | Space Before Opening Brace                      | Braces            | `tests/fixtures/space_before_blocks`         |
| [`no-padded-blocks`](#no-padded-blocks)                       | No Blank Lines Inside Blocks                    | Braces            | `tests/fixtures/no_padded_blocks`            |
| [`curly`](#curly)                                             | Forced Control Flow Braces                      | Control Flow      | `tests/fixtures/curly`                       |
| [`space-keyword`](#space-keyword)                             | Space After Control Keywords                    | Control Flow      | `tests/fixtures/space_keyword`               |
| [`switch-case-indent`](#switch-case-indent)                   | Switch Statement Indentation                    | Control Flow      | `tests/fixtures/switch_case_indent`          |
| [`try-catch`](#try-catch)                                     | Try / Catch / Finally Block Layout              | Control Flow      | `tests/fixtures/try_catch`                   |
| [`space-before-function-paren`](#space-before-function-paren) | Space Before Function Parenthesis               | Functions         | `tests/fixtures/space_before_function_paren` |
| [`no-spaces-inside-paren`](#no-spaces-inside-paren)           | No Spaces Inside Parentheses                    | Functions         | `tests/fixtures/no_spaces_inside_paren`      |
| [`comma-spacing`](#comma-spacing)                             | Space After Commas                              | Functions         | `tests/fixtures/comma_spacing`               |
| [`closing-paren-newline`](#closing-paren-newline)             | Multi-Line Parameter Closing Parenthesis        | Functions         | `tests/fixtures/closing_paren_newline`       |
| [`trailing-lambda-layout`](#trailing-lambda-layout)           | Trailing-Lambda Layout in Calls                 | Functions         | `tests/test_regressions.vala`                |
| [`method-chain-newline`](#method-chain-newline)               | Multi-Line Method Chaining                      | Chaining          | `tests/fixtures/method_chain_newline`        |
| [`semi`](#semi)                                               | Always Semicolon Terminated                     | Declarations      | `tests/fixtures/semi`                        |
| [`one-var-per-declaration`](#one-var-per-declaration)         | Single Variable per Statement                   | Declarations      | `tests/fixtures/one_var_per_declaration`     |
| [`type-clause-wrap`](#type-clause-wrap)                       | Base Class & Interface List Wrap                | Declarations      | `tests/fixtures/type_clause_wrap`            |
| [`space-infix-ops`](#space-infix-ops)                         | Spaces Around Infix Operators                   | Operators         | `tests/fixtures/space_infix_ops`             |
| [`operator-linebreak`](#operator-linebreak)                   | Leading Operators on Wrapped Binary Expressions | Operators         | `tests/test_regressions.vala`                |
| [`space-unary-ops`](#space-unary-ops)                         | No Space Before Unary Operands                  | Operators         | `tests/fixtures/space_unary_ops`             |
| [`cast-spacing`](#cast-spacing)                               | Space After Cast Target or As                   | Operators         | `tests/fixtures/cast_spacing`                |
| [`owned-unowned-space`](#owned-unowned-space)                 | Space After Owned / Unowned                     | Operators         | `tests/fixtures/owned_unowned_space`         |
| [`initializer-wrap`](#initializer-wrap)                       | Multi-Line Array & Struct Initializer Tables    | Expressions       | `tests/test_regressions.vala`                |
| [`property-body-newline`](#property-body-newline)             | Multi-Line Property Accessor Bodies             | Features          | `tests/fixtures/property_body_newline`       |
| [`object-property-newline`](#object-property-newline)         | Construct Property Initializers                 | Objects           | `tests/fixtures/object_property_newline`     |
| [`nullable-type-spacing`](#nullable-type-spacing)             | No Space Before Nullable Indicator              | Features          | `tests/fixtures/nullable_type_spacing`       |
| [`enum-value-newline`](#enum-value-newline)                   | Enum Member Newlines                            | Features          | `tests/fixtures/enum_value_newline`          |
| [`attribute-placement`](#attribute-placement)                 | Attribute Placement                             | Features          | `tests/fixtures/attribute_placement`         |
| [`throws-space`](#throws-space)                               | Space Before Throws Clause                      | Errors            | `tests/fixtures/throws_space`                |
| [`modifier-order`](#modifier-order)                           | Canonical Symbol Modifier Order                 | Declarations      | `tests/fixtures/modifier_order`              |
| [`comment-spacing`](#comment-spacing)                         | Space After Comment Markers (`// ...`)          | Comments          | `tests/test_linter.vala`                     |
| [`no-valadoc-in-body`](#no-valadoc-in-body)                   | No Valadoc in Method Bodies / Blocks            | Linter (`--lint`) | `tests/test_linter.vala`                     |
| [`naming-convention`](#naming-convention)                     | Standard Vala Naming Conventions                | Linter (`--lint`) | `tests/test_linter.vala`                     |
| [`double-semicolon`](#double-semicolon)                       | No Double Semicolons                            | Linter (`--lint`) | `tests/test_linter.vala`                     |
| [`unnecessary-string-template`](#unnecessary-string-template) | No Redundant String Template Interpolation      | Linter (`--lint`) | `tests/test_linter.vala`                     |
| [`keyword-as-identifier`](#keyword-as-identifier)             | Disallow Unescaped Keywords as Identifiers      | Linter (`--lint`) | `tests/test_linter.vala`                     |

---

## Table of Contents

- [Indentation & Line Layout](#indentation--line-layout)
- [Brace Placement & Block Formatting](#brace-placement--block-formatting)
- [Function & Method Formatting](#function--method-formatting)
- [Control Flow](#control-flow)
- [Variables & Declarations](#variables--declarations)
- [Naming Conventions](#naming-conventions)
- [Strings & Character Literals](#strings--character-literals)
- [Operators & Spacing](#operators--spacing)
- [Object-Oriented & Vala Features](#object-oriented--vala-features)
- [Error Handling](#error-handling)
- [Comments & Documentation](#comments--documentation)

---

## Indentation & Line Layout

* **Formatter output is idempotent.** Running `valafmt` on code that is already formatted produces identical output
  (`format(format(code)) == format(code)`). The formatting engine converges to a stable fixed point so that
  re-formatting compliant code leaves it completely unchanged.

### <a id="indent"></a>Use Tabs (`\t`) for Indentation

* Tabs are standard in the Vala compiler (`valac`) codebase and traditional GNOME core projects.

```vala
// ✓ ok (tabs)
public void hello (string name) {
    stdout.printf ("hi, %s\n", name);
}

// ✗ avoid (spaces)
public void hello (string name) {
    stdout.printf ("hi, %s\n", name);
}
```

### <a id="no-trailing-spaces"></a>No Trailing Whitespace

* Remove trailing spaces at the end of lines.

```vala
int x = 42;<space> // ✗ avoid
int x = 42;        // ✓ ok
```

### <a id="eol-last"></a>Single Ending Newline

* Files must end with a single newline character.

### <a id="no-multiple-empty-lines"></a>No Multiple Empty Lines

* Avoid consecutive blank lines inside code blocks (multiple consecutive blank lines collapse to at most one).

```vala
// ✓ ok
var value = "hello";

stdout.printf (value);

// ✗ avoid
var value = "hello";


stdout.printf (value);
```

### <a id="max-len"></a>Fixed Line Length Limit (120 Chars)

* Code lines should stay within 120 characters. When a statement exceeds this width, parameters and expressions wrap
  across continuation lines.

### <a id="continuation-indent"></a>Continuation Indentation

* Wrapped statement continuation lines are indented by 2 tab steps relative to the enclosing block indent.

```vala
// ✓ ok (continuation indent with tabs)
public void process_data (
        string first_param,
        string second_param
) {
    do_something ();
}
```

---

## Brace Placement & Block Formatting

### <a id="brace-style"></a>K&R Opening Brace Placement

* Opening braces `{` stay on the same line for namespaces, classes, structs, interfaces, enums, methods, functions, and
  control structures.

```vala
// ✓ ok
public class Greeter : Object {
    public void greet () {
        if (condition) {
        // ...
        }
    }
}

// ✗ avoid (Allman style)
public class Greeter : Object {
    public void greet ()
    {
        if (condition)
        {
        // ...
        }
    }
}
```

### <a id="cuddled-else-catch"></a>Cuddled Control Flow Braces

* Keep `else`, `catch`, and `finally` on the same line as closing braces (Cuddled style).

```vala
// ✓ ok
if (condition) {
    do_something ();
} else {
    do_other ();
}

// ✗ avoid (Uncuddled style)
if (condition) {
    do_something ();
}
else {
    do_other ();
}
```

### <a id="space-before-blocks"></a>Space Before Opening Brace

* Must have a space before opening brace `{`.

```vala
if (admin) { ... }  // ✓ ok
if (admin){ ... }   // ✗ avoid
```

### <a id="no-padded-blocks"></a>No Blank Lines Inside Blocks

* No blank padding lines immediately inside blocks.

```vala
// ✓ ok
if (user != null) {
    process (user);
}

// ✗ avoid
if (user != null) {

    process (user);

}
```

---

## Function & Method Formatting

### <a id="space-before-function-paren"></a>Space Before Function Parenthesis

* Add a space before parentheses in function & method invocations and declarations.

```vala
stdout.printf ("hello\n");                       // ✓ ok
public void calculate_total (int count) { ... } // ✓ ok

stdout.printf("hello\n");                        // ✗ avoid
public void calculate_total(int count) { ... }   // ✗ avoid
```

### <a id="no-spaces-inside-paren"></a>No Spaces Inside Parentheses

* No spaces directly inside parentheses.

```vala
get_name (name);    // ✓ ok
get_name ( name );  // ✗ avoid
```

### <a id="comma-spacing"></a>Space After Commas

* Commas must have a space after them, and no space before.

```vala
var list = new int[] { 1, 2, 3 };                     // ✓ ok
public void greet (string first, string last) { ... } // ✓ ok

var list = new int[] { 1, 2, 3 };                       // ✗ avoid
public void greet (string first, string last) { ... } // ✗ avoid
```

### <a id="closing-paren-newline"></a>Multi-Line Parameter Closing Parenthesis

* When arguments or parameters wrap across multiple lines, the closing parenthesis `)` is placed on its own line aligned
  with the declaration/call indentation.

```vala
// ✓ ok
do_something (
        first_arg,
        second_arg
);
```

### <a id="trailing-lambda-layout"></a>Trailing-Lambda Layout in Calls

* When the last argument of a method invocation is a lambda expression with a block body, the call line and the lambda
  header stay together on the invocation line.
* The closing parenthesis `)` attaches directly to the closing brace `}` (`});`) rather than dangling on a lonely
  continuation line, regardless of `closing-paren-newline`.

```vala
// ✓ ok
button.clicked.connect (() => {
    handle_click ();
});

button.connect_signals ("clicked", (s) => {
    do_work ();
});
```

### <a id="method-chain-newline"></a>Multi-Line Method Chaining

* When a chain of method invocations wraps, each chained `.method ()` starts on a new line with a leading dot, indented
  by 1 tab step.

```vala
// ✓ ok
var result = items
.filter ((item) => item.is_active ())
.map ((item) => item.get_name ())
.collect ();
```

---

## Control Flow

### <a id="curly"></a>Forced Control Flow Braces

* Braces are strictly required for all `if`, `else`, `for`, `foreach`, `while`, and `do` bodies—even for
  single-statement bodies.

```vala
// ✓ ok
if (quiet != true) {
    stdout.printf ("done\n");
}

// ✗ avoid (unbraced inline statement)
if (quiet != true) stdout.printf ("done\n");
```

### <a id="space-keyword"></a>Space After Control Keywords

* Add a space after control keywords (`if`, `for`, `foreach`, `while`, `do`, `switch`, `lock`).

```vala
if (condition) { ... }       // ✓ ok
foreach (var item in list) { // ✓ ok

if(condition) { ... }        // ✗ avoid
```

### <a id="switch-case-indent"></a>Switch Statement Indentation

* Indent `case` and `default` statements inside `switch` blocks.

```vala
switch (state) {
    case State.START:
        do_start ();
        break;
    case State.STOP:
        do_stop ();
        break;
}
```

### <a id="try-catch"></a>Try / Catch / Finally Block Layout

* Format `try`, `catch`, and `finally` blocks cleanly with cuddled braces.

```vala
// ✓ ok
try {
    read_file ();
} catch (Error e) {
    stderr.printf ("Error: %s\n", e.message);
} finally {
    cleanup ();
}
```

---

## Variables & Declarations

### <a id="semi"></a>Always Semicolon Terminated

* Always end statements with a semicolon `;`.

```vala
int x = 42; // ✓ ok
int x = 42  // ✗ avoid
```

### <a id="one-var-per-declaration"></a>Single Variable per Statement

* Write each variable declaration in its own statement.

```vala
// ✓ ok
int silent = 1;
int verbose = 1;

// ✗ avoid
int silent = 1, verbose = 1;
```

### <a id="type-clause-wrap"></a>Base Class & Interface List Wrap

* Long base class or interface implementation lists wrap across multiple lines with 2 tab steps continuation indent.

```vala
// ✓ ok
public class CustomWindow : Gtk.ApplicationWindow,
Gtk.Buildable,
Gtk.Orientable {
}
```

### <a id="modifier-order"></a>Canonical Symbol Modifier Order (`modifier-order`)

* Enforce canonical modifier order across all symbol declarations (`class`, `interface`, `struct`, `method`, `field`,
  `property`, `delegate`):
    1. Accessibility: `public` | `protected` | `private` | `internal`
    2. Member/Dispatch: `static` | `class` | `extern` | `new` | `abstract` | `virtual` | `override` | `inline` |
       `async` | `compact` | `sealed` | `partial`
    3. Ownership: `unowned` | `weak`

```vala
// ✓ ok
public abstract class Controller<T> {
    public static unowned string get_tag () {
        return "tag";
    }

    public override async void run_task () {
    }
}

// ✗ avoid (non-canonical modifier order)
abstract public class Controller<T> {
public async override void run_task () {
}
}
```

---

## Naming Conventions

### <a id="naming-convention"></a>Standard Vala Naming Conventions (`naming-convention`)

* Use `snake_case` for variables, fields, parameters, methods, signals, and properties.
* Prefix private backing fields with an underscore `_`.
* Use `PascalCase` (CamelCase) for Class, Struct, Interface, Enum, Error Domain, Delegate, and Namespace names.
* Use `ALL_CAPS_SNAKE` for Constants, Enum members, and Error Codes.

```vala
public class MainWindow : Gtk.ApplicationWindow {
    private string _window_title;
    public const int MAX_ITEMS = 10;
}
```

---

## Strings & Character Literals

* Use string templates (`@"..."`) for interpolation.
* Use triple quotes `"""..."""` for multiline verbatim strings.

---

## Operators & Spacing

### <a id="space-infix-ops"></a>Spaces Around Infix Operators

* Infix operators must be surrounded by spaces.

```vala
int result = a + b; // ✓ ok
int result = a + b;   // ✗ avoid
```

### <a id="operator-linebreak"></a>Leading Operators on Wrapped Binary Expressions

* When boolean (`&&`, `||`) or binary operator expressions wrap across multiple lines, operators break at the beginning
  of continuation lines.
* Continuation lines are indented by 2 tabs relative to the enclosing statement.

```vala
// ✓ ok
if (very_long_condition_one ()
&& very_long_condition_two ()
&& very_long_condition_three ()) {
    do_something ();
}
```

### <a id="space-unary-ops"></a>No Space Before Unary Operands

* Unary operators should not have a space before their operand.

```vala
bool valid = !is_empty; // ✓ ok
bool valid = ! is_empty; // ✗ avoid
```

### <a id="cast-spacing"></a>Space After Cast Target or As

* Add space after type cast target or `as` operator.

```vala
var win = (Gtk.Window) widget;  // ✓ ok
var win = widget as Gtk.Window; // ✓ ok
```

### <a id="owned-unowned-space"></a>Space After Owned / Unowned

* Add space after `owned` / `unowned` keywords.

```vala
public unowned string get_title () { ... } // ✓ ok
```

---

## Object-Oriented & Vala Features

### <a id="property-body-newline"></a>Multi-Line Property Accessor Bodies

* Single-line property definitions are allowed **only** for body-less accessors (`get; set;`). Properties with code
  bodies must be split across separate lines.

```vala
// ✓ ok (auto-property without bodies)
public string title { get; set; }

// ✓ ok (custom getter/setter with bodies on separate lines)
public string name {
get {
return _name;
}
set {
_name = value;
}
}

// ✗ avoid (property accessors with bodies on a single line)
public string name { get { return _name; } set { _name = value; } }
```

### <a id="object-property-newline"></a>Construct Property Initializers

* Format object construct properties nicely across separate lines.

```vala
// ✓ ok
var window = new Gtk.ApplicationWindow (app) {
    title = "My App",
    default_width = 800,
    default_height = 600
};
```

### <a id="initializer-wrap"></a>Multi-Line Array & Struct Initializer Tables

* Static array tables, matrices, and multi-line struct initializers are formatted with one element per line, indented by
  an additional tab step. Simple flat initializers fit inline.

```vala
// ✓ ok (multi-line table layout)
const OptionEntry[] options = {
    { "vapidir", 0, 0, OptionArg.FILENAME_ARRAY, ref vapi_dirs, "Look for bindings", "DIR" },
    { "girdir", 0, 0, OptionArg.FILENAME_ARRAY, ref gir_dirs, "Look for .gir files", "DIR" },
    { null }
};

// ✓ ok (simple inline array)
int[] numbers = { 1, 2, 3 };
```

### <a id="nullable-type-spacing"></a>No Space Before Nullable Indicator

* Place `?` for nullable types directly after the type without space.

```vala
string? optional_name = null;  // ✓ ok
string ? optional_name = null; // ✗ avoid
```

### <a id="enum-value-newline"></a>Enum Member Newlines

* Enum and error domain members are formatted strictly one per line. Comments between or preceding enum members are
  preserved in source order.

```vala
// ✓ ok
public enum ProcessState {
// Idle waiting for input
    IDLE,
    // Currently processing
    RUNNING,
    STOPPED
}
```

### <a id="attribute-placement"></a>Attribute Placement

* Declaration attributes (such as `[DBus (name = "...")]` or `[CCode (...)]`) are placed on separate lines directly
  preceding the entity they annotate. Parameter attributes remain inline.

```vala
// ✓ ok
[DBus (name = "org.example.App")]
public class AppService : Object {
    public void execute ([CCode (array_length = false)] string[] args) {
    }
}
```

---

## Error Handling

### <a id="throws-space"></a>Space Before Throws Clause

* Add space before `throws` clause.

```vala
public void parse () throws ParseError, FileError { // ✓ ok
}
```

---

## Comments & Documentation

### <a id="comment-spacing"></a>Space After Comment Markers (`comment-spacing`)

* Add a space after single-line comment markers (`// Comment`).
* Use Valadoc style (`/** ... */`) for public API documentation.

```vala
// ✓ ok
// Standard single-line comment
int x = 42;

// ✗ avoid
//Missing space after slash
int x = 42;
```

### <a id="no-valadoc-in-body"></a>No Valadoc Comments in Method Bodies (`no-valadoc-in-body`)

* Valadoc doc-comments (`/** ... */`) must only be placed before exportable declarations (`class`, `struct`,
  `interface`, `enum`, `method`, `property`, `field`, `signal`, `delegate`).
* Placing `/** ... */` inside statement blocks or method bodies will never be exported to API documentation. Use
  standard multi-line (`/* ... */`) or single-line (`// ...`) comments instead.

```vala
// ✓ ok (standard comments inside method bodies)
public void process () {
/* Standard block comment */
    int x = 1;
// Single line comment
}

// ✗ avoid (Valadoc comment inside method body will not be exported)
public void process () {
/**
 * Unexported Valadoc inside method body
 */
    int x = 1;
}
```

### <a id="double-semicolon"></a>No Double Semicolons (`double-semicolon`)

* Stray empty semicolons `;;` after statements should be removed.

```vala
// ✓ ok
int x = 1;

// ✗ avoid
int x = 1;;
```

### <a id="unnecessary-string-template"></a>No Redundant String Template Interpolation (`unnecessary-string-template`)

* Avoid template string interpolation `@""` when a single string variable or expression is being referenced without
  surrounding text.

```vala
// ✓ ok
string msg = name;
string full = @"hello $(name)";

// ✗ avoid
string msg = @"$(name)";
```

### <a id="keyword-as-identifier"></a>Disallow Unescaped Keywords as Identifiers (`keyword-as-identifier`)

* Keywords used as identifiers (e.g. variable names, parameters, or members matching Vala reserved words like `if`,
  `class`, `foreach`, `default`) must be escaped with a leading `@` prefix (e.g., `@if`, `@foreach`).
* When running `valafmt --lint`, unescaped keyword identifiers in parseable declarations trigger a
  `keyword-as-identifier` warning. When formatting, `valafmt` automatically inserts the `@` escape. In
  statement/expression positions where unescaped keywords prevent parsing, `valafmt` reports an actionable syntax error
  pointing out the missing `@` escape.

```vala
// ✓ ok
int @if = 1;
string @foreach = "item";

// ✗ avoid
int if = 1;
```
