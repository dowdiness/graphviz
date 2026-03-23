///|
/// Bidirectional mapping between String node IDs and Int vertex indices.
/// Bridges graphviz's String-based graph to alga's Int-based DirectedGraph.
///
/// - `to_int[name]` → Int index (for building AdjacencyMap)
/// - `to_string[idx]` → String name (for mapping results back)
priv struct VertexMap {
  to_int : Map[String, Int]
  to_string : Array[String]
}

///|
/// Build a VertexMap from the node map.
/// Each node gets a stable Int index based on insertion order.
fn VertexMap::from_nodes(nodes : Map[String, NodeData]) -> VertexMap {
  let to_int : Map[String, Int] = Map::new()
  let to_string : Array[String] = []
  for id, _ in nodes {
    to_int[id] = to_string.length()
    to_string.push(id)
  }
  { to_int, to_string }
}

///|
/// Convert an edge list to an alga AdjacencyMap using the vertex mapping.
/// Self-loops (u == v) are filtered out since they don't affect layering
/// and would cause toposort to report a false cycle.
fn VertexMap::to_adjacency_map(
  self : VertexMap,
  edges : Array[EdgeData],
) -> @alga.AdjacencyMap {
  let int_edges : Array[(Int, Int)] = []
  for edge in edges {
    match (self.to_int.get(edge.from), self.to_int.get(edge.to)) {
      (Some(u), Some(v)) => if u != v { int_edges.push((u, v)) }
      _ => ()
    }
  }
  @alga.AdjacencyMap::from_edges(int_edges)
}
