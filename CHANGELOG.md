# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-21

First public release. Three packages forming a DOT → AST → layout → SVG pipeline. Any of them can be used independently.

### Parser — `dowdiness/graphviz/lib/parser`

- Full DOT grammar: `strict`, `graph`/`digraph`, node statements, edge chains (`a -> b -> c`), attribute statements, default attributes, graph-level assignments, subgraphs and clusters, ports with compass points, quoted strings with escape sequences, and C-style / hash comments.
- `parse_dot` returns `Result[Graph, ParseError]` with position-tagged errors (no panics on bad input).
- `parse_attributes` for standalone attribute-list parsing.
- `format_graph` round-trips with `parse_dot`: preserves subgraph operands, label overrides, compass-only ports, non-BMP characters, and mixed-case keywords.
- `ToDot` / `FromDot` traits plus `to_dot_string` / `from_dot_string` convenience functions for serializing domain types to DOT.
- AST types (`Graph`, `Statement`, `NodeId`, `Port`, `CompassPoint`, `EdgeOp`, `AttrTarget`, `AttributeList`, `Attribute`, `Subgraph`) are `pub(all)` — consumers can construct and pattern-match them directly.

### Layout — `dowdiness/graphviz/lib/layout`

- Sugiyama-style layered layout with five phases: cycle removal, layer assignment, crossing minimization, coordinate assignment, edge routing.
- Topological sort via [`dowdiness/alga`](https://mooncakes.io/docs/dowdiness/alga).
- Immutable data flow through the pipeline.
- Per-node `color` / `fontcolor` / `fillcolor` attributes extracted from the AST and carried into the rendered output.
- `LayoutConfig` with `default()` and `compact()` presets for node/layer spacing.

### SVG — `dowdiness/graphviz/lib/svg`

- SVG and HTML rendering via [`dowdiness/svg-dsl`](https://mooncakes.io/docs/dowdiness/svg-dsl).
- `SvgConfig::default()` (light background, dark strokes) and `SvgConfig::dark_theme()` (dark background, light strokes).
- Per-node color attributes override config defaults.
- Convenience helpers: `save_svg`, `save_svg_with_config`, `save_html`, `save_html_with_config`.

[Unreleased]: https://github.com/dowdiness/graphviz/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dowdiness/graphviz/releases/tag/v0.1.0
