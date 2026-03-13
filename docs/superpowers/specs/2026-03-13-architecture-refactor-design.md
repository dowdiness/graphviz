# Architecture Refactor Design

Clean boundaries, immutable data flow, curated public API, and comprehensive tests for the graphviz DOT parser and layout engine.

**Consumers:** `crdt` monorepo, `loom` (both under same ownership — breaking changes acceptable).

---

## 1. Parser Package File Split

Split `dot_parser.mbt` (1,129 lines) into four focused files within `src/lib/parser/`:

| File | Contents | Lines (approx) |
|------|----------|-----------------|
| `ast.mbt` | AST types: `Graph`, `Statement`, `Subgraph`, `NodeId`, `Port`, `CompassPoint`, `EdgeOp`, `Attribute`, `AttributeList` | ~120 |
| `lexer.mbt` | `Lexer` struct, tokenization, `keyword_or_id` | ~280 |
| `parser.mbt` | `Parser` struct, recursive descent, `parse_dot`, `parse_attributes`, subgraph helpers, `EdgeRhsParseResult` | ~520 |
| `formatter.mbt` | `format_graph`, `format_id`, `format_node_id`, `format_statement_with_indent`, `format_attr_list`, `format_compass`, `needs_quoting`, `escape_and_quote` | ~200 |

`traits.mbt` remains unchanged.

### Visibility changes

- `Token` enum: `pub(all)` -> private (implementation detail)
- `Lexer` struct: already private, stays private
- `Parser` struct: `pub(all)` -> private (consumers use `parse_dot`, not `Parser` directly)
- AST types (`Graph`, `Statement`, `NodeId`, etc.): stay `pub(all)`

### Test file split

Split `dot_parser_test.mbt` (1,110 lines) into:
- `parser_test.mbt` — parsing success/failure tests
- `formatter_test.mbt` — formatting output and round-trip tests

### Pre-flight check

Before making `Token`/`Parser` private, grep `crdt` and `loom` to confirm neither references them directly.

---

## 2. Layout Package: Immutable Data Flow

Replace the mutable `InternalGraph` threading with explicit inputs and outputs per phase.

### Current problem

- `build_adjacency_lists` mutates `NodeInfo.incoming`/`outgoing` in-place, returns the same object
- `remove_cycles` internally calls `build_adjacency_lists`, creating invisible coupling
- `assign_coordinates` reads from the same mutable `InternalGraph.nodes` map
- Phases can't be called independently without understanding hidden mutation order

### New data types (package-private)

```
struct NodeData {
  id: String
  label: String
  color: String?
  fontcolor: String?
  fillcolor: String?
}

struct EdgeData {
  from: String
  to: String
}
```

Replaces `InternalGraph`, `NodeInfo`, `Edge`, `EdgeDirection`.

### New phase signatures

```
// Phase 0: AST extraction
fn extract_graph(Graph) -> (Map[String, NodeData], Array[EdgeData])

// Phase 1: Cycle removal (returns new edge list + set of reversed pairs)
fn remove_cycles(Array[EdgeData]) -> (Array[EdgeData], Set[(String, String)])

// Phase 2: Layer assignment
fn assign_layers(Map[String, NodeData], Array[EdgeData]) -> Map[String, Int]

// Phase 3: Crossing minimization
fn minimize_crossings(Map[String, NodeData], Array[EdgeData], Array[Array[String]], Int) -> Array[Array[String]]

// Phase 4: Coordinate assignment
fn assign_coordinates(Array[Array[String]], Map[String, NodeData], LayoutConfig) -> Map[String, LayoutNode]

// Phase 5: Edge routing
fn route_edges(Array[EdgeData], Set[(String, String)], Map[String, LayoutNode], LayoutConfig) -> Array[LayoutEdge]
```

### Adjacency as utility

```
fn build_adjacency(Array[EdgeData]) -> (Map[String, Array[String]], Map[String, Array[String]])
```

