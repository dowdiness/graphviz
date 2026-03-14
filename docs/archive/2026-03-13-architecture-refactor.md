# Architecture Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the graphviz project for clean module boundaries, immutable layout data flow, curated public API, and comprehensive test coverage.

**Architecture:** Split the monolithic parser file into focused files, redesign layout phases to use immutable data flow with explicit inputs/outputs, tighten public API visibility, add structured parse errors, and fill test coverage gaps.

**Tech Stack:** MoonBit, moonbitlang/x (core library provides `@hashset.HashSet`), antisatori/svg-dsl

**Spec:** `docs/superpowers/specs/2026-03-13-architecture-refactor-design.md`

---

## Chunk 1: Parser Package File Split

### Task 1: Pre-flight check — verify no downstream usage of Token/Parser

**Files:**
- Read-only: `../loom/`, `../crdt/`, `src/browser/browser.mbt`, `src/main/main.mbt`

- [ ] **Step 1: Grep for Token/Parser references outside parser package**

Run:
```bash
cd /home/antisatori/ghq/github.com/dowdiness/crdt
grep -r "Token\|@parser\.Parser\|@parser\.Lexer" --include="*.mbt" loom/ graphviz/src/main/ graphviz/src/browser/ 2>/dev/null || echo "No references found"
```
Expected: No references to `Token`, `Parser`, or `Lexer` from outside the parser package.

- [ ] **Step 2: Commit (no-op if clean)**

No changes to commit — this is a read-only verification step.

---

### Task 2: Create ast.mbt — extract AST types

**Files:**
- Create: `src/lib/parser/ast.mbt`
- Modify: `src/lib/parser/dot_parser.mbt` (remove lines 1–123)

- [ ] **Step 1: Create `src/lib/parser/ast.mbt`**

Extract lines 1–123 from `dot_parser.mbt` into a new file `ast.mbt`. This includes:
- The DOT grammar comment block (lines 1–23)
- `Token` enum (lines 27–55) — change `pub(all)` to `priv`
- `CompassPoint` enum (lines 59–71) — keep `pub(all)`
- `Port` struct (lines 73–77) — keep `pub(all)`
- `NodeId` struct (lines 79–83) — keep `pub(all)`
- `EdgeOp` enum (lines 85–89) — keep `pub(all)`
- `Attribute` struct (lines 91–95) — keep `pub(all)`
- `AttributeList` struct (lines 97–100) — keep `pub(all)`
- `Statement` enum (lines 102–109) — keep `pub(all)`
- `Subgraph` struct (lines 111–115) — keep `pub(all)`
- `Graph` struct (lines 117–123) — keep `pub(all)`

Add new `ParseError` type at the end:

```moonbit
///|
pub(all) struct ParseError {
  message : String
  position : Int // UTF-16 code unit index
} derive(Show)
```

- [ ] **Step 2: Remove the extracted lines from `dot_parser.mbt`**

Delete lines 1–123 (grammar comment + all type definitions) from `dot_parser.mbt`. The file should now start at the `// Lexer implementation` comment (line 125).

- [ ] **Step 3: Run `moon check`**

Run: `moon check`
Expected: No errors. All types are in the same package so existing references resolve.

- [ ] **Step 4: Run tests**

Run: `moon test -p antisatori/graphviz/lib/parser`
Expected: All 72 tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/lib/parser/ast.mbt src/lib/parser/dot_parser.mbt
git commit -m "refactor(parser): extract AST types into ast.mbt

Move all type definitions (Graph, Statement, NodeId, etc.) to ast.mbt.
Add ParseError struct. Change Token visibility from pub(all) to priv."
```

---

### Task 3: Create lexer.mbt — extract lexer

**Files:**
- Create: `src/lib/parser/lexer.mbt`
- Modify: `src/lib/parser/dot_parser.mbt` (remove lexer section)

- [ ] **Step 1: Create `src/lib/parser/lexer.mbt`**

Extract the lexer section from `dot_parser.mbt` (originally lines 125–406). This includes:
- `Lexer` struct (already private — no `pub`)
- `Lexer::new`
- `Lexer::advance`
- `Lexer::peek_char`
- `Lexer::skip_whitespace`
- `Lexer::skip_comment`
- `Lexer::read_identifier`
- `Lexer::read_dotted_identifier`
- `Lexer::read_number`
- `Lexer::read_quoted_string`
- `keyword_or_id` free function
- `Lexer::next_token`

All these are already package-private. No visibility changes needed.

- [ ] **Step 2: Remove the lexer section from `dot_parser.mbt`**

Delete the lexer code from `dot_parser.mbt`. The file should now start at `// Parser implementation`.

- [ ] **Step 3: Run `moon check` and tests**

Run: `moon check && moon test -p antisatori/graphviz/lib/parser`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add src/lib/parser/lexer.mbt src/lib/parser/dot_parser.mbt
git commit -m "refactor(parser): extract lexer into lexer.mbt"
```

---

### Task 4: Create formatter.mbt — extract formatter

**Files:**
- Create: `src/lib/parser/formatter.mbt`
- Modify: `src/lib/parser/dot_parser.mbt` (remove formatter section)

- [ ] **Step 1: Create `src/lib/parser/formatter.mbt`**

Extract the formatter section from `dot_parser.mbt` (originally lines 929–1129). This includes:
- `needs_quoting` (private)
- `escape_and_quote` (private)
- `format_id` (pub)
- `format_graph` (pub)
- `format_node_id` (private)
- `format_indent` (private)
- `format_statement_with_indent` (private)
- `format_compass` (private)
- `format_attr_list` (private)

- [ ] **Step 2: Remove the formatter section from `dot_parser.mbt`**

Delete the formatter code from `dot_parser.mbt`.

- [ ] **Step 3: Run `moon check` and tests**

Run: `moon check && moon test -p antisatori/graphviz/lib/parser`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add src/lib/parser/formatter.mbt src/lib/parser/dot_parser.mbt
git commit -m "refactor(parser): extract formatter into formatter.mbt"
```

