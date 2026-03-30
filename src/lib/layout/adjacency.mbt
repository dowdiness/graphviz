// Adjacency utility — computes incoming/outgoing maps from edge list

///|
fn build_adjacency(
  edges : Array[EdgeData],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let incoming : Map[String, Array[String]] = Map::new()
  let outgoing : Map[String, Array[String]] = Map::new()
  for edge in edges {
    // Ensure both nodes exist in maps
    if !outgoing.contains(edge.from) {
      outgoing.set(edge.from, [])
    }
    if !incoming.contains(edge.to) {
      incoming.set(edge.to, [])
    }
    if !incoming.contains(edge.from) {
      incoming.set(edge.from, [])
    }
    if !outgoing.contains(edge.to) {
      outgoing.set(edge.to, [])
    }
    outgoing.get(edge.from).unwrap().push(edge.to)
    incoming.get(edge.to).unwrap().push(edge.from)
  }
  (incoming, outgoing)
}
