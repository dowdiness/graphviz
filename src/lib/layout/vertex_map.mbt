///|
/// Mapping from String node IDs to Int vertex indices.
/// Bridges graphviz's String-based graph to alga's Int-based DirectedGraph.
priv struct VertexMap {
  to_int : Map[String, Int]
}

///|
/// Build a VertexMap from the node map.
/// Each node gets a stable Int index based on insertion order.
fn VertexMap::from_nodes(nodes : Map[String, NodeData]) -> VertexMap {
  let to_int : Map[String, Int] = Map::new()
  let mut idx = 0
  for id, _ in nodes {
    to_int[id] = idx
    idx = idx + 1
  }
  { to_int, }
}

///|
/// Convert an edge list to an alga AdjacencyMap using the vertex mapping.
/// Vertices not in the map are silently skipped.
fn VertexMap::to_adjacency_map(
  self : VertexMap,
  edges : Array[EdgeData],
) -> @alga.AdjacencyMap {
  let int_edges : Array[(Int, Int)] = []
  for edge in edges {
    match (self.to_int.get(edge.from), self.to_int.get(edge.to)) {
      (Some(u), Some(v)) => int_edges.push((u, v))
      _ => ()
    }
  }
  @alga.AdjacencyMap::from_edges(int_edges)
}