---

### Task 5: Rename dot_parser.mbt to parser.mbt + tighten Parser visibility

**Files:**
- Rename: `src/lib/parser/dot_parser.mbt` → `src/lib/parser/parser.mbt`
- Modify: `src/lib/parser/parser.mbt` (change `Parser` visibility)

- [ ] **Step 1: Rename the file**

```bash
git mv src/lib/parser/dot_parser.mbt src/lib/parser/parser.mbt
```

- [ ] **Step 2: Change `Parser` struct from `pub(all)` to private**

In `parser.mbt`, change:
```moonbit
pub(all) struct Parser {
```
to:
```moonbit
struct Parser {
```

- [ ] **Step 3: Run `moon check` and tests**

Run: `moon check && moon test -p antisatori/graphviz/lib/parser`
Expected: All pass. `Parser` was not used externally.

- [ ] **Step 4: Update interfaces**

Run: `moon info && moon fmt`
Verify: `git diff *.mbti` — `Token` and `Parser` should no longer appear in the public interface.

- [ ] **Step 5: Commit**

```bash
git add src/lib/parser/
git commit -m "refactor(parser): rename to parser.mbt and make Parser private"
```

---

### Task 6: Split test file

**Files:**
- Rename: `src/lib/parser/dot_parser_test.mbt` → `src/lib/parser/parser_test.mbt`
- Create: `src/lib/parser/formatter_test.mbt`

- [ ] **Step 1: Rename test file**

```bash
git mv src/lib/parser/dot_parser_test.mbt src/lib/parser/parser_test.mbt
```

- [ ] **Step 2: Create `src/lib/parser/formatter_test.mbt`**

Move all format-related tests from `parser_test.mbt` to the new file. These are the tests whose names start with `format_` or that test `format_graph`/`format_id` output:
- `format_simple_graph` (originally line 694)
- `format_digraph` (line 707)
- `format_strict_graph` (line 719)
- `format_preserves_non_bmp_identifier` (line 731)
- `format_preserves_non_bmp_attribute_value` (line 743)
- `format_id_quotes_keywords_and_digit_leading_mixed_ids` (line 760)
- `format_graph_roundtrips_dotted_ids` (line 791)
- `format_subgraph_renders_nested_statements` (line 833)
- `format_attr_list_quotes_keyword_attribute_keys` (line 848)
- `format_edge_stmt_preserves_ports_and_compass` (line 865)
- `format_edge_stmt_preserves_compass_only_ports` (line 877)

Remove these tests from `parser_test.mbt`.

**Keep in `parser_test.mbt`** (do NOT move):
- `parse_attributes_requires_full_input_consumption` (line 824) — tests `parse_attributes` utility, not formatting

- [ ] **Step 3: Run all tests**

Run: `moon test -p antisatori/graphviz/lib/parser`
Expected: All 72 tests pass (split across two files).

- [ ] **Step 4: Commit**

```bash
git add src/lib/parser/parser_test.mbt src/lib/parser/formatter_test.mbt
git commit -m "refactor(parser): split tests into parser_test.mbt and formatter_test.mbt"
```

---

### Task 7: Change parse_dot return type to Result + update consumers

**Files:**
- Modify: `src/lib/parser/parser.mbt` — change `parse_dot` signature
- Modify: `src/lib/parser/traits.mbt` — update `from_dot_string`
- Modify: `src/lib/parser/parser_test.mbt` — update all `match parse_dot` patterns
- Modify: `src/lib/parser/formatter_test.mbt` — update format test patterns
- Modify: `src/main/main.mbt` — update `parse_dot` call sites
- Modify: `src/browser/browser.mbt` — update `parse_dot` call site
- Modify: `src/lib/layout/layout_test.mbt` — update `parse_dot` call sites
- Modify: `src/lib/svg/renderer_test.mbt` — update `parse_dot` call sites

- [ ] **Step 1: Update `parse_dot` in `parser.mbt`**

Change the function to return `Result[Graph, ParseError]`:

```moonbit
///|
pub fn parse_dot(input : String) -> Result[Graph, ParseError] {
  let parser = Parser::new(input)
  match parser.parse_graph() {
    Some(graph) =>
      match parser.current_token {
        EOF => Ok(graph)
        _ => Err({ message: "unexpected tokens after graph", position: parser.lexer.position })
      }
    None => Err({ message: "failed to parse graph", position: parser.lexer.position })
  }
}
```

- [ ] **Step 2: Update `from_dot_string` in `traits.mbt`**

```moonbit
pub fn[T : FromDot] from_dot_string(dot : String) -> T? {
  match parse_dot(dot) {
    Ok(graph) => FromDot::from_graph(graph)
    Err(_) => None
  }
}
```

- [ ] **Step 3: Update all test files**

In every test file that calls `parse_dot`, change pattern matches:
- `Some(graph) =>` → `Ok(graph) =>`
- `None =>` → `Err(_) =>`

Files to update:
- `src/lib/parser/parser_test.mbt` — all `match parse_dot(input)` patterns
- `src/lib/parser/formatter_test.mbt` — all `match parse_dot(input)` patterns
- `src/lib/layout/layout_test.mbt` — 4 tests
- `src/lib/svg/renderer_test.mbt` — 6 tests

Also update error case tests like:
```moonbit
// Before:
match parse_dot(input) {
  Some(_) => abort("Should fail")
  None => ()
}
// After:
match parse_dot(input) {
  Ok(_) => abort("Should fail")
  Err(_) => ()
}
```

And `inspect(parsed == None, content="true")` → `inspect(parsed.is_err(), content="true")`

- [ ] **Step 4: Update `src/main/main.mbt`**

Change both `parse_dot` call sites:
- In `test_layout` function (line 4): `Some(graph) =>` → `Ok(graph) =>`, `None =>` → `Err(_) =>`
- In `pub fn parse_dot` (line 50): `Some(graph) =>` → `Ok(graph) =>`, `None =>` → `Err(_) =>`
- In `pub fn render_dot_to_svg` (line 60): `Some(graph) =>` → `Ok(graph) =>`, `None =>` → `Err(_) =>`

