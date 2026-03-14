# Graphviz in MoonBit

A [MoonBit](https://www.moonbitlang.com/) library for parsing, laying out, and rendering [Graphviz DOT](https://graphviz.org/doc/info/lang.html) graphs.

```text
DOT string ──→ parse ──→ AST ──→ layout ──→ SVG/HTML
```

## Installation

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "antisatori/graphviz": "0.1.0"
  }
}
```

Then run:

```bash
moon update
```

## Quick Start

```moonbit
fn main {
  let dot = "digraph { a -> b -> c }"
  match @parser.parse_dot(dot) {
    Ok(graph) => {
      let layout = @layout.compute_layout(graph)
      println(@svg.render_svg(layout))
    }
    Err(e) => println("Error at position \{e.position}: \{e.message}")
  }
}
```

## Packages

The library is split into three packages that form a pipeline:

| Package | Import path | Purpose |
|---------|-------------|---------|
| **parser** | `antisatori/graphviz/lib/parser` | Parse DOT → AST, format AST → DOT |
| **layout** | `antisatori/graphviz/lib/layout` | Compute node positions and edge routes |
| **svg** | `antisatori/graphviz/lib/svg` | Render layout to SVG or HTML |

You can use any package independently. For example, use just the parser for DOT manipulation without rendering.

## Parser

### Parsing DOT strings

```moonbit
let result : Result[Graph, ParseError] = @parser.parse_dot(
  #|digraph G {
  #|  rankdir=LR;
  #|  a -> b [label="edge"];
  #|  b -> c;
  #|}
)

match result {
  Ok(graph) => {
    // graph.directed == true
    // graph.id == Some("G")
    // graph.statements contains NodeStmt, EdgeStmt, etc.
  }
  Err(e) => println("Parse error at \{e.position}: \{e.message}")
}
```

### Formatting back to DOT

```moonbit
let dot_string : String = @parser.format_graph(graph)
```

Round-tripping is supported: `parse_dot(dot) |> format_graph` produces valid DOT output.

### Parsing attribute strings

```moonbit
let attrs : Array[Attribute] = @parser.parse_attributes("color=red, style=bold")
// [{ key: "color", value: "red" }, { key: "style", value: "bold" }]
```

### AST Types

The parser produces a strongly-typed AST:

```moonbit
// Top-level graph
struct Graph {
  strict : Bool         // "strict" keyword present
  directed : Bool       // digraph (true) vs graph (false)
  id : String?          // optional graph name
  statements : Array[Statement]
}

// Statements
enum Statement {
  NodeStmt(NodeId, AttributeList?)              // a [color=red]
  EdgeStmt(NodeId, Array[(EdgeOp, NodeId)], AttributeList?)  // a -> b -> c [label="x"]
  AttrStmt(AttrTarget, AttributeList)           // node [shape=box]
  Assignment(String, String)                     // rankdir=LR
  Subgraph(Subgraph)                            // subgraph cluster_0 { ... }
}

// Edge operators
enum EdgeOp { Directed /* -> */ ; Undirected /* -- */ }

// Attribute statement targets
enum AttrTarget { GraphAttr; NodeAttr; EdgeAttr }

// Node identifier with optional port
struct NodeId { id : String; port : Port? }
struct Port { id : String?; compass : CompassPoint? }
enum CompassPoint { N; NE; E; SE; S; SW; W; NW; C; Underscore }

// Attributes
struct AttributeList { attributes : Array[Attribute] }
struct Attribute { key : String; value : String }

// Subgraphs
struct Subgraph { id : String?; statements : Array[Statement] }
```

All AST types are `pub(all)` — you can construct and pattern-match on them directly.

### ToDot / FromDot Traits

Convert between your domain types and DOT graphs:

```moonbit
pub(open) trait ToDot {
  to_graph(Self) -> Graph
}

pub(open) trait FromDot {
  from_graph(Graph) -> Self?
}
```

Example implementation:

```moonbit
struct MyGraph {
  edges : Array[(String, String)]
}

pub impl @parser.ToDot for MyGraph with to_graph(self) {
  @parser.Graph::{
    strict: false,
    directed: true,
    id: None,
    statements: self.edges.map(fn(edge) {
      @parser.EdgeStmt(
        @parser.NodeId::{ id: edge.0, port: None },
        [(@parser.Directed, @parser.NodeId::{ id: edge.1, port: None })],
        None,
      )
    }),
  }
}

// Then use the convenience functions:
let dot_string : String = @parser.to_dot_string(my_graph)
let parsed : MyGraph? = @parser.from_dot_string(dot_string)
```

## Layout

The layout engine implements the [Sugiyama algorithm](https://en.wikipedia.org/wiki/Layered_graph_drawing) for layered graph drawing:

1. **Cycle removal** — reverse back-edges to make the graph acyclic
2. **Layer assignment** — assign nodes to horizontal layers
3. **Crossing minimization** — reorder nodes within layers to reduce edge crossings
4. **Coordinate assignment** — compute x/y positions for each node
5. **Edge routing** — compute waypoints for edges between layers

### Computing layout

```moonbit
let graph = @parser.parse_dot("digraph { a -> b -> c }").unwrap()

