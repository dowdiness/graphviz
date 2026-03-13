// Phase 2: Layer Assignment using topological sort

///|
fn assign_layers(
  nodes : Map[String, NodeData],
  edges : Array[EdgeData],
) -> Map[String, Int] {
  let (incoming, outgoing) = build_adjacency(edges)
  let layer_map : Map[String, Int] = Map::new()
  let in_degree : Map[String, Int] = Map::new()

  // Initialize in-degree for all nodes
  nodes.each(fn(id, _) {
    match incoming.get(id) {
      Some(inc) => in_degree.set(id, inc.length())
      None => in_degree.set(id, 0)
    }
  })

  // Initialize sources (in-degree 0) at layer 0
  let queue : Array[String] = []
  nodes.each(fn(id, _) {
    if in_degree.get(id).unwrap() == 0 {
      layer_map.set(id, 0)
      queue.push(id)
    }
  })

  // Process nodes in topological order
  while not(queue.is_empty()) {
    let current = queue.pop().unwrap()
    let current_layer = layer_map.get(current).unwrap()
    match outgoing.get(current) {
      Some(neighbors) =>
        for neighbor in neighbors {
          let neighbor_degree = in_degree.get(neighbor).unwrap()
          in_degree.set(neighbor, neighbor_degree - 1)
          let new_layer = current_layer + 1
          match layer_map.get(neighbor) {
            Some(existing_layer) =>
              if new_layer > existing_layer {
                layer_map.set(neighbor, new_layer)
              }
            None => layer_map.set(neighbor, new_layer)
          }
          if in_degree.get(neighbor).unwrap() == 0 {
            queue.push(neighbor)
          }
        }
      None => ()
    }
  }
  layer_map
}

///|
fn group_by_layer(layer_map : Map[String, Int]) -> Array[Array[String]] {
  let mut max_layer = 0
  layer_map.each(fn(_id, layer) { if layer > max_layer { max_layer = layer } })
  let layers : Array[Array[String]] = []
  for i = 0; i <= max_layer; i = i + 1 {
    layers.push([])
  }
  layer_map.each(fn(id, layer) { layers[layer].push(id) })
  layers
}
