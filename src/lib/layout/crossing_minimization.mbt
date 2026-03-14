// Phase 3: Crossing Minimization using barycenter heuristic

///|
fn minimize_crossings(
  edges : Array[EdgeData],
  layers : Array[Array[String]],
  iterations : Int,
) -> Array[Array[String]] {
  let (incoming, outgoing) = build_adjacency(edges)
  let mut current_layers = copy_layers(layers)
  for _iter = 0; _iter < iterations; _iter = _iter + 1 {
    current_layers = sweep_down(incoming, current_layers)
    current_layers = sweep_up(outgoing, current_layers)
  }
  current_layers
}

///|
fn copy_layers(layers : Array[Array[String]]) -> Array[Array[String]] {
  let new_layers : Array[Array[String]] = []
  for layer in layers {
    let new_layer : Array[String] = []
    for node in layer {
      new_layer.push(node)
    }
    new_layers.push(new_layer)
  }
  new_layers
}

///|
fn sweep_down(
  incoming : Map[String, Array[String]],
  layers : Array[Array[String]],
) -> Array[Array[String]] {
  let new_layers = copy_layers(layers)
  for i = 1; i < new_layers.length(); i = i + 1 {
    let current_layer = new_layers[i]
    let previous_layer = new_layers[i - 1]
    let barycenters = compute_layer_barycenters(
      current_layer, previous_layer, incoming,
    )
    new_layers[i] = sort_by_barycenter(current_layer, barycenters)
  }
  new_layers
}

///|
fn sweep_up(
  outgoing : Map[String, Array[String]],
  layers : Array[Array[String]],
) -> Array[Array[String]] {
  let new_layers = copy_layers(layers)
  for i = new_layers.length() - 2; i >= 0; i = i - 1 {
    let current_layer = new_layers[i]
    let next_layer = new_layers[i + 1]
    let barycenters = compute_layer_barycenters(
      current_layer, next_layer, outgoing,
    )
    new_layers[i] = sort_by_barycenter(current_layer, barycenters)
  }
  new_layers
}

///|
fn compute_layer_barycenters(
  current_layer : Array[String],
  adjacent_layer : Array[String],
  connections : Map[String, Array[String]],
) -> Map[String, Double] {
  let pos_index : Map[String, Int] = Map::new()
  for i = 0; i < adjacent_layer.length(); i = i + 1 {
    pos_index.set(adjacent_layer[i], i)
  }
  let barycenters : Map[String, Double] = Map::new()
  let default_pos = adjacent_layer.length().to_double() / 2.0
  for node in current_layer {
    let connected = match connections.get(node) {
      Some(c) => c
      None => {
        barycenters.set(node, default_pos)
        continue
      }
    }
    if connected.is_empty() {
      barycenters.set(node, default_pos)
      continue
    }
    let mut sum = 0.0
    let mut count = 0
    for connected_node in connected {
      match pos_index.get(connected_node) {
        Some(pos) => {
          sum = sum + pos.to_double()
          count = count + 1
        }
        None => ()
      }
    }
    if count == 0 {
      barycenters.set(node, default_pos)
    } else {
      barycenters.set(node, sum / count.to_double())
    }
  }
  barycenters
}

///|
fn sort_by_barycenter(
  layer : Array[String],
  barycenters : Map[String, Double],
) -> Array[String] {
  let pairs : Array[(String, Double)] = []
  for node in layer {
    let barycenter = barycenters.get(node).unwrap_or(0.0)
    pairs.push((node, barycenter))
  }
  for i = 1; i < pairs.length(); i = i + 1 {
    let key = pairs[i]
    let mut j = i - 1
    while j >= 0 && pairs[j].1 > key.1 {
      pairs[j + 1] = pairs[j]
      j = j - 1
    }
    pairs[j + 1] = key
  }
  let sorted : Array[String] = []
  for pair in pairs {
    let (node, _) = pair
    sorted.push(node)
  }
  sorted
}