- [ ] **Step 5: Update `src/browser/browser.mbt`**

Change: `Some(graph) =>` → `Ok(graph) =>`, `None =>` → `Err(_) =>`

- [ ] **Step 6: Run `moon check` and all tests**

Run: `moon check && moon test`
Expected: All tests pass across all packages.

- [ ] **Step 7: Update interfaces**

Run: `moon info && moon fmt`
Verify: `git diff *.mbti` — `parse_dot` signature should show `Result[Graph, ParseError]`.

- [ ] **Step 8: Commit**

```bash
git add src/
git commit -m "feat(parser): change parse_dot to return Result[Graph, ParseError]

Breaking change: parse_dot now returns Result[Graph, ParseError] instead
of Graph?. All consumers updated. from_dot_string maps Err to None."
```

---

## Chunk 2: Layout Package Immutable Data Flow

**Spec deviations (intentional):**
- The `reversed` return type from `remove_cycles` is simplified from `Map[String, @hashset.HashSet[String]]` (spec) to `@hashset.HashSet[String]` (plan) using null-byte-delimited keys for simpler lookup. `route_edges` updated accordingly.
- `minimize_crossings` drops the `Map[String, NodeData]` parameter (spec) since it only needs edges for adjacency.
- `loom` does not call `parse_dot` directly (confirmed in Task 1 grep), so no loom changes needed for the `Result` migration.

**Important:** Tasks 10–14 rewrite layout files one by one. `moon check` will fail during this stretch because files reference types being removed. This is expected. The first clean `moon check` is at Task 15, Step 4.

### Task 8: Define new layout types (NodeData, EdgeData)

**Files:**
- Modify: `src/lib/layout/types.mbt`

- [ ] **Step 1: Add new immutable types to `types.mbt`**

Add at the end of `types.mbt` (below existing types, which will be removed in a later task):

```moonbit
// Immutable node data extracted from AST

///|
struct NodeData {
  id : String
  label : String
  color : String?
  fontcolor : String?
  fillcolor : String?
} derive(Show)

// Immutable edge data

///|
struct EdgeData {
  from : String
  to : String
} derive(Eq, Show)
```

- [ ] **Step 2: Verify `@hashset.HashSet` is available**

Run: `moon check`
Expected: Pass. New types coexist with old ones temporarily. If `@hashset.HashSet` causes import errors in later tasks, add `moonbitlang/core/hashset` to `src/lib/layout/moon.pkg` imports.

- [ ] **Step 3: Commit**

```bash
git add src/lib/layout/types.mbt
git commit -m "refactor(layout): add NodeData and EdgeData immutable types"
```

---

### Task 9: Add build_adjacency utility

**Files:**
- Create: `src/lib/layout/adjacency.mbt`

- [ ] **Step 1: Create `adjacency.mbt`**

```moonbit
// Adjacency utility — computes incoming/outgoing maps from edge list

///|
fn make_edge_key(from : String, to : String) -> String {
  from + "\x00" + to
}

///|
fn build_adjacency(
  edges : Array[EdgeData],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let incoming : Map[String, Array[String]] = Map::new()
  let outgoing : Map[String, Array[String]] = Map::new()
  for edge in edges {
    // Ensure both nodes exist in maps
    if not(outgoing.contains(edge.from)) {
      outgoing.set(edge.from, [])
    }
    if not(incoming.contains(edge.to)) {
      incoming.set(edge.to, [])
    }
    if not(incoming.contains(edge.from)) {
      incoming.set(edge.from, [])
    }
    if not(outgoing.contains(edge.to)) {
      outgoing.set(edge.to, [])
    }
    outgoing.get(edge.from).unwrap().push(edge.to)
    incoming.get(edge.to).unwrap().push(edge.from)
  }
  (incoming, outgoing)
}
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: Pass.

- [ ] **Step 3: Commit**

```bash
git add src/lib/layout/adjacency.mbt
git commit -m "refactor(layout): add build_adjacency utility"
```

---

### Task 10: Rewrite graph_builder.mbt to use new types

**Files:**
- Modify: `src/lib/layout/graph_builder.mbt`

- [ ] **Step 1: Rewrite `extract_graph` and helpers**

Replace the entire content of `graph_builder.mbt`:

```moonbit
// Convert DOT AST to internal graph representation

///|
fn extract_graph(
  graph : @parser.Graph,
) -> (Map[String, NodeData], Array[EdgeData]) {
  let nodes = collect_nodes(graph.statements)
  let edges = collect_edges(graph.statements, graph.directed)
  (nodes, edges)
}

///|
fn extract_label(node_id : String, attrs : @parser.AttributeList?) -> String {
  match attrs {
    Some(attr_list) => {
      for attr in attr_list.attributes {
        if attr.key == "label" {
          return attr.value
        }
      }
      node_id
    }
    None => node_id
  }
}

///|
fn extract_attr(key : String, attrs : @parser.AttributeList?) -> String? {
  match attrs {
    Some(attr_list) => {
      for attr in attr_list.attributes {
        if attr.key == key {
          return Some(attr.value)
        }
      }
      None
    }
    None => None
  }
}

