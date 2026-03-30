// Phase 1: Cycle Removal using DFS-based detection

///|
priv struct DFSState {
  visited : Map[String, Bool]
  on_stack : Map[String, Bool]
  reversed_edges : Array[Bool]
}

///|
fn remove_cycles(edges : Array[EdgeData]) -> (Array[EdgeData], Array[Bool]) {
  let outgoing = build_indexed_outgoing_adjacency(edges)
  let reversed_edges : Array[Bool] = []
  for _ in edges {
    reversed_edges.push(false)
  }
  let state : DFSState = {
    visited: Map::new(),
    on_stack: Map::new(),
    reversed_edges,
  }
  // DFS root choice decides which back edge gets flipped in a cycle.
  // Preserving first-seen order keeps that decision tied to DOT input order
  // instead of HashSet iteration order.
  let all_nodes : Array[String] = []
  let seen_nodes : @hashset.HashSet[String] = @hashset.HashSet::new()
  for edge in edges {
    if !seen_nodes.contains(edge.from) {
      seen_nodes.add(edge.from)
      all_nodes.push(edge.from)
    }
    if !seen_nodes.contains(edge.to) {
      seen_nodes.add(edge.to)
      all_nodes.push(edge.to)
    }
  }
  for id in all_nodes {
    state.visited.set(id, false)
  }

  // Run DFS from each unvisited node
  for id in all_nodes {
    match state.visited.get(id) {
      Some(false) => dfs_visit(id, outgoing, state)
      _ => ()
    }
  }

  // Build new edge list with reversed back edges
  let new_edges : Array[EdgeData] = []
  for i = 0; i < edges.length(); i = i + 1 {
    let edge = edges[i]
    if state.reversed_edges[i] {
      new_edges.push({ from: edge.to, to: edge.from })
    } else {
      new_edges.push(edge)
    }
  }
  (new_edges, state.reversed_edges)
}

///|
fn build_indexed_outgoing_adjacency(
  edges : Array[EdgeData],
) -> Map[String, Array[(String, Int)]] {
  let outgoing : Map[String, Array[(String, Int)]] = Map::new()
  for i = 0; i < edges.length(); i = i + 1 {
    let edge = edges[i]
    if !outgoing.contains(edge.from) {
      outgoing.set(edge.from, [])
    }
    if !outgoing.contains(edge.to) {
      outgoing.set(edge.to, [])
    }
    outgoing.get(edge.from).unwrap().push((edge.to, i))
  }
  outgoing
}

///|
fn dfs_visit(
  node : String,
  outgoing : Map[String, Array[(String, Int)]],
  state : DFSState,
) -> Unit {
  state.visited.set(node, true)
  state.on_stack.set(node, true)
  match outgoing.get(node) {
    Some(neighbors) =>
      for edge in neighbors {
        let (neighbor, edge_index) = edge
        match state.visited.get(neighbor) {
          Some(false) => dfs_visit(neighbor, outgoing, state)
          Some(true) =>
            match state.on_stack.get(neighbor) {
              // A neighbor already on the DFS stack closes a cycle, so mark
              // this edge for reversal and rebuild the edge list afterward.
              Some(true) => state.reversed_edges[edge_index] = true
              _ => ()
            }
          None => ()
        }
      }
    None => ()
  }
  state.on_stack.set(node, false)
}
