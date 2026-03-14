# Skipped Review Findings (2026-03-14)

Findings from the `/simplify` code review that were not addressed in this PR, with rationale for each.

## Adjacency triple-build

**Finding:** `build_adjacency(edges)` is called independently in `assign_layers` and `minimize_crossings`, and `remove_cycles` builds its own `build_indexed_outgoing_adjacency`. Three O(E) passes over the same edge list.

**Why skipped:** Already documented as a follow-up optimization (adjacency struct). Fixing it requires threading an adjacency object through the layout orchestrator, which changes the phase function signatures. Planned as a standalone PR.

## `_explicit` fields / parameter sprawl in `NodeData`

**Finding:** `NodeData` carries four `_explicit` boolean fields alongside value fields. `build_node_data` and `upsert_node` each take four separate boolean parameters. Adding a new style attribute requires touching both functions plus all call sites.

**Why skipped:** With only 4 style attributes, the explicit tracking is straightforward and readable. Abstracting into a `Set[String]` or `ExplicitFlags` struct adds indirection without meaningful gain at this scale. Revisit if attribute count grows beyond ~6.

## `AttrStmt` stringly-typed (`"graph"` / `"node"` / `"edge"`)

**Finding:** `Statement::AttrStmt(String, AttributeList)` uses a raw string for the target type. Should be an enum since only three values are valid per the DOT grammar.

**Why skipped:** `Statement` is a `pub(all)` AST type — changing the string to an enum is a public API break affecting downstream consumers. Worth doing in a dedicated breaking-change PR, not as cleanup inside an architecture refactor.

## `sweep_down` / `sweep_up` unification

**Finding:** The two functions differ only in iteration direction and which adjacency map is used. Bodies are otherwise identical.

**Why skipped:** A unified `sweep(direction, connections, layers)` function would need a direction parameter that controls iteration order, which layer is "adjacent", and loop bounds. The resulting abstraction is harder to read than two 12-line functions. The duplication is small and unlikely to diverge.

## `push_unique_node_id` linear scan

**Finding:** `push_unique_node_id` deduplicates by linear scan over the array. O(N^2) for N nodes in a subgraph.

**Why skipped:** `NodeId` is a struct (with optional `Port`) that doesn't implement `Hash`, so it can't be used as a `HashSet` key without adding a Hash derivation or manual implementation. In practice, subgraph node counts are small (DOT subgraphs rarely exceed tens of nodes). The cost of adding `Hash` to `NodeId`, `Port`, and `CompassPoint` outweighs the benefit.

## Layer copying in crossing minimization

**Finding:** `copy_layers` deep-copies all layers at the start of each sweep. 48 full copies across 24 iterations.

**Why skipped:** Each layer is a small `Array[String]` of node IDs. For typical graph sizes (tens to low hundreds of nodes), the copy cost is negligible. Mutating in place would require careful reasoning about aliasing and would make the sweep functions harder to understand.

## `merge_attrs` allocation per NodeStmt

**Finding:** `merge_attrs` allocates a fresh array when merging defaults + overrides, even though the result is only consumed by `extract_attr` and discarded.

**Why skipped:** The allocation is transient and small (typically <10 attributes). Avoiding it would require passing two separate attribute lists through `build_node_data` and scanning both in `extract_attr`, adding complexity for negligible performance gain.

## String-keyed maps throughout layout

**Finding:** All layout maps use `Map[String, ...]` keyed by node ID strings. Integer indices would be faster.

**Why skipped:** This is an architectural change that would require an ID-to-index mapping at extraction time, converting all downstream code to use integer indices, and maintaining the reverse mapping for output. Significant scope for a follow-up optimization PR, not in-scope for this refactor.

## Keyword list duplication (`keyword_or_id` vs `needs_quoting`)

**Finding:** The DOT keyword list (`strict`, `graph`, `digraph`, `node`, `edge`, `subgraph`) appears in both `lexer.mbt` and `formatter.mbt`.

**Why skipped:** Only 6 items in a closed set defined by the DOT spec. The two functions serve different purposes (token classification vs quoting decision) and are in different files for good reason (lexer vs formatter). A shared `is_dot_keyword` function would add a cross-file dependency for minimal deduplication benefit. The keyword list hasn't changed since the DOT spec was written.

## `needs_quoting` / `escape_and_quote` call `to_array()`

**Finding:** Both functions convert the string to a character array before iterating, allocating O(n) memory.

**Why skipped:** MoonBit strings don't expose a direct char iterator that avoids allocation. The `to_array()` approach is idiomatic in the current MoonBit ecosystem. The strings being processed (DOT identifiers and attribute values) are typically short (<100 chars).