///|
fn collect_nodes(
  statements : Array[@parser.Statement],
) -> Map[String, NodeData] {
  let nodes : Map[String, NodeData] = Map::new()
  for stmt in statements {
    match stmt {
      @parser.NodeStmt(node_id, attrs) => {
        let label = extract_label(node_id.id, attrs)
        let color = extract_attr("color", attrs)
        let fontcolor = extract_attr("fontcolor", attrs)
        let fillcolor = extract_attr("fillcolor", attrs)
        nodes.set(node_id.id, { id: node_id.id, label, color, fontcolor, fillcolor })
      }
      @parser.EdgeStmt(start_node, edges, _attrs) => {
        if not(nodes.contains(start_node.id)) {
          nodes.set(start_node.id, {
            id: start_node.id, label: start_node.id,
            color: None, fontcolor: None, fillcolor: None,
          })
        }
        for edge_pair in edges {
          let (_edge_op, target_node) = edge_pair
          if not(nodes.contains(target_node.id)) {
            nodes.set(target_node.id, {
              id: target_node.id, label: target_node.id,
              color: None, fontcolor: None, fillcolor: None,
            })
          }
        }
      }
      @parser.Subgraph(subgraph) => {
        let subgraph_nodes = collect_nodes(subgraph.statements)
        subgraph_nodes.each(fn(id, node_data) {
          if not(nodes.contains(id)) {
            nodes.set(id, node_data)
          }
        })
      }
      @parser.AttrStmt(_, _) => ()
      @parser.Assignment(_, _) => ()
    }
  }
  nodes
}

///|
fn collect_edges(
  statements : Array[@parser.Statement],
  directed : Bool,
) -> Array[EdgeData] {
  let edges : Array[EdgeData] = []
  for stmt in statements {
    match stmt {
      @parser.EdgeStmt(start_node, edge_list, _attrs) => {
        let mut current = start_node.id
        for edge_pair in edge_list {
          let (edge_op, target_node) = edge_pair
          edges.push({ from: current, to: target_node.id })
          if not(directed) || edge_op == @parser.Undirected {
            edges.push({ from: target_node.id, to: current })
          }
          current = target_node.id
        }
      }
      @parser.Subgraph(subgraph) => {
        let subgraph_edges = collect_edges(subgraph.statements, directed)
        for edge in subgraph_edges {
          edges.push(edge)
        }
      }
      @parser.NodeStmt(_, _) => ()
      @parser.AttrStmt(_, _) => ()
      @parser.Assignment(_, _) => ()
    }
  }
  edges
}
```

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: Errors in other files that still reference old `InternalGraph`. This is expected — we fix them in the next tasks.

- [ ] **Step 3: Commit (work-in-progress)**

```bash
git add src/lib/layout/graph_builder.mbt
git commit -m "refactor(layout): rewrite graph_builder to use NodeData/EdgeData

WIP: other layout files still reference old types."
```

---

### Task 11: Rewrite cycle_removal.mbt

**Files:**
- Modify: `src/lib/layout/cycle_removal.mbt`

- [ ] **Step 1: Rewrite cycle removal to use new types**

Replace the entire content of `cycle_removal.mbt`:

```moonbit
// Phase 1: Cycle Removal using DFS-based detection

///|
priv struct DFSState {
  visited : Map[String, Bool]
  on_stack : Map[String, Bool]
  reversed_edges : @hashset.HashSet[String]
}

///|
fn remove_cycles(
  edges : Array[EdgeData],
) -> (Array[EdgeData], @hashset.HashSet[String]) {
  let (_, outgoing) = build_adjacency(edges)
  let state : DFSState = {
    visited: Map::new(),
    on_stack: Map::new(),
    reversed_edges: @hashset.HashSet::new(),
  }
  // Initialize all nodes as unvisited
  let all_nodes : @hashset.HashSet[String] = @hashset.HashSet::new()
  for edge in edges {
    all_nodes.add(edge.from)
    all_nodes.add(edge.to)
  }
  all_nodes.each(fn(id) { state.visited.set(id, false) })

  // Run DFS from each unvisited node
  all_nodes.each(fn(id) {
    match state.visited.get(id) {
      Some(false) => dfs_visit(id, outgoing, state)
      _ => ()
    }
  })

  // Build new edge list with reversed back edges
  let new_edges : Array[EdgeData] = []
  for edge in edges {
    let key = make_edge_key(edge.from, edge.to)
    if state.reversed_edges.contains(key) {
      new_edges.push({ from: edge.to, to: edge.from })
    } else {
      new_edges.push(edge)
    }
  }
  (new_edges, state.reversed_edges)
}

///|
fn dfs_visit(
  node : String,
  outgoing : Map[String, Array[String]],
  state : DFSState,
) -> Unit {
  state.visited.set(node, true)
  state.on_stack.set(node, true)
  match outgoing.get(node) {
    Some(neighbors) =>
      for neighbor in neighbors {
        match state.visited.get(neighbor) {
          Some(false) => dfs_visit(neighbor, outgoing, state)
          Some(true) =>
            match state.on_stack.get(neighbor) {
              Some(true) =>
                state.reversed_edges.add(make_edge_key(node, neighbor))
              _ => ()
            }
          None => ()
        }
      }
    None => ()
  }
  state.on_stack.set(node, false)
}
```

Note: We use a single `@hashset.HashSet[String]` with a delimiter-joined key (`"from\x00to"`) instead of `Map[String, @hashset.HashSet[String]]` for simpler lookup. The null byte delimiter is safe because DOT IDs never contain it.

- [ ] **Step 2: Run `moon check`**

Run: `moon check`
Expected: May still have errors in downstream files. Continue.

- [ ] **Step 3: Commit**

```bash
git add src/lib/layout/cycle_removal.mbt
git commit -m "refactor(layout): rewrite cycle_removal with immutable data flow

Uses EdgeData input, returns (new_edges, reversed_set).
Builds adjacency internally."
```

---

### Task 12: Rewrite layer_assignment.mbt

**Files:**
- Modify: `src/lib/layout/layer_assignment.mbt`

- [ ] **Step 1: Rewrite layer assignment to use new types**

Replace the entire content:

```moonbit
// Phase 2: Layer Assignment using topological sort

