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
  for stmt in statements {
    match stmt {
      @parser.NodeStmt(node_id, attrs) => {
        let label = extract_attr("label", attrs).or(node_id.id)
        let color = extract_attr("color", attrs)
        let fontcolor = extract_attr("fontcolor", attrs)
        let fillcolor = extract_attr("fillcolor", attrs)
        nodes.set(node_id.id, {
          id: node_id.id,
          label,
          color,
          fontcolor,
          fillcolor,
        })
      }
      @parser.EdgeStmt(start_node, edges, _attrs) => {
        if not(nodes.contains(start_node.id)) {
          nodes.set(start_node.id, {
            id: start_node.id,
            label: start_node.id,
            color: None,
            fontcolor: None,
            fillcolor: None,
          })
        }
        for edge_pair in edges {
          let (_edge_op, target_node) = edge_pair
          if not(nodes.contains(target_node.id)) {
            nodes.set(target_node.id, {
              id: target_node.id,
              label: target_node.id,
              color: None,
              fontcolor: None,
              fillcolor: None,
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
