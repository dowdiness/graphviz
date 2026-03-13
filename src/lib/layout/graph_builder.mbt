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
      for attr in attr_list.attributes {
        if attr.key == key {
          return Some(attr.value)
        }
      }
      None
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
        upsert_node(nodes, node_id.id, merge_attrs(node_defaults, attrs))
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
) -> NodeData {
  let label = extract_attr("label", attrs).unwrap_or(node_id)
  let color = extract_attr("color", attrs)
  let fontcolor = extract_attr("fontcolor", attrs)
  let fillcolor = extract_attr("fillcolor", attrs)
  { id: node_id, label, color, fontcolor, fillcolor }
}

///|
fn merge_node_data(existing : NodeData, update : NodeData) -> NodeData {
  {
    id: update.id,
    label: if update.label != update.id {
      update.label
    } else {
      existing.label
    },
    color: match update.color {
      Some(_) => update.color
      None => existing.color
    },
    fontcolor: match update.fontcolor {
      Some(_) => update.fontcolor
      None => existing.fontcolor
    },
    fillcolor: match update.fillcolor {
      Some(_) => update.fillcolor
      None => existing.fillcolor
    },
  }
}

///|
fn upsert_node(
  nodes : Map[String, NodeData],
  node_id : String,
  attrs : @parser.AttributeList?,
) -> Unit {
  let node_data = build_node_data(node_id, attrs)
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
    nodes.set(node_id, build_node_data(node_id, attrs))
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
      for attr in o.attributes {
        merged.push(attr)
      }
      for attr in d.attributes {
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
