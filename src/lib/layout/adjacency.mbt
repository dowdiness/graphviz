// Adjacency utility — computes incoming/outgoing maps from edge list

///|
fn make_edge_key(from : String, to : String) -> String {
  from + "\u0000" + to
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
