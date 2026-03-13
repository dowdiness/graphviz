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
  let mut node_defaults : @parser.AttributeList? = None
  for stmt in statements {
    match stmt {
      @parser.AttrStmt("node", attr_list) => node_defaults = Some(attr_list)
      @parser.NodeStmt(node_id, attrs) => {
        let merged_attrs = merge_attrs(node_defaults, attrs)
        let label = extract_attr("label", merged_attrs).unwrap_or(node_id.id)
        let color = extract_attr("color", merged_attrs)
        let fontcolor = extract_attr("fontcolor", merged_attrs)
        let fillcolor = extract_attr("fillcolor", merged_attrs)
        match nodes.get(node_id.id) {
          Some(existing) =>
            nodes.set(node_id.id, {
              id: node_id.id,
              label: if label != node_id.id {
                label
              } else {
                existing.label
              },
              color: match color {
                Some(_) => color
                None => existing.color
              },
              fontcolor: match fontcolor {
                Some(_) => fontcolor
                None => existing.fontcolor
              },
              fillcolor: match fillcolor {
                Some(_) => fillcolor
                None => existing.fillcolor
              },
            })
          None =>
            nodes.set(node_id.id, {
              id: node_id.id,
              label,
              color,
              fontcolor,
              fillcolor,
            })
        }
      }
      @parser.EdgeStmt(start_node, edges, _attrs) => {
        if not(nodes.contains(start_node.id)) {
          let merged_attrs = merge_attrs(node_defaults, None)
          nodes.set(start_node.id, {
            id: start_node.id,
            label: extract_attr("label", merged_attrs).unwrap_or(start_node.id),
            color: extract_attr("color", merged_attrs),
            fontcolor: extract_attr("fontcolor", merged_attrs),
            fillcolor: extract_attr("fillcolor", merged_attrs),
          })
        }
        for edge_pair in edges {
          let (_edge_op, target_node) = edge_pair
          if not(nodes.contains(target_node.id)) {
            let merged_attrs = merge_attrs(node_defaults, None)
            nodes.set(target_node.id, {
              id: target_node.id,
              label: extract_attr("label", merged_attrs).unwrap_or(
                target_node.id,
              ),
              color: extract_attr("color", merged_attrs),
              fontcolor: extract_attr("fontcolor", merged_attrs),
              fillcolor: extract_attr("fillcolor", merged_attrs),
            })
          }
        }
      }
      @parser.Subgraph(subgraph) => {
        let subgraph_nodes = collect_nodes(subgraph.statements)
        subgraph_nodes.each(fn(id, node_data) {
          if not(nodes.contains(id)) {
            nodes.set(id, node_data)
          }
        })
      }
      @parser.AttrStmt(_, _) => ()
      @parser.Assignment(_, _) => ()
    }
  }
  nodes
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
