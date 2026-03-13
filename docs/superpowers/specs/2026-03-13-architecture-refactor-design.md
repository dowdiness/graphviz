# Architecture Refactor Design

Clean boundaries, immutable data flow, curated public API, and comprehensive tests for the graphviz DOT parser and layout engine.

**Consumers:** `crdt` monorepo, `loom` (specifically `loom/loom/src/viz/` which constructs AST types directly), and the internal `src/browser/` package. All under same ownership — breaking changes acceptable.

---

## 1. Parser Package File Split

Split `dot_parser.mbt` (~1,128 lines) into four focused files within the existing `src/lib/parser/` package (no new packages created):

| File | Contents | Lines (approx) |
|------|----------|-----------------|
| `ast.mbt` | AST types: `Graph`, `Statement`, `Subgraph`, `NodeId`, `Port`, `CompassPoint`, `EdgeOp`, `Attribute`, `AttributeList`, `ParseError` (new) | ~130 |
| `lexer.mbt` | `Lexer` struct, tokenization, `keyword_or_id` | ~280 |
| `parser.mbt` | `Parser` struct, recursive descent, `parse_dot`, `parse_attributes`, subgraph helpers, `EdgeRhsParseResult` | ~520 |
| `formatter.mbt` | `format_graph`, `format_id`, `format_node_id`, `format_indent`, `format_statement_with_indent`, `format_attr_list`, `format_compass`, `needs_quoting`, `escape_and_quote` | ~200 |

`traits.mbt` updated to handle `Result` from `parse_dot` (see Section 3).

### Visibility changes

- `Token` enum: `pub(all)` -> private (implementation detail)
- `Lexer` struct: already private, stays private (note: `.mbti` exposes it as opaque `type Lexer` — this will disappear once all consumers of the struct are internal)
- `Parser` struct: `pub(all)` -> private (consumers use `parse_dot`, not `Parser` directly)
- `EdgeRhsParseResult`: already `priv`, stays `priv`
- AST types (`Graph`, `Statement`, `NodeId`, etc.): stay `pub(all)` — `loom/loom/src/viz/` constructs these directly

### Test file split

Split `dot_parser_test.mbt` (~1,109 lines, 72 tests) into:
- `parser_test.mbt` — parsing success/failure tests, error reporting tests
- `formatter_test.mbt` — formatting output and round-trip tests

### Pre-flight check

Before making `Token`/`Parser` private, grep `crdt`, `loom`, and `src/browser/` to confirm none reference them directly.

---

## 2. Layout Package: Immutable Data Flow

Replace the mutable `InternalGraph` threading with explicit inputs and outputs per phase. The layout package already has a clean file-per-phase structure (`cycle_removal.mbt`, `layer_assignment.mbt`, etc.) — this section changes the data flow and types, not the file organization.

### Current problem

- `build_adjacency_lists` mutates `NodeInfo.incoming`/`outgoing` in-place, returns the same object
- `remove_cycles` internally calls `build_adjacency_lists`, creating invisible coupling
- `assign_coordinates` reads from the same mutable `InternalGraph.nodes` map
- Phases can't be called independently without understanding hidden mutation order

### New data types (package-private)

```moonbit
struct NodeData {
  id : String
  label : String
  color : String?
  fontcolor : String?
  fillcolor : String?
}

struct EdgeData {
  from : String
  to : String
}
```

Replaces `InternalGraph`, `NodeInfo`, `Edge`, `EdgeDirection`.

### New phase signatures

```moonbit
// Phase 0: AST extraction
fn extract_graph(@parser.Graph) -> (Map[String, NodeData], Array[EdgeData])

// Phase 1: Cycle removal
// Builds adjacency internally via build_adjacency. Returns new edge list
// plus a map recording which edges were reversed.
fn remove_cycles(Array[EdgeData]) -> (Array[EdgeData], Map[String, @hashset.HashSet[String]])

// Phase 2: Layer assignment
fn assign_layers(Map[String, NodeData], Array[EdgeData]) -> Map[String, Int]

// Phase 3: Crossing minimization
fn minimize_crossings(Map[String, NodeData], Array[EdgeData], Array[Array[String]], Int) -> Array[Array[String]]

// Phase 4: Coordinate assignment
fn assign_coordinates(Array[Array[String]], Map[String, NodeData], LayoutConfig) -> Map[String, LayoutNode]

// Phase 5: Edge routing
fn route_edges(Array[EdgeData], Map[String, @hashset.HashSet[String]], Map[String, LayoutNode], LayoutConfig) -> Array[LayoutEdge]
```

### Adjacency as utility

```moonbit
fn build_adjacency(edges : Array[EdgeData]) -> (Map[String, Array[String]], Map[String, Array[String]])
```

Called internally by phases that need adjacency (cycle removal, layer assignment, crossing minimization). Not exposed in the orchestrator pipeline. Each phase that needs adjacency calls this function on its input edges.