///|
fn assign_layers(
  nodes : Map[String, NodeData],
  edges : Array[EdgeData],
) -> Map[String, Int] {
  let (incoming, outgoing) = build_adjacency(edges)
  let layer_map : Map[String, Int] = Map::new()
  let in_degree : Map[String, Int] = Map::new()

  // Initialize in-degree for all nodes
  nodes.each(fn(id, _) {
    match incoming.get(id) {
      Some(inc) => in_degree.set(id, inc.length())
      None => in_degree.set(id, 0)
    }
  })

  // Initialize sources (in-degree 0) at layer 0
  let queue : Array[String] = []
  nodes.each(fn(id, _) {
    if in_degree.get(id).unwrap() == 0 {
      layer_map.set(id, 0)
      queue.push(id)
    }
  })

  // Process nodes in topological order
  while not(queue.is_empty()) {
    let current = queue.pop().unwrap()
    let current_layer = layer_map.get(current).unwrap()
    match outgoing.get(current) {
      Some(neighbors) =>
        for neighbor in neighbors {
          let neighbor_degree = in_degree.get(neighbor).unwrap()
          in_degree.set(neighbor, neighbor_degree - 1)
          let new_layer = current_layer + 1
          match layer_map.get(neighbor) {
            Some(existing_layer) =>
              if new_layer > existing_layer {
                layer_map.set(neighbor, new_layer)
              }
            None => layer_map.set(neighbor, new_layer)
          }
          if in_degree.get(neighbor).unwrap() == 0 {
            queue.push(neighbor)
          }
        }
      None => ()
    }
  }
  layer_map
}

///|
fn group_by_layer(layer_map : Map[String, Int]) -> Array[Array[String]] {
  let mut max_layer = 0
  layer_map.each(fn(_id, layer) { if layer > max_layer { max_layer = layer } })
  let layers : Array[Array[String]] = []
  for i = 0; i <= max_layer; i = i + 1 {
    layers.push([])
  }
  layer_map.each(fn(id, layer) { layers[layer].push(id) })
  layers
}
```

- [ ] **Step 2: Run `moon check`**

Expected: May still have errors in downstream files.

- [ ] **Step 3: Commit**

```bash
git add src/lib/layout/layer_assignment.mbt
git commit -m "refactor(layout): rewrite layer_assignment with immutable data flow"
```

---

### Task 13: Rewrite crossing_minimization.mbt

**Files:**
- Modify: `src/lib/layout/crossing_minimization.mbt`

- [ ] **Step 1: Rewrite crossing minimization to use new types**

Replace the entire content. The key change: instead of reading `node_info.incoming`/`node_info.outgoing`, call `build_adjacency` once and pass the maps through:

```moonbit
// Phase 3: Crossing Minimization using barycenter heuristic

///|
fn minimize_crossings(
  edges : Array[EdgeData],
  layers : Array[Array[String]],
  iterations : Int,
) -> Array[Array[String]] {
  let (incoming, outgoing) = build_adjacency(edges)
  let mut current_layers = copy_layers(layers)
  for _iter = 0; _iter < iterations; _iter = _iter + 1 {
    current_layers = sweep_down(incoming, current_layers)
    current_layers = sweep_up(outgoing, current_layers)
  }
  current_layers
}

///|
fn copy_layers(layers : Array[Array[String]]) -> Array[Array[String]] {
  let new_layers : Array[Array[String]] = []
  for layer in layers {
    let new_layer : Array[String] = []
    for node in layer {
      new_layer.push(node)
    }
    new_layers.push(new_layer)
  }
  new_layers
}

///|
fn sweep_down(
  incoming : Map[String, Array[String]],
  layers : Array[Array[String]],
) -> Array[Array[String]] {
  let new_layers = copy_layers(layers)
  for i = 1; i < new_layers.length(); i = i + 1 {
    let current_layer = new_layers[i]
    let previous_layer = new_layers[i - 1]
    let barycenters = compute_layer_barycenters(
      current_layer, previous_layer, incoming,
    )
    new_layers[i] = sort_by_barycenter(current_layer, barycenters)
  }
  new_layers
}

///|
fn sweep_up(
  outgoing : Map[String, Array[String]],
  layers : Array[Array[String]],
) -> Array[Array[String]] {
  let new_layers = copy_layers(layers)
  for i = new_layers.length() - 2; i >= 0; i = i - 1 {
    let current_layer = new_layers[i]
    let next_layer = new_layers[i + 1]
    let barycenters = compute_layer_barycenters(
      current_layer, next_layer, outgoing,
    )
    new_layers[i] = sort_by_barycenter(current_layer, barycenters)
  }
  new_layers
}

///|
fn compute_layer_barycenters(
  current_layer : Array[String],
  adjacent_layer : Array[String],
  connections : Map[String, Array[String]],
) -> Map[String, Double] {
  let barycenters : Map[String, Double] = Map::new()
  for node in current_layer {
    let barycenter = compute_barycenter(node, adjacent_layer, connections)
    barycenters.set(node, barycenter)
  }
  barycenters
}

///|
fn compute_barycenter(
  node : String,
  adjacent_layer : Array[String],
  connections : Map[String, Array[String]],
) -> Double {
  let connected = match connections.get(node) {
    Some(c) => c
    None => return adjacent_layer.length().to_double() / 2.0
  }
  if connected.is_empty() {
    return adjacent_layer.length().to_double() / 2.0
  }
  let mut sum = 0.0
  let mut count = 0
  for connected_node in connected {
    for i = 0; i < adjacent_layer.length(); i = i + 1 {
      if adjacent_layer[i] == connected_node {
        sum = sum + i.to_double()
        count = count + 1
        break
      }
    }
  }
  if count == 0 {
    return adjacent_layer.length().to_double() / 2.0
  }
  sum / count.to_double()
}

///|
fn sort_by_barycenter(
  layer : Array[String],
  barycenters : Map[String, Double],
) -> Array[String] {
  let pairs : Array[(String, Double)] = []
  for node in layer {
    let barycenter = barycenters.get(node).unwrap_or(0.0)
    pairs.push((node, barycenter))
  }
  for i = 1; i < pairs.length(); i = i + 1 {
    let key = pairs[i]
    let mut j = i - 1
    while j >= 0 && pairs[j].1 > key.1 {
      pairs[j + 1] = pairs[j]
      j = j - 1
    }
    pairs[j + 1] = key
  }
  let sorted : Array[String] = []
  for pair in pairs {
    let (node, _) = pair
    sorted.push(node)
  }
  sorted
}
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/layout/crossing_minimization.mbt
git commit -m "refactor(layout): rewrite crossing_minimization with immutable data flow"
```

---

### Task 14: Rewrite coordinate_assignment.mbt and edge_routing.mbt

**Files:**
- Modify: `src/lib/layout/coordinate_assignment.mbt`
- Modify: `src/lib/layout/edge_routing.mbt`

- [ ] **Step 1: Rewrite `coordinate_assignment.mbt`**

Replace the entire content:

```moonbit
// Phase 4: Coordinate Assignment

