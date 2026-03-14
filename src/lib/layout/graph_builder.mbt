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
      @parser.AttrStmt(@parser.NodeAttr, attr_list) =>
        node_defaults = merge_attrs(node_defaults, Some(attr_list))
      @parser.NodeStmt(node_id, attrs) => {
        let explicit = @hashset.HashSet::new()
        if extract_attr("label", attrs) is Some(_) {
          explicit.add("label")
        }
        if extract_attr("color", attrs) is Some(_) {
          explicit.add("color")
        }
        if extract_attr("fontcolor", attrs) is Some(_) {
          explicit.add("fontcolor")
        }
        if extract_attr("fillcolor", attrs) is Some(_) {
          explicit.add("fillcolor")
        }
        upsert_node(
          nodes,
          node_id.id,
          merge_attrs(node_defaults, attrs),
          explicit,
        )
      }
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
  explicit_attrs : @hashset.HashSet[String],
) -> NodeData {
  let label_attr = extract_attr("label", attrs)
  let label = label_attr.unwrap_or(node_id)
  let color = extract_attr("color", attrs)
  let fontcolor = extract_attr("fontcolor", attrs)
  let fillcolor = extract_attr("fillcolor", attrs)
  {
    id: node_id,
    label_attr,
    label,
    color,
    fontcolor,
    fillcolor,
    explicit_attrs,
  }
}

///|
fn merge_node_data(existing : NodeData, update : NodeData) -> NodeData {
  // Re-mentioning a node with new defaults should not erase a value that was
  // explicitly set earlier, so we track which attrs were set on the node itself.
  let merged_explicit = @hashset.HashSet::new()
  existing.explicit_attrs.each(fn(k) { merged_explicit.add(k) })
  update.explicit_attrs.each(fn(k) { merged_explicit.add(k) })
  fn pick(
    key : String,
    update_val : String?,
    existing_val : String?,
  ) -> String? {
    if update.explicit_attrs.contains(key) {
      update_val
    } else if existing.explicit_attrs.contains(key) {
      existing_val
    } else if update_val is Some(_) {
      update_val
    } else {
      existing_val
    }
  }
  let label_attr = pick("label", update.label_attr, existing.label_attr)
  {
    id: update.id,
    label_attr,
    label: label_attr.unwrap_or(update.id),
    color: pick("color", update.color, existing.color),
    fontcolor: pick("fontcolor", update.fontcolor, existing.fontcolor),
    fillcolor: pick("fillcolor", update.fillcolor, existing.fillcolor),
    explicit_attrs: merged_explicit,
  }
}

///|
fn upsert_node(
  nodes : Map[String, NodeData],
  node_id : String,
  attrs : @parser.AttributeList?,
  explicit_attrs : @hashset.HashSet[String],
) -> Unit {
  let node_data = build_node_data(node_id, attrs, explicit_attrs)
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
    nodes.set(node_id, build_node_data(node_id, attrs, @hashset.HashSet::new()))
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
