// Phase 4: Coordinate Assignment

///|
fn assign_coordinates(
  layers : Array[Array[String]],
  nodes : Map[String, NodeData],
  config : LayoutConfig,
) -> Map[String, LayoutNode] {
  let positions : Map[String, LayoutNode] = Map::new()
  for layer_index = 0
      layer_index < layers.length()
      layer_index = layer_index + 1 {
    let layer = layers[layer_index]
    let y = layer_index.to_double() *
      (config.node_height + config.layer_spacing)
    let n = layer.length()
    if n == 0 {
      continue
    }
    let total_width = (n - 1).to_double() * config.node_spacing +
      n.to_double() * config.node_width
    let start_x = -total_width / 2.0
    for i = 0; i < n; i = i + 1 {
      let node_id = layer[i]
      let x = start_x +
        i.to_double() * (config.node_width + config.node_spacing)
      let (label, color, fontcolor, fillcolor) = match nodes.get(node_id) {
        Some(nd) => (nd.label, nd.color, nd.fontcolor, nd.fillcolor)
        None => (node_id, None, None, None)
      }
      positions.set(node_id, {
        id: node_id,
        label,
        position: { x, y },
        size: { width: config.node_width, height: config.node_height },
        layer: layer_index,
        order: i,
        color,
        fontcolor,
        fillcolor,
      })
    }
  }
  positions
}
