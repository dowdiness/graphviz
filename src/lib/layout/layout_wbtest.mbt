// Layout Phase Whitebox Tests

///|
test "extract_graph_simple" {
  match @parser.parse_dot("digraph { a -> b }") {
    Ok(graph) => {
      let (nodes, edges) = extract_graph(graph)
      inspect(nodes.length(), content="2")
      inspect(edges.length(), content="1")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "extract_graph_node_defaults_allow_explicit_override" {
  match @parser.parse_dot("digraph { node [color=red]; a [color=blue] }") {
    Ok(graph) => {
      let (nodes, _edges) = extract_graph(graph)
      let node = nodes.get("a").unwrap()
      inspect(node.color, content="Some(\"blue\")")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "extract_graph_node_defaults_accumulate" {
  match
    @parser.parse_dot("digraph { node [color=red]; node [fontcolor=white]; a }") {
    Ok(graph) => {
      let (nodes, _edges) = extract_graph(graph)
      let node = nodes.get("a").unwrap()
      inspect(node.color, content="Some(\"red\")")
      inspect(node.fontcolor, content="Some(\"white\")")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "extract_graph_subgraph_inherits_parent_node_defaults" {
  match @parser.parse_dot("digraph { node [color=red]; subgraph { a } }") {
    Ok(graph) => {
      let (nodes, _edges) = extract_graph(graph)
      let node = nodes.get("a").unwrap()
      inspect(node.color, content="Some(\"red\")")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "extract_graph_explicit_label_matching_id_overrides_default_label" {
  match @parser.parse_dot("digraph { node [label=default]; a [label=a] }") {
    Ok(graph) => {
      let (nodes, _edges) = extract_graph(graph)
      let node = nodes.get("a").unwrap()
      inspect(node.label, content="a")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "extract_graph_default_label_does_not_overwrite_existing_explicit_label" {
  match @parser.parse_dot("digraph { a [label=custom]; node [label=default]; a }") {
    Ok(graph) => {
      let (nodes, _edges) = extract_graph(graph)
      let node = nodes.get("a").unwrap()
      inspect(node.label, content="custom")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "extract_graph_default_styles_do_not_overwrite_existing_explicit_styles" {
  match @parser.parse_dot(
    "digraph { a [color=blue, fontcolor=white, fillcolor=black]; node [color=red, fontcolor=yellow, fillcolor=green]; a }",
  ) {
    Ok(graph) => {
      let (nodes, _edges) = extract_graph(graph)
      let node = nodes.get("a").unwrap()
      inspect(node.color, content="Some(\"blue\")")
      inspect(node.fontcolor, content="Some(\"white\")")
      inspect(node.fillcolor, content="Some(\"black\")")
    }
    Err(_) => abort("parse failed")
  }
}

///|
test "cycle_removal_acyclic_unchanged" {
  let edges : Array[EdgeData] = [{ from: "a", to: "b" }, { from: "b", to: "c" }]
  let (result, reversed) = remove_cycles(edges)
  inspect(result.length(), content="2")
  inspect(reversed, content="[false, false]")
}

///|
test "cycle_removal_single_cycle" {
  let edges : Array[EdgeData] = [{ from: "a", to: "b" }, { from: "b", to: "a" }]
  let (result, reversed) = remove_cycles(edges)
  inspect(result.length(), content="2")
  // Exactly one edge should be reversed
  inspect(reversed[0] != reversed[1], content="true")
}

///|
test "layer_assignment_sources_at_zero" {
  let nodes : Map[String, NodeData] = Map::new()
  nodes.set("a", {
    id: "a",
    label: "a",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  nodes.set("b", {
    id: "b",
    label: "b",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  nodes.set("c", {
    id: "c",
    label: "c",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  let edges : Array[EdgeData] = [{ from: "a", to: "b" }, { from: "b", to: "c" }]
  let layers = assign_layers(nodes, edges)
  inspect(layers.get("a"), content="Some(0)")
}

///|
test "layer_assignment_edges_go_lower_to_higher" {
  let nodes : Map[String, NodeData] = Map::new()
  nodes.set("a", {
    id: "a",
    label: "a",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  nodes.set("b", {
    id: "b",
    label: "b",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  nodes.set("c", {
    id: "c",
    label: "c",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  let edges : Array[EdgeData] = [{ from: "a", to: "b" }, { from: "b", to: "c" }]
  let layers = assign_layers(nodes, edges)
  let a_layer = layers.get("a").unwrap()
  let b_layer = layers.get("b").unwrap()
  let c_layer = layers.get("c").unwrap()
  inspect(a_layer < b_layer, content="true")
  inspect(b_layer < c_layer, content="true")
}

///|
test "crossing_minimization_preserves_nodes" {
  let edges : Array[EdgeData] = [{ from: "a", to: "c" }, { from: "b", to: "d" }]
  let layers : Array[Array[String]] = [["a", "b"], ["c", "d"]]
  let result = minimize_crossings(edges, layers, 4)
  // Same number of layers
  inspect(result.length(), content="2")
  // Same number of nodes per layer
  inspect(result[0].length(), content="2")
  inspect(result[1].length(), content="2")
}

///|
test "coordinate_assignment_no_overlap" {
  let nodes : Map[String, NodeData] = Map::new()
  nodes.set("a", {
    id: "a",
    label: "a",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  nodes.set("b", {
    id: "b",
    label: "b",
    label_explicit: false,
    color: None,
    color_explicit: false,
    fontcolor: None,
    fontcolor_explicit: false,
    fillcolor: None,
    fillcolor_explicit: false,
  })
  let layers : Array[Array[String]] = [["a", "b"]]
  let config = LayoutConfig::default()
  let positions = assign_coordinates(layers, nodes, config)
  let a_pos = positions.get("a").unwrap()
  let b_pos = positions.get("b").unwrap()
  // Nodes in same layer should not overlap in X
  let a_right = a_pos.position.x + a_pos.size.width
  inspect(a_right <= b_pos.position.x, content="true")
}

///|
test "edge_routing_has_waypoints" {
  let edges : Array[EdgeData] = [{ from: "a", to: "b" }]
  let reversed : Array[Bool] = [false]
  let positions : Map[String, LayoutNode] = Map::new()
  positions.set("a", {
    id: "a",
    label: "a",
    position: { x: 0.0, y: 0.0 },
    size: { width: 72.0, height: 36.0 },
    layer: 0,
    order: 0,
    color: None,
    fontcolor: None,
    fillcolor: None,
  })
  positions.set("b", {
    id: "b",
    label: "b",
    position: { x: 0.0, y: 116.0 },
    size: { width: 72.0, height: 36.0 },
    layer: 1,
    order: 0,
    color: None,
    fontcolor: None,
    fillcolor: None,
  })
  let config = LayoutConfig::default()
  let routed = route_edges(edges, reversed, positions, config)
  inspect(routed.length(), content="1")
  inspect(routed[0].waypoints.length() >= 2, content="true")
}

///|
test "edge_routing_tracks_reversal_per_edge" {
  let edges : Array[EdgeData] = [{ from: "a", to: "b" }, { from: "b", to: "a" }]
  let (acyclic_edges, reversed) = remove_cycles(edges)
  let positions : Map[String, LayoutNode] = Map::new()
  positions.set("a", {
    id: "a",
    label: "a",
    position: { x: 0.0, y: 0.0 },
    size: { width: 72.0, height: 36.0 },
    layer: 0,
    order: 0,
    color: None,
    fontcolor: None,
    fillcolor: None,
  })
  positions.set("b", {
    id: "b",
    label: "b",
    position: { x: 0.0, y: 116.0 },
    size: { width: 72.0, height: 36.0 },
    layer: 1,
    order: 0,
    color: None,
    fontcolor: None,
    fillcolor: None,
  })
  let config = LayoutConfig::default()
  let routed = route_edges(acyclic_edges, reversed, positions, config)
  inspect(routed.length(), content="2")
  inspect(routed[0].reversed != routed[1].reversed, content="true")
}
