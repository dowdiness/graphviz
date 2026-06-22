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
  let layout_edges = route_edges(
    acyclic_edges, reversed, node_positions, config,
  )

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
      if node.position.x < min_x {
        min_x = node.position.x
      }
      if node.position.y < min_y {
        min_y = node.position.y
      }
      if node_max_x > max_x {
        max_x = node_max_x
      }
      if node_max_y > max_y {
        max_y = node_max_y
      }
    }
  })
  { min_x, min_y, max_x, max_y }
}