### Eliminated types

- `InternalGraph` — replaced by `(nodes, edges)` pairs
- `NodeInfo` — replaced by immutable `NodeData`
- `Edge` — replaced by `EdgeData`
- `EdgeDirection` enum — replaced by reversed map from `remove_cycles`

---

## 3. Public API Surface

### Parser package — public

```moonbit
// Data types (pub(all))
Graph, Statement, Subgraph, NodeId, Port, CompassPoint, EdgeOp, Attribute, AttributeList

// Error type (new, lives in ast.mbt)
pub(all) struct ParseError {
  message : String
  position : Int  // character index (matches Lexer.position)
} derive(Show)

// Functions
pub fn parse_dot(String) -> Result[Graph, ParseError]  // was Graph?
pub fn format_graph(Graph) -> String
pub fn format_id(String) -> String
pub fn parse_attributes(String) -> Array[Attribute]    // uses Parser internally

// Traits
pub(open) trait ToDot { to_graph(Self) -> Graph }
pub(open) trait FromDot { from_graph(Graph) -> Self? }
pub fn to_dot_string[T : ToDot](T) -> String
pub fn from_dot_string[T : FromDot](String) -> T?     // updated: propagates ParseError silently (returns None on Err)
```

### Parser package — private

`Token`, `Lexer`, `Parser`, all helper functions.

### Layout package — public

```moonbit
pub fn compute_layout(@parser.Graph) -> GraphLayout
pub fn compute_layout_with_config(@parser.Graph, LayoutConfig) -> GraphLayout

// Output types
GraphLayout, LayoutNode, LayoutEdge, Point, Size, Bounds

// Config
LayoutConfig, LayoutConfig::default(), LayoutConfig::compact()
```

### Layout package — private

`NodeData`, `EdgeData`, all phase functions, `build_adjacency`.

Note: `extract_graph` is currently `pub fn` and used in `layout_test.mbt`. It becomes private; that test moves to `layout_wbtest.mbt` (whitebox).

### SVG package — unchanged

Already clean.

### Consumer migration

**`parse_dot` call sites** change from:
```moonbit
match parse_dot(s) { Some(g) => ... None => ... }
```
to:
```moonbit
match parse_dot(s) { Ok(g) => ... Err(e) => ... }
```

**Affected call sites:**
- `src/main/main.mbt`
- `src/browser/browser.mbt`
- `loom/loom/src/viz/` (if it calls `parse_dot`)
- `from_dot_string` in `traits.mbt` (internal — updated to map `Err` to `None`)

---

## 4. Test Strategy

### Current coverage

| Area | Tests | Lines | Quality |
|------|-------|-------|---------|
| Parser | 72 | ~1,109 | Strong |
| Layout | 4 | ~83 | Weak |
| SVG | 6 | ~145 | Structural only |

### New tests

**Layout invariant tests (`layout_wbtest.mbt`, whitebox):**
Whitebox because phase functions become private after the refactor.
- Cycle removal: acyclic input unchanged, single cycle has one reversal, self-loops handled, disconnected components
- Layer assignment: sources at layer 0, edges go lower-to-higher, all nodes assigned
- Crossing minimization: same nodes per layer (no loss/duplication), crossing count does not increase
- Coordinate assignment: no X-overlap within a layer, layers ordered top-to-bottom in Y, all nodes present
- Edge routing: every edge has >= 2 waypoints, endpoints within node bounds
- Graph extraction: moved from current `layout_test.mbt` (currently tests `extract_graph` which becomes private)

**Round-trip property tests (additions to `formatter_test.mbt`, blackbox):**
These only use public API (`parse_dot`, `format_graph`), so blackbox is sufficient.
- `parse_dot(format_graph(g)) == Ok(g)` for parsed graphs
- Every `NodeStmt` has valid `NodeId`
- Edge count matches edge operators in input

**Error reporting tests (additions to `parser_test.mbt`):**
- Unterminated graph → `Err` with position past `{`
- Invalid syntax → `Err` with meaningful message
- Position values match character indices in input

**SVG snapshot tests (additions to `renderer_test.mbt`):**
- Known 3-node graph → `inspect` snapshot of full SVG output
- Per-node color attributes reflected in SVG fill/stroke
- Undirected graph → no `marker-end` anywhere

### Test file organization

| File | Package | Type | Scope |
|------|---------|------|-------|
| `parser_test.mbt` | parser | blackbox | Parse success/failure, error positions |
| `formatter_test.mbt` | parser | blackbox | Format output, round-trips |
| `layout_wbtest.mbt` | layout | whitebox | Phase invariants, graph extraction |
| `layout_test.mbt` | layout | blackbox | End-to-end `compute_layout` |
| `renderer_test.mbt` | svg | blackbox | SVG snapshots, structural checks |
