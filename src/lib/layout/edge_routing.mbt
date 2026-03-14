// Phase 5: Edge Routing

///|
fn route_edges(
  edges : Array[EdgeData],
  reversed : Array[Bool],
  node_positions : Map[String, LayoutNode],
  _config : LayoutConfig,
) -> Array[LayoutEdge] {
  let layout_edges : Array[LayoutEdge] = []
  for i = 0; i < edges.length(); i = i + 1 {
    let edge = edges[i]
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
        let is_reversed = reversed[i]
        layout_edges.push({
          from: edge.from,
          to: edge.to,
          waypoints: [source_point, target_point],
          reversed: is_reversed,
        })
      }
      _ => ()
    }
  }
  layout_edges
}
