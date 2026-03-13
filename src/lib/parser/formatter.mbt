// DOT Formatter

///|
fn needs_quoting(s : String) -> Bool {
  let chars = s.to_array()
  if chars.length() == 0 {
    return true
  }
  if (match s {
      "strict" | "graph" | "digraph" | "node" | "edge" | "subgraph" => true
      _ => false
    }) {
    return true
  }
  let mut has_ascii_alpha = false
  for c in chars {
    if c.is_ascii_alphabetic() {
      has_ascii_alpha = true
    }
    if c.is_ascii_alphabetic() || c == '_' || c.is_numeric() {
      continue
    }
    if c == '.' && not(has_ascii_alpha) {
      continue
    }
    return true
  }
  if chars[0].is_numeric() && has_ascii_alpha {
    return true
  }
  false
}

///|
fn escape_and_quote(s : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  for c in s.to_array() {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      _ => buf.write_char(c)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
pub fn format_id(s : String) -> String {
  if needs_quoting(s) {
    escape_and_quote(s)
  } else {
    s
  }
}

// Format the AST back to DOT string

///|
pub fn format_graph(graph : Graph) -> String {
  let buf = StringBuilder::new()
  if graph.strict {
    buf.write_string("strict ")
  }
  buf.write_string(if graph.directed { "digraph" } else { "graph" })
  match graph.id {
    Some(id) => {
      buf.write_string(" ")
      buf.write_string(format_id(id))
    }
    None => ()
  }
  buf.write_string(" {\n")
  for stmt in graph.statements {
    buf.write_string(format_indent(1))
    buf.write_string(format_statement_with_indent(stmt, 1))
    buf.write_string(";\n")
  }
  buf.write_string("}\n")
  buf.to_string()
}

///|
fn format_node_id(node_id : NodeId) -> String {
  let mut result = format_id(node_id.id)
  match node_id.port {
    Some(port) =>
      match (port.id, port.compass) {
        (Some(port_id), Some(compass)) =>
          result = result +
            ":" +
            format_id(port_id) +
            ":" +
            format_compass(compass)
        (Some(port_id), None) => result = result + ":" + format_id(port_id)
        (None, Some(compass)) => result = result + ":" + format_compass(compass)
        (None, None) => result = result + ":"
      }
    None => ()
  }
  result
}

///|
fn format_indent(level : Int) -> String {
  "  ".repeat(level)
}

///|
fn format_statement_with_indent(stmt : Statement, indent_level : Int) -> String {
  match stmt {
    NodeStmt(node_id, attr_list) => {
      let mut result = format_node_id(node_id)
      match attr_list {
        Some(attrs) => result = result + " " + format_attr_list(attrs)
        None => ()
      }
      result
    }
    EdgeStmt(start_node, edges, attr_list) => {
      let mut result = loop (edges[:], format_node_id(start_node)) {
        ([], acc) => break acc
        ([(edge_op, node_id), .. rest], acc) => {
          let op_str = match edge_op {
            Directed => " -> "
            Undirected => " -- "
          }
          continue (rest, acc + op_str + format_node_id(node_id))
        }
      }
      match attr_list {
        Some(attrs) => result = result + " " + format_attr_list(attrs)
        None => ()
      }
      result
    }
    AttrStmt(attr_type, attr_list) =>
      attr_type + " " + format_attr_list(attr_list)
    Assignment(key, value) => format_id(key) + " = " + format_id(value)
    Subgraph(subgraph) => {
      let mut result = "subgraph"
      match subgraph.id {
        Some(id) => result = result + " " + format_id(id)
        None => ()
      }
      result = result + " {\n"
      for nested_stmt in subgraph.statements {
        result = result + format_indent(indent_level + 1)
        result = result +
          format_statement_with_indent(nested_stmt, indent_level + 1)
        result = result + ";\n"
      }
      result = result + format_indent(indent_level) + "}"
      result
    }
  }
}

///|
fn format_compass(compass : CompassPoint) -> String {
  match compass {
    N => "n"
    NE => "ne"
    E => "e"
    SE => "se"
    S => "s"
    SW => "sw"
    W => "w"
    NW => "nw"
    C => "c"
    Underscore => "_"
  }
}

///|
fn format_attr_list(attr_list : AttributeList) -> String {
  let mut result = "["
  let mut first = true
  for attr in attr_list.attributes {
    if not(first) {
      result = result + ", "
    }
    result = result + format_id(attr.key) + "=" + escape_and_quote(attr.value)
    first = false
  }
  result = result + "]"
  result
}
