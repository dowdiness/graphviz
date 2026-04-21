# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a MoonBit implementation of a Graphviz DOT language parser. The project parses DOT graph description language according to the [DOT Language Specification](https://graphviz.org/doc/info/lang.html) and builds an Abstract Syntax Tree (AST) representation.

## Essential Commands

### Building and Running
```bash
# Build the project
moon build

# Run the main program
moon run src/main

# Check code without building
moon check
```

### Testing
```bash
# Run all tests
moon test

# Run tests in a specific package (parser / layout / svg)
moon test -p lib/parser

# Run a specific test file
moon test -p lib/parser -f parser_test.mbt

# Run a specific test by index
moon test -p lib/parser -f parser_test.mbt -i 0

# Update test snapshots
moon test -u
```

### Code Quality
```bash
# Format all source files
moon fmt

# Build with warnings as errors
moon build -d
```

### Documentation
```bash
# Generate documentation
moon doc
```

## Architecture

### Module Structure

The library is split into three packages that form a pipeline (DOT → AST → layout → SVG), plus application-level packages:

- **`src/lib/parser/`** (`antisatori/graphviz/lib/parser`)
  - Lexer, recursive-descent parser, AST types, and DOT formatter
  - Public entry points: `parse_dot`, `parse_attributes`, `format_graph`, `ToDot`/`FromDot` traits
  - Files: `ast.mbt`, `lexer.mbt`, `parser.mbt`, `formatter.mbt`

- **`src/lib/layout/`** (`antisatori/graphviz/lib/layout`)
  - Sugiyama-style layered layout: cycle removal, layer assignment, crossing minimization, coordinate assignment, edge routing
  - Public entry points: `compute_layout`, `compute_layout_with_config`, `LayoutConfig`

- **`src/lib/svg/`** (`antisatori/graphviz/lib/svg`)
  - Renders a `GraphLayout` to SVG or HTML, using `antisatori/svg-dsl`
  - Public entry points: `render_svg`, `render_html`, `SvgConfig`

- **`src/main/`** — CLI entry point that exercises the pipeline on example graphs
- **`src/browser/`** — Browser entry point (JS target) for the web demo

### Parser Architecture

The parser follows a classic lexer-parser architecture, split across four files in `src/lib/parser/`:

1. **Lexer (`lexer.mbt`)**: Tokenizes DOT language input
   - Handles identifiers, keywords, operators, quoted strings, numerals (including dot-prefixed like `.5`)
   - Supports C-style comments (`//`, `/* */`) and hash comments (`#`); rejects unterminated block comments
   - Returns a stream of `Token` enum values

2. **Parser (`parser.mbt`)**: Builds AST from tokens
   - Recursive descent parser following DOT grammar rules
   - Top-level entry: `parse_dot` returns `Result[Graph, ParseError]` with position-tagged errors
   - Parses statements recursively: nodes, edges, attributes, subgraphs
   - Expands subgraph edge endpoints into concrete edges during parsing

3. **AST Types (`ast.mbt`)**: Strongly-typed representation of DOT graphs
   - `Graph`: Top-level structure (strict/non-strict, directed/undirected)
   - `Statement`: `NodeStmt`, `EdgeStmt`, `AttrStmt`, `Assignment`, `Subgraph`
   - `AttrTarget`: `GraphAttr` / `NodeAttr` / `EdgeAttr` (typed target for attribute statements)
   - `NodeId`, `Port`, `CompassPoint`: Node identifiers with optional ports
   - `EdgeOp`: Directed (`->`) vs undirected (`--`) edges
   - `AttributeList`: Key-value attribute pairs

4. **Formatter (`formatter.mbt`)**: AST → DOT string
   - Round-trips with `parse_dot`: preserves subgraph operands, label overrides, compass-only ports, non-BMP characters
   - Quotes IDs and escapes strings conservatively

### Key Design Patterns

- **Recursive descent parsing**: Each grammar rule maps to a parser method (e.g., `parse_statement`, `parse_node_id`, `parse_edge_rhs`)
- **Token consumption**: An `eat`/`expect`-style method verifies and consumes expected tokens, raising `ParseError` on mismatch
- **Optional elements**: Parser methods return `Option` types for optional grammar elements
- **Iteration**: Uses `while` and `for .. in` with accumulator state (MoonBit's `loop` keyword is deprecated)

### Grammar Implementation

The parser implements the DOT language grammar as specified:

```
graph     : [ strict ] (graph | digraph) [ ID ] '{' stmt_list '}'
stmt_list : [ stmt [ ';' ] stmt_list ]
stmt      : node_stmt | edge_stmt | attr_stmt | ID '=' ID | subgraph
edge_stmt : (node_id | subgraph) edgeRHS [ attr_list ]
edgeRHS   : edgeop (node_id | subgraph) [ edgeRHS ]
```

Key parsing entry points live in `src/lib/parser/parser.mbt`: `parse_dot`, `parse_graph`, `parse_statement`, `parse_edge_rhs`, `parse_node_id`, `parse_stmt_list`. Use `moon ide peek-def <symbol>` to jump to any of them rather than relying on line numbers.

## MoonBit Language Specifics

### Function Syntax
Recent commits indicate a shift to method-style function syntax:
- Use method style: `fn Parser::parse_graph(self : Parser) -> Graph?`
- Not: `fn parse_graph(parser : Parser) -> Graph?`

### Type Aliases
Use `using` syntax for type aliases instead of deprecated `typealias`:
```moonbit
using Env = @map.Map[String, Value]
```

### Accessing Inner Types
Use direct access instead of deprecated `Complex::T` syntax:
```moonbit
Complex  // not Complex::T
```

### Iteration

The codebase uses `while` and `for .. in` with accumulator state for iterative operations. MoonBit's `loop` keyword is deprecated.

## Testing

Each library package owns its own tests alongside its source:

- `src/lib/parser/parser_test.mbt`, `formatter_test.mbt` — parser/formatter behavior, error reporting, round-trip property tests
- `src/lib/layout/layout_test.mbt`, `layout_wbtest.mbt` — layout phase invariants (whitebox) and end-to-end behavior (blackbox)
- `src/lib/svg/` — snapshot and color tests for the SVG renderer

Tests exercise basic directed graphs, undirected graphs with attributes, clustered subgraphs, ports with compass points, and automaton-style record nodes. The tests demonstrate both parsing and formatting via `parse_dot` and `format_graph`.