// Default settings
let layout : GraphLayout = @layout.compute_layout(graph)

// Custom settings
let layout = @layout.compute_layout_with_config(
  graph,
  @layout.LayoutConfig::compact(),
)
```

### LayoutConfig presets

```moonbit
// Default — comfortable spacing for readability
LayoutConfig::default()
// node_width: 80, node_height: 40
// layer_spacing: 100, node_spacing: 60, edge_spacing: 20

// Compact — tighter spacing for dense graphs
LayoutConfig::compact()
// node_width: 60, node_height: 30
// layer_spacing: 70, node_spacing: 40, edge_spacing: 15
```

Or create your own:

```moonbit
let config = @layout.LayoutConfig::{
  node_width: 120.0,
  node_height: 50.0,
  layer_spacing: 150.0,
  node_spacing: 80.0,
  edge_spacing: 25.0,
}
```

### Layout result

```moonbit
struct GraphLayout {
  nodes : Map[String, LayoutNode]  // keyed by node ID
  edges : Array[LayoutEdge]
  bounds : Bounds                  // bounding box of the entire graph
  layers : Array[Array[String]]    // node IDs grouped by layer
  directed : Bool
}

struct LayoutNode {
  id : String
  label : String
  position : Point     // center position
  size : Size
  layer : Int
  order : Int          // order within layer
  color : String?      // from DOT attributes
  fontcolor : String?
  fillcolor : String?
}

struct LayoutEdge {
  from : String
  to : String
  waypoints : Array[Point]  // polyline points
  reversed : Bool           // true if edge was reversed to break cycles
}
```

## SVG Rendering

### Basic rendering

```moonbit
let svg : String = @svg.render_svg(layout)
let html : String = @svg.render_html(layout, "My Graph")
```

### Custom theme

```moonbit
let svg = @svg.render_svg_with_config(layout, @svg.SvgConfig::dark_theme())
```

### SvgConfig presets

```moonbit
// Default — light background, black strokes
SvgConfig::default()
// node_fill: "#ffffff", node_stroke: "#333333"
// edge_stroke: "#666666", text_color: "#333333"
// font_size: 14, font_family: "Arial, Helvetica, sans-serif"

// Dark theme — dark background, light strokes
SvgConfig::dark_theme()
// node_fill: "#2d2d2d", node_stroke: "#cccccc"
// edge_stroke: "#999999", text_color: "#e0e0e0"
```

Or create your own:

```moonbit
let config = @svg.SvgConfig::{
  padding: 30.0,
  node_stroke: "#0066cc",
  node_fill: "#e6f0ff",
  node_stroke_width: 2.0,
  edge_stroke: "#0066cc",
  edge_stroke_width: 1.5,
  text_color: "#003366",
  font_size: 12.0,
  font_family: "monospace",
}
```

### Saving to files

```moonbit
// Save SVG
match @svg.save_svg(layout, "output.svg") {
  Ok(_) => println("Saved!")
  Err(e) => println("Error: \{e}")
}

// Save HTML with title
match @svg.save_html(layout, "output.html", "My Graph") {
  Ok(_) => println("Saved!")
  Err(e) => println("Error: \{e}")
}

// With custom config
@svg.save_svg_with_config(layout, "output.svg", config) |> ignore
@svg.save_html_with_config(layout, "output.html", "Title", config) |> ignore
```

## Full Pipeline Example

```moonbit
fn main {
  let dot =
    #|digraph {
    #|  node [shape=box];
    #|  Start -> Parse -> Layout -> Render;
    #|  Parse -> Error [style=dashed];
    #|}

  match @parser.parse_dot(dot) {
    Ok(graph) => {
      // Customize layout
      let config = @layout.LayoutConfig::compact()
      let layout = @layout.compute_layout_with_config(graph, config)

      // Render with dark theme
      let svg = @svg.render_svg_with_config(layout, @svg.SvgConfig::dark_theme())
      println(svg)

      // Or save as HTML
      @svg.save_html(layout, "pipeline.html", "Pipeline") |> ignore
    }
    Err(e) => println("Parse error: \{e.message}")
  }
}
```

## Supported DOT Features

The parser implements the [DOT language grammar](https://graphviz.org/doc/info/lang.html):

- `digraph` (directed) and `graph` (undirected)
- `strict` modifier
- Node statements with attributes: `a [color=red, label="Node A"]`
- Edge chains: `a -> b -> c` and `a -- b -- c`
- Edge attributes: `a -> b [label="edge", style=dashed]`
- Default attributes: `node [shape=box]`, `edge [color=blue]`, `graph [rankdir=LR]`
- Graph-level assignments: `rankdir=LR`
- Subgraphs and clusters: `subgraph cluster_0 { ... }`
- Ports and compass points: `a:port1:n -> b:port2:s`
- Quoted strings with escape sequences: `"line 1\nline 2"`
- C-style comments: `// ...`, `/* ... */`, `# ...`

## References

- [Graphviz](https://graphviz.org/)
- [DOT Language Specification](https://graphviz.org/doc/info/lang.html)
- [MoonBit Documentation](https://docs.moonbitlang.com/)

## License

Apache-2.0