Called internally by phases that need it (cycle removal, layer assignment, crossing minimization). Not exposed in the orchestrator pipeline.

### Eliminated types

- `InternalGraph` — replaced by `(nodes, edges)` pairs
- `NodeInfo` — replaced by immutable `NodeData`
- `Edge` — replaced by `EdgeData`
- `EdgeDirection` enum — replaced by reversed set from `remove_cycles`

---

## 3. Public API Surface

### Parser package — public

```moonbit
// Data types (pub(all))
Graph, Statement, Subgraph, NodeId, Port, CompassPoint, EdgeOp, Attribute, AttributeList

// Error type (new)
pub(all) struct ParseError {
  message: String
  position: Int  // byte offset
}

// Functions
pub fn parse_dot(String) -> Result[Graph, ParseError]  // was Graph?
pub fn format_graph(Graph) -> String
pub fn format_id(String) -> String
pub fn parse_attributes(String) -> Array[Attribute]

// Traits (unchanged)
pub(open) trait ToDot { to_graph(Self) -> Graph }
pub(open) trait FromDot { from_graph(Graph) -> Self? }
pub fn to_dot_string[T: ToDot](T) -> String
pub fn from_dot_string[T: FromDot](String) -> T?
```

### Parser package — private

`Token`, `Lexer`, `Parser`, all helper functions.

### Layout package — public

```moonbit
pub fn compute_layout(Graph) -> GraphLayout
pub fn compute_layout_with_config(Graph, LayoutConfig) -> GraphLayout

// Output types
GraphLayout, LayoutNode, LayoutEdge, Point, Size, Bounds

// Config
LayoutConfig, LayoutConfig::default(), LayoutConfig::compact()
```

### Layout package — private

`NodeData`, `EdgeData`, all phase functions, `build_adjacency`.

### SVG package — unchanged

Already clean.

### Consumer migration

`parse_dot` call sites change from:
```moonbit
match parse_dot(s) { Some(g) => ... None => ... }
```
to:
```moonbit
match parse_dot(s) { Ok(g) => ... Err(e) => ... }
```

---

## 4. Test Strategy

### Current coverage

| Area | Tests | Lines | Quality |
|------|-------|-------|---------|
| Parser | 62+ | 1,110 | Strong |
| Layout | 4 | 84 | Weak |
| SVG | 6 | 146 | Structural only |

### New tests

**Layout invariant tests (`layout_wbtest.mbt`, whitebox):**
- Cycle removal: acyclic input unchanged, single cycle has one reversal, self-loops handled, disconnected components
- Layer assignment: sources at layer 0, edges go lower-to-higher, all nodes assigned
- Crossing minimization: same nodes per layer (no loss/duplication), crossing count does not increase
- Coordinate assignment: no X-overlap within a layer, layers ordered top-to-bottom in Y, all nodes present
- Edge routing: every edge has >= 2 waypoints, endpoints within node bounds

**Round-trip property tests (`parser_wbtest.mbt`, whitebox):**
- `parse_dot(format_graph(g)) == Ok(g)` for parsed graphs
- Every `NodeStmt` has valid `NodeId`
- Edge count matches edge operators in input

**Error reporting tests (additions to `parser_test.mbt`):**
- Unterminated graph → `Err` with position past `{`
- Invalid syntax → `Err` with meaningful message
- Position values match byte offsets in input

**SVG snapshot tests (additions to `renderer_test.mbt`):**
- Known 3-node graph → `inspect` snapshot of full SVG output
- Per-node color attributes reflected in SVG fill/stroke
- Undirected graph → no `marker-end` anywhere

### Test file organization

| File | Type | Scope |
|------|------|-------|
| `parser_test.mbt` | blackbox | Parse success/failure, error positions |
| `formatter_test.mbt` | blackbox | Format output, round-trips |
| `layout_wbtest.mbt` | whitebox | Phase invariants |
| `layout_test.mbt` | blackbox | End-to-end `compute_layout` |
| `renderer_test.mbt` | blackbox | SVG snapshots, structural checks |
