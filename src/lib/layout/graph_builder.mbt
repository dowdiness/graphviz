// Convert DOT AST to internal graph representation

///|
fn extract_graph(
  graph : @parser.Graph,
) -> (Map[String, NodeData], Array[EdgeData]) {
  let nodes = collect_nodes(graph.statements)
  let edges = collect_edges(graph.statements, graph.directed)
  (nodes, edges)
}

///|
fn extract_attr(key : String, attrs : @parser.AttributeList?) -> String? {
  match attrs {
    Some(attr_list) => {
      let mut value = None
      // DOT treats later duplicate attributes as overriding earlier ones,
      // so keep scanning and return the last matching value.
      for attr in attr_list.attributes {
        if attr.key == key {
          value = Some(attr.value)
        }
      }
      value
    }
    None => None
  }
}

///|
fn collect_nodes(
  statements : Array[@parser.Statement],
) -> Map[String, NodeData] {
  let nodes : Map[String, NodeData] = Map::new()
  collect_nodes_with_defaults(statements, None, nodes)
  nodes
}

///|
fn collect_nodes_with_defaults(
  statements : Array[@parser.Statement],
  inherited_defaults : @parser.AttributeList?,
  nodes : Map[String, NodeData],
) -> Unit {
  let mut node_defaults = inherited_defaults
  for stmt in statements {
    match stmt {
      @parser.AttrStmt("node", attr_list) =>
        node_defaults = merge_attrs(node_defaults, Some(attr_list))
      @parser.NodeStmt(node_id, attrs) =>
        upsert_node(
          nodes,
          node_id.id,
          merge_attrs(node_defaults, attrs),
          extract_attr("label", attrs) is Some(_),
          extract_attr("color", attrs) is Some(_),
          extract_attr("fontcolor", attrs) is Some(_),
          extract_attr("fillcolor", attrs) is Some(_),
        )
      @parser.EdgeStmt(start_node, edges, _attrs) => {
        ensure_node(nodes, start_node.id, node_defaults)
        for edge_pair in edges {
          let (_edge_op, target_node) = edge_pair
          ensure_node(nodes, target_node.id, node_defaults)
        }
      }
      @parser.Subgraph(subgraph) =>
        collect_nodes_with_defaults(subgraph.statements, node_defaults, nodes)
      @parser.AttrStmt(_, _) => ()
      @parser.Assignment(_, _) => ()
    }
  }
}

///|
fn build_node_data(
  node_id : String,
  attrs : @parser.AttributeList?,
  label_explicit : Bool,
  color_explicit : Bool,
  fontcolor_explicit : Bool,
  fillcolor_explicit : Bool,
) -> NodeData {
  let label = extract_attr("label", attrs).unwrap_or(node_id)
  let color = extract_attr("color", attrs)
  let fontcolor = extract_attr("fontcolor", attrs)
  let fillcolor = extract_attr("fillcolor", attrs)
  {
    id: node_id,
    label,
    label_explicit,
    color,
    color_explicit,
    fontcolor,
    fontcolor_explicit,
    fillcolor,
    fillcolor_explicit,
  }
}

///|
fn merge_node_data(existing : NodeData, update : NodeData) -> NodeData {
  {
    id: update.id,
    // Re-mentioning a node with new defaults should not erase a value that was
    // explicitly set earlier, so each style field carries its own explicitness.
    label: if update.label_explicit {
      update.label
    } else {
      existing.label
    },
    label_explicit: existing.label_explicit || update.label_explicit,
    color: if update.color_explicit {
      update.color
    } else {
      existing.color
    },
    color_explicit: existing.color_explicit || update.color_explicit,
    fontcolor: if update.fontcolor_explicit {
      update.fontcolor
    } else {
      existing.fontcolor
    },
    fontcolor_explicit: existing.fontcolor_explicit || update.fontcolor_explicit,
    fillcolor: if update.fillcolor_explicit {
      update.fillcolor
    } else {
      existing.fillcolor
    },
    fillcolor_explicit: existing.fillcolor_explicit || update.fillcolor_explicit,
  }
}

///|
fn upsert_node(
  nodes : Map[String, NodeData],
  node_id : String,
  attrs : @parser.AttributeList?,
  label_explicit : Bool,
  color_explicit : Bool,
  fontcolor_explicit : Bool,
  fillcolor_explicit : Bool,
) -> Unit {
  let node_data = build_node_data(
    node_id, attrs, label_explicit, color_explicit, fontcolor_explicit, fillcolor_explicit,
  )
  match nodes.get(node_id) {
    Some(existing) => nodes.set(node_id, merge_node_data(existing, node_data))
    None => nodes.set(node_id, node_data)
  }
}

///|
fn ensure_node(
  nodes : Map[String, NodeData],
  node_id : String,
  attrs : @parser.AttributeList?,
) -> Unit {
  if not(nodes.contains(node_id)) {
    nodes.set(
      node_id,
      build_node_data(node_id, attrs, false, false, false, false),
    )
  }
}

///|
fn merge_attrs(
  defaults : @parser.AttributeList?,
  overrides : @parser.AttributeList?,
) -> @parser.AttributeList? {
  match (defaults, overrides) {
    (None, None) => None
    (Some(_), None) => defaults
    (None, Some(_)) => overrides
    (Some(d), Some(o)) => {
      let merged : Array[@parser.Attribute] = []
      // Defaults go first and explicit attrs go last so extract_attr's
      // last-match behavior gives node-local attrs precedence.
      for attr in d.attributes {
        merged.push(attr)
      }
      for attr in o.attributes {
        merged.push(attr)
      }
      Some({ attributes: merged })
    }
  }
}

///|
fn collect_edges(
  statements : Array[@parser.Statement],
  directed : Bool,
) -> Array[EdgeData] {
  let edges : Array[EdgeData] = []
  for stmt in statements {
    match stmt {
      @parser.EdgeStmt(start_node, edge_list, _attrs) => {
        let mut current = start_node.id
        for edge_pair in edge_list {
          let (edge_op, target_node) = edge_pair
          edges.push({ from: current, to: target_node.id })
          if not(directed) || edge_op == @parser.Undirected {
            edges.push({ from: target_node.id, to: current })
          }
          current = target_node.id
        }
      }
      @parser.Subgraph(subgraph) => {
        let subgraph_edges = collect_edges(subgraph.statements, directed)
        for edge in subgraph_edges {
          edges.push(edge)
        }
      }
      @parser.NodeStmt(_, _) => ()
      @parser.AttrStmt(_, _) => ()
      @parser.Assignment(_, _) => ()
    }
  }
  edges
}