///|
fn assign_coordinates(
  layers : Array[Array[String]],
  nodes : Map[String, NodeData],
  config : LayoutConfig,
) -> Map[String, LayoutNode] {
  let positions : Map[String, LayoutNode] = Map::new()
  for layer_index = 0; layer_index < layers.length(); layer_index = layer_index + 1 {
    let layer = layers[layer_index]
    let y = layer_index.to_double() * (config.node_height + config.layer_spacing)
    let n = layer.length()
    if n == 0 {
      continue
    }
    let total_width = (n - 1).to_double() * config.node_spacing +
      n.to_double() * config.node_width
    let start_x = -total_width / 2.0
    for i = 0; i < n; i = i + 1 {
      let node_id = layer[i]
      let x = start_x + i.to_double() * (config.node_width + config.node_spacing)
      let (label, color, fontcolor, fillcolor) = match nodes.get(node_id) {
        Some(nd) => (nd.label, nd.color, nd.fontcolor, nd.fillcolor)
        None => (node_id, None, None, None)
      }
      positions.set(node_id, {
        id: node_id, label, position: { x, y },
        size: { width: config.node_width, height: config.node_height },
        layer: layer_index, order: i, color, fontcolor, fillcolor,
      })
    }
  }
  positions
}
```

- [ ] **Step 2: Rewrite `edge_routing.mbt`**

Replace the entire content:

```moonbit
// Phase 5: Edge Routing

///|
fn route_edges(
  edges : Array[EdgeData],
  reversed : @hashset.HashSet[String],
  node_positions : Map[String, LayoutNode],
  _config : LayoutConfig,
) -> Array[LayoutEdge] {
  let layout_edges : Array[LayoutEdge] = []
  for edge in edges {
    match (node_positions.get(edge.from), node_positions.get(edge.to)) {
      (Some(from_node), Some(to_node)) => {
        let source_point : Point = {
          x: from_node.position.x + from_node.size.width / 2.0,
          y: from_node.position.y + from_node.size.height,
        }
        let target_point : Point = {
          x: to_node.position.x + to_node.size.width / 2.0,
          y: to_node.position.y,
        }
        let is_reversed = reversed.contains(make_edge_key(edge.from, edge.to)) ||
          reversed.contains(make_edge_key(edge.to, edge.from))
        layout_edges.push({
          from: edge.from, to: edge.to,
          waypoints: [source_point, target_point],
          reversed: is_reversed,
        })
      }
      _ => ()
    }
  }
  layout_edges
}
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/layout/coordinate_assignment.mbt src/lib/layout/edge_routing.mbt
git commit -m "refactor(layout): rewrite coordinate_assignment and edge_routing"
```

---

### Task 15: Rewrite layout.mbt orchestrator + remove old types

**Files:**
- Modify: `src/lib/layout/layout.mbt`
- Modify: `src/lib/layout/types.mbt` (remove old types)

- [ ] **Step 1: Rewrite `layout.mbt` orchestrator**

Replace the entire content:

```moonbit
// Main Layout Orchestrator - Public API

///|
pub fn compute_layout(graph : @parser.Graph) -> GraphLayout {
  compute_layout_with_config(graph, LayoutConfig::default())
}

///|
pub fn compute_layout_with_config(
  graph : @parser.Graph,
  config : LayoutConfig,
) -> GraphLayout {
  // Phase 0: Extract graph from AST
  let (nodes, edges) = extract_graph(graph)

  // Phase 1: Remove cycles
  let (acyclic_edges, reversed) = remove_cycles(edges)

  // Phase 2: Assign layers
  let layer_map = assign_layers(nodes, acyclic_edges)
  let layers = group_by_layer(layer_map)

  // Phase 3: Minimize crossings
  let ordered_layers = minimize_crossings(acyclic_edges, layers, 24)

  // Phase 4: Assign coordinates
  let node_positions = assign_coordinates(ordered_layers, nodes, config)

  // Phase 5: Route edges
  let layout_edges = route_edges(acyclic_edges, reversed, node_positions, config)

  // Calculate bounds
  let bounds = calculate_bounds(node_positions)

  {
    nodes: node_positions,
    edges: layout_edges,
    bounds,
    layers: ordered_layers,
    directed: graph.directed,
  }
}

///|
fn calculate_bounds(nodes : Map[String, LayoutNode]) -> Bounds {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  nodes.each(fn(_id, node) {
    let node_max_x = node.position.x + node.size.width
    let node_max_y = node.position.y + node.size.height
    if first {
      min_x = node.position.x
      min_y = node.position.y
      max_x = node_max_x
      max_y = node_max_y
      first = false
    } else {
      if node.position.x < min_x { min_x = node.position.x }
      if node.position.y < min_y { min_y = node.position.y }
      if node_max_x > max_x { max_x = node_max_x }
      if node_max_y > max_y { max_y = node_max_y }
    }
  })
  { min_x, min_y, max_x, max_y }
}
```

- [ ] **Step 2: Remove old types from `types.mbt`**

Remove the `InternalGraph`, `NodeInfo`, `Edge`, and `EdgeDirection` definitions (lines 63–94 in the current file). Keep `Point`, `Size`, `Bounds`, `LayoutNode`, `LayoutEdge`, `GraphLayout`, and the new `NodeData`/`EdgeData`.

- [ ] **Step 3: Remove old `build_adjacency_lists` from `graph_builder.mbt`**

If any remnants of the old `build_adjacency_lists` function remain, remove them. The function has been replaced by `build_adjacency` in `adjacency.mbt`.

- [ ] **Step 4: Run `moon check` and all tests**

Run: `moon check && moon test`
Expected: All tests pass. The layout tests use `compute_layout` (public API) which still works.

- [ ] **Step 5: Update interfaces**

Run: `moon info && moon fmt`
Verify: `git diff *.mbti` — `InternalGraph`, `NodeInfo`, `Edge`, `EdgeDirection`, `build_adjacency_lists`, `extract_graph`, `remove_cycles`, `assign_layers`, `minimize_crossings`, `assign_coordinates`, `route_edges` should all be gone from the public interface. Only `compute_layout`, `compute_layout_with_config`, `GraphLayout`, `LayoutNode`, `LayoutEdge`, `Point`, `Size`, `Bounds`, `LayoutConfig` should remain. `group_by_layer` should also be gone (now package-private).

- [ ] **Step 6: Commit**

```bash
git add src/lib/layout/
git commit -m "refactor(layout): rewrite orchestrator and remove old mutable types

