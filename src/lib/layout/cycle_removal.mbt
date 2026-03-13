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
