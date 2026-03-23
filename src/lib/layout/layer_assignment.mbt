// Phase 2: Layer Assignment using alga's topological sort

///|
/// Assign each node to a layer using longest-path layering.
///
/// 1. Map String node IDs to Int indices (VertexMap)
/// 2. Build AdjacencyMap and run alga's toposort (Kahn's algorithm)
/// 3. Walk topological order, propagating longest-path layers forward
/// 4. Map Int results back to String keys via reverse lookup
fn assign_layers(
  nodes : Map[String, NodeData],
  edges : Array[EdgeData],
) -> Map[String, Int] {
  let vmap = VertexMap::from_nodes(nodes)
  let g = vmap.to_adjacency_map(edges)
  let topo_order = match @alga.toposort(g) {
    Some(order) => order
    None =>
      // cycle_removal should have made the graph acyclic — if toposort
      // still finds a cycle, something is wrong upstream. Abort so
      // the bug surfaces during testing instead of producing a silent
      // degenerate layout.
      abort("assign_layers: toposort returned None (cycle detected) after cycle_removal — this is a bug")
  }
  // Forward propagation: each node's layer = max(predecessor layers) + 1
  let int_layer : Map[Int, Int] = Map::new()
  for v in topo_order {
    let current_layer = match int_layer.get(v) {
      Some(l) => l
      None => 0
    }
    @alga.DirectedGraph::for_each_successor(g, v, fn(w) {
      let new_layer = current_layer + 1
      match int_layer.get(w) {
        Some(existing) =>
          if new_layer > existing {
            int_layer[w] = new_layer
          }
        None => int_layer[w] = new_layer
      }
    })
  }
  // Map back to String keys via O(1) array index reverse lookup
  let layer_map : Map[String, Int] = Map::new()
  for idx, layer in int_layer {
    layer_map[vmap.to_string[idx]] = layer
  }
  // Ensure source nodes (layer 0, no predecessors) are included
  for id, _ in nodes {
    if not(layer_map.contains(id)) {
      layer_map[id] = 0
    }
  }
  layer_map
}

///|
fn group_by_layer(layer_map : Map[String, Int]) -> Array[Array[String]] {
  let mut max_layer = 0
  for _, layer in layer_map {
    if layer > max_layer {
      max_layer = layer
    }
  }
  let layers : Array[Array[String]] = []
  for _ in 0..<=max_layer {
    layers.push([])
  }
  for id, layer in layer_map {
    layers[layer].push(id)
  }
  layers
}