Complete the immutable data flow refactor. InternalGraph, NodeInfo,
Edge, EdgeDirection are removed. Layout phases are now package-private
pure functions."
```

---

## Chunk 3: Test Coverage

### Task 16: Layout whitebox tests

**Files:**
- Create: `src/lib/layout/layout_wbtest.mbt`
- Modify: `src/lib/layout/layout_test.mbt` (remove `graph_extraction_simple` test)

- [ ] **Step 1: Create `layout_wbtest.mbt`**

```moonbit
// Layout Phase Whitebox Tests

///|
test "extract_graph_simple" {
  match @parser.parse_dot("digraph { a -> b }") {
    Ok(graph) => {
      let (nodes, edges) = extract_graph(graph)
      inspect(nodes.length(), content="2")
      inspect(edges.length(), content="1")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "cycle_removal_acyclic_unchanged" {
  let edges : Array[EdgeData] = [
    { from: "a", to: "b" },
    { from: "b", to: "c" },
  ]
  let (result, reversed) = remove_cycles(edges)
  inspect(result.length(), content="2")
  inspect(reversed.length(), content="0")
}

///|
test "cycle_removal_single_cycle" {
  let edges : Array[EdgeData] = [
    { from: "a", to: "b" },
    { from: "b", to: "a" },
  ]
  let (result, reversed) = remove_cycles(edges)
  inspect(result.length(), content="2")
  // Exactly one edge should be reversed
  inspect(reversed.length(), content="1")
}

///|
test "layer_assignment_sources_at_zero" {
  let nodes : Map[String, NodeData] = Map::new()
  nodes.set("a", { id: "a", label: "a", color: None, fontcolor: None, fillcolor: None })
  nodes.set("b", { id: "b", label: "b", color: None, fontcolor: None, fillcolor: None })
  nodes.set("c", { id: "c", label: "c", color: None, fontcolor: None, fillcolor: None })
  let edges : Array[EdgeData] = [
    { from: "a", to: "b" },
    { from: "b", to: "c" },
  ]
  let layers = assign_layers(nodes, edges)
  inspect(layers.get("a"), content="Some(0)")
}

///|
test "layer_assignment_edges_go_lower_to_higher" {
  let nodes : Map[String, NodeData] = Map::new()
  nodes.set("a", { id: "a", label: "a", color: None, fontcolor: None, fillcolor: None })
  nodes.set("b", { id: "b", label: "b", color: None, fontcolor: None, fillcolor: None })
  nodes.set("c", { id: "c", label: "c", color: None, fontcolor: None, fillcolor: None })
  let edges : Array[EdgeData] = [
    { from: "a", to: "b" },
    { from: "b", to: "c" },
  ]
  let layers = assign_layers(nodes, edges)
  let a_layer = layers.get("a").unwrap()
  let b_layer = layers.get("b").unwrap()
  let c_layer = layers.get("c").unwrap()
  inspect(a_layer < b_layer, content="true")
  inspect(b_layer < c_layer, content="true")
}

///|
test "crossing_minimization_preserves_nodes" {
  let edges : Array[EdgeData] = [
    { from: "a", to: "c" },
    { from: "b", to: "d" },
  ]
  let layers : Array[Array[String]] = [["a", "b"], ["c", "d"]]
  let result = minimize_crossings(edges, layers, 4)
  // Same number of layers
  inspect(result.length(), content="2")
  // Same number of nodes per layer
  inspect(result[0].length(), content="2")
  inspect(result[1].length(), content="2")
}

///|
test "coordinate_assignment_no_overlap" {
  let nodes : Map[String, NodeData] = Map::new()
  nodes.set("a", { id: "a", label: "a", color: None, fontcolor: None, fillcolor: None })
  nodes.set("b", { id: "b", label: "b", color: None, fontcolor: None, fillcolor: None })
  let layers : Array[Array[String]] = [["a", "b"]]
  let config = LayoutConfig::default()
  let positions = assign_coordinates(layers, nodes, config)
  let a_pos = positions.get("a").unwrap()
  let b_pos = positions.get("b").unwrap()
  // Nodes in same layer should not overlap in X
  let a_right = a_pos.position.x + a_pos.size.width
  inspect(a_right <= b_pos.position.x, content="true")
}

///|
test "edge_routing_has_waypoints" {
  let edges : Array[EdgeData] = [{ from: "a", to: "b" }]
  let reversed : @hashset.HashSet[String] = @hashset.HashSet::new()
  let positions : Map[String, LayoutNode] = Map::new()
  positions.set("a", {
    id: "a", label: "a",
    position: { x: 0.0, y: 0.0 },
    size: { width: 72.0, height: 36.0 },
    layer: 0, order: 0,
    color: None, fontcolor: None, fillcolor: None,
  })
  positions.set("b", {
    id: "b", label: "b",
    position: { x: 0.0, y: 116.0 },
    size: { width: 72.0, height: 36.0 },
    layer: 1, order: 0,
    color: None, fontcolor: None, fillcolor: None,
  })
  let config = LayoutConfig::default()
  let routed = route_edges(edges, reversed, positions, config)
  inspect(routed.length(), content="1")
  inspect(routed[0].waypoints.length() >= 2, content="true")
}
```

- [ ] **Step 2: Update `layout_test.mbt`**

Remove the `graph_extraction_simple` test (it used `extract_graph` which is now private; the equivalent test is in the whitebox file).

Also update the remaining tests to use `Ok`/`Err` pattern matching (if not already done in Task 7).

- [ ] **Step 3: Run all layout tests**

Run: `moon test -p antisatori/graphviz/lib/layout`
Expected: All tests pass (both blackbox and whitebox).

- [ ] **Step 4: Commit**

```bash
git add src/lib/layout/layout_wbtest.mbt src/lib/layout/layout_test.mbt
git commit -m "test(layout): add whitebox tests for layout phase invariants"
```

---

### Task 17: Parser error reporting tests

**Files:**
- Modify: `src/lib/parser/parser_test.mbt`

- [ ] **Step 1: Add error reporting tests**

Append to `parser_test.mbt`:

```moonbit
///|
test "parse_dot_error_has_position_for_missing_brace" {
  match parse_dot("digraph") {
    Ok(_) => abort("should fail")
    Err(e) => {
      inspect(e.position > 0, content="true")
      inspect(e.message.length() > 0, content="true")
    }
  }
}

///|
test "parse_dot_error_has_position_for_trailing_tokens" {
  match parse_dot("digraph { a } extra") {
    Ok(_) => abort("should fail")
    Err(e) => {
      inspect(e.message.contains("unexpected"), content="true")
    }
  }
}
```

- [ ] **Step 2: Run parser tests**

Run: `moon test -p antisatori/graphviz/lib/parser`
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add src/lib/parser/parser_test.mbt
git commit -m "test(parser): add error reporting tests for ParseError"
```

---

### Task 18: Formatter round-trip tests

**Files:**
- Modify: `src/lib/parser/formatter_test.mbt`

- [ ] **Step 1: Add round-trip tests**

Append to `formatter_test.mbt`:

```moonbit
///|
test "roundtrip_simple_digraph" {
  let input = "digraph { a -> b }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      match parse_dot(formatted) {
        Ok(reparsed) => {
          assert_eq(reparsed.directed, graph.directed)
          assert_eq(reparsed.strict, graph.strict)
          assert_eq(reparsed.statements.length(), graph.statements.length())
        }
        Err(e) => abort("roundtrip failed: " + e.message)
      }
    }
    Err(e) => abort("initial parse failed: " + e.message)
  }
}

///|
test "roundtrip_graph_with_attributes" {
  let input = "strict digraph G { node [shape=box]; a [color=red]; a -> b [label=edge1] }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      match parse_dot(formatted) {
        Ok(reparsed) => {
          assert_eq(reparsed.strict, true)
          assert_eq(reparsed.id, Some("G"))
          assert_eq(reparsed.statements.length(), graph.statements.length())
        }
        Err(e) => abort("roundtrip failed: " + e.message)
      }
    }
    Err(e) => abort("initial parse failed: " + e.message)
  }
}
```

- [ ] **Step 2: Run tests**

Run: `moon test -p antisatori/graphviz/lib/parser`
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add src/lib/parser/formatter_test.mbt
git commit -m "test(parser): add round-trip property tests for formatter"
```

---

### Task 19: SVG snapshot tests

**Files:**
- Modify: `src/lib/svg/renderer_test.mbt`

- [ ] **Step 1: Add SVG snapshot test**

Append to `renderer_test.mbt`:

```moonbit
///|
test "render_svg_snapshot_simple_digraph" {
  let dot = "digraph { a -> b -> c }"
  match @parser.parse_dot(dot) {
    Ok(graph) => {
      let layout = @layout.compute_layout(graph)
      let svg = render_svg(layout)
      // Verify key structural elements
      inspect(svg.contains("<rect"), content="true")
      inspect(svg.contains("<text"), content="true")
      inspect(svg.contains("<polyline"), content="true")
      inspect(svg.contains("arrowhead"), content="true")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "render_svg_respects_node_colors" {
  let dot = "digraph { a [color=red, fillcolor=blue, fontcolor=white]; a -> b }"
  match @parser.parse_dot(dot) {
    Ok(graph) => {
      let layout = @layout.compute_layout(graph)
      let svg = render_svg(layout)
      inspect(svg.contains("blue"), content="true")
      inspect(svg.contains("red"), content="true")
      inspect(svg.contains("white"), content="true")
    }
    Err(_) => abort("parse failed")
  }
}
```

- [ ] **Step 2: Run tests**

Run: `moon test -p antisatori/graphviz/lib/svg`
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add src/lib/svg/renderer_test.mbt
git commit -m "test(svg): add snapshot and color tests for SVG renderer"
```

---

### Task 20: Final verification and cleanup

**Files:**
- All

- [ ] **Step 1: Run full test suite**

Run: `moon test`
Expected: All tests pass across all packages.

- [ ] **Step 2: Run format and interface update**

Run: `moon info && moon fmt && moon check`
Expected: Clean.

- [ ] **Step 3: Review public API diff**

Run: `git diff HEAD~15 -- '*.mbti'`
Verify:
- Parser package: `Token`, `Parser` no longer in public interface. `ParseError` and `Result[Graph, ParseError]` added.
- Layout package: `InternalGraph`, `NodeInfo`, `Edge`, `EdgeDirection`, `build_adjacency_lists`, `extract_graph`, `remove_cycles`, `assign_layers`, `minimize_crossings`, `assign_coordinates`, `route_edges` all removed from public interface.
- SVG package: unchanged.

- [ ] **Step 4: Commit any remaining formatting changes**

```bash
git add -A
git commit -m "chore: final formatting and interface updates"
```
