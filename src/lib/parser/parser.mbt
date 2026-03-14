// Parser implementation

///|
priv struct Parser {
  lexer : Lexer
  mut current_token : Token
  mut current_token_start : Int
  pending_statements : Array[Statement]
}

///|
fn Parser::new(input : String) -> Parser {
  let lexer = Lexer::new(input)
  let current_token = lexer.next_token()
  {
    lexer,
    current_token,
    current_token_start: lexer.token_start,
    pending_statements: [],
  }
}

///|
fn Parser::advance_token(self : Parser) -> Unit {
  self.current_token = self.lexer.next_token()
  self.current_token_start = self.lexer.token_start
}

///|
fn Parser::peek_token(self : Parser) -> Token {
  let lexer : Lexer = {
    input: self.lexer.input,
    position: self.lexer.position,
    current_char: self.lexer.current_char,
    token_start: self.lexer.token_start,
  }
  lexer.next_token()
}

///|
fn Parser::eat(self : Parser, expected : Token) -> Bool {
  match (self.current_token, expected) {
    (ID(_), ID(_)) => {
      self.advance_token()
      true
    }
    (actual, expected) if actual == expected => {
      self.advance_token()
      true
    }
    _ => false
  }
}

///|
fn is_compass_point(s : String) -> Bool {
  match s {
    "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw" | "c" | "_" => true
    _ => false
  }
}

///|
fn parse_compass_point(compass_str : String) -> CompassPoint {
  match compass_str {
    "n" => N
    "ne" => NE
    "e" => E
    "se" => SE
    "s" => S
    "sw" => SW
    "w" => W
    "nw" => NW
    "c" => C
    "_" => Underscore
    _ => C
  } // Default fallback
}

///|
fn Parser::parse_port(self : Parser) -> Port? {
  if not(self.eat(Colon)) {
    return None
  }
  let port = { id: None, compass: None }
  let first = match self.current_token {
    ID(id) => id
    _ => return None
  }
  ignore(self.eat(ID("")))
  if self.eat(Colon) {
    match self.current_token {
      ID(compass_str) if is_compass_point(compass_str) => {
        port.id = Some(first)
        port.compass = Some(parse_compass_point(compass_str))
        ignore(self.eat(ID("")))
      }
      _ => return None
    }
  } else if is_compass_point(first) {
    port.compass = Some(parse_compass_point(first))
  } else {
    port.id = Some(first)
  }
  Some(port)
}

///|
fn Parser::parse_node_id(self : Parser) -> NodeId? {
  match self.current_token {
    ID(id) => {
      ignore(self.eat(ID("")))
      let port = match self.current_token {
        Colon =>
          match self.parse_port() {
            Some(port) => Some(port)
            None => return None
          }
        _ => None
      }
      Some({ id, port })
    }
    _ => None
  }
}

///|
fn push_unique_node_id(node_ids : Array[NodeId], node_id : NodeId) -> Unit {
  for existing in node_ids {
    if existing == node_id {
      return
    }
  }
  node_ids.push(node_id)
}

///|
fn collect_node_ids_from_statement(
  stmt : Statement,
  node_ids : Array[NodeId],
) -> Unit {
  match stmt {
    NodeStmt(node_id, _) => push_unique_node_id(node_ids, node_id)
    EdgeStmt(start, edges, _) => {
      push_unique_node_id(node_ids, start)
      for edge in edges {
        let (_, target) = edge
        push_unique_node_id(node_ids, target)
      }
    }
    Subgraph(nested) => collect_node_ids_from_subgraph(nested, node_ids)
    _ => ()
  }
}

///|
fn collect_node_ids_from_subgraph(
  subgraph : Subgraph,
  node_ids : Array[NodeId],
) -> Unit {
  for stmt in subgraph.statements {
    collect_node_ids_from_statement(stmt, node_ids)
  }
}

///|
fn node_ids_in_subgraph(subgraph : Subgraph) -> Array[NodeId] {
  let node_ids = []
  collect_node_ids_from_subgraph(subgraph, node_ids)
  node_ids
}

///|
priv struct EdgeEndpoint {
  node_ids : Array[NodeId]
  preserved_subgraph : Subgraph?
}

///|
fn make_subgraph_endpoint(subgraph : Subgraph) -> EdgeEndpoint {
  {
    node_ids: node_ids_in_subgraph(subgraph),
    preserved_subgraph: if subgraph_requires_preservation(subgraph) {
      Some(subgraph)
    } else {
      None
    },
  }
}

///|
fn Parser::parse_edge_endpoint(self : Parser) -> EdgeEndpoint? {
  match self.parse_node_id() {
    Some(node_id) => Some({ node_ids: [node_id], preserved_subgraph: None })
    None =>
      match self.parse_subgraph() {
        Some(subgraph) => Some(make_subgraph_endpoint(subgraph))
        None => None
      }
  }
}

///|
fn Parser::parse_attribute(self : Parser) -> Attribute? {
  match self.current_token {
    ID(key) if self.peek_token() == Equals => {
      ignore(self.eat(ID("")))
      ignore(self.eat(Equals))
      match self.current_token {
        ID(value) => {
          ignore(self.eat(ID("")))
          Some({ key, value })
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn Parser::parse_a_list(self : Parser) -> Array[Attribute] {
  let attributes = []
  while true {
    match self.parse_attribute() {
      Some(attr) => {
        attributes.push(attr)
        match self.current_token {
          Semicolon | Comma => ignore(self.eat(self.current_token))
          _ => ()
        }
      }
      None => break
    }
  }
  attributes
}

///|
fn Parser::parse_attr_list(self : Parser) -> AttributeList? {
  if not(self.eat(LeftBracket)) {
    return None
  }
  let attributes = self.parse_a_list()
  if not(self.eat(RightBracket)) {
    return None
  }
  let attr_list = { attributes, }

  // Handle multiple attribute lists
  match self.parse_attr_list() {
    Some(next_attr_list) =>
      attr_list.attributes.append(next_attr_list.attributes)
    None => ()
  }
  Some(attr_list)
}

///|
priv enum EdgeRhsParseResult {
  NoEdgeOp
  Parsed(Array[(EdgeOp, EdgeEndpoint)])
  Malformed
}

///|
fn Parser::parse_edge_rhs(self : Parser) -> EdgeRhsParseResult {
  let edges = []
  while true {
    let edge_op = match self.current_token {
      Arrow => {
        ignore(self.eat(Arrow))
        Directed
      }
      Line => {
        ignore(self.eat(Line))
        Undirected
      }
      _ => break
    }
    match self.parse_edge_endpoint() {
      Some(endpoint) => edges.push((edge_op, endpoint))
      None => return Malformed
    }
  }
  if edges.is_empty() {
    NoEdgeOp
  } else {
    Parsed(edges)
  }
}

///|
fn expand_edge_statements(
  start_nodes : Array[NodeId],
  edge_chain : Array[(EdgeOp, EdgeEndpoint)],
  attr_list : AttributeList?,
) -> Array[Statement] {
  let expanded = []
  let mut current_sources = start_nodes
  for edge_step in edge_chain {
    let (edge_op, endpoint) = edge_step
    let targets = endpoint.node_ids
    for source in current_sources {
      for target in targets {
        expanded.push(EdgeStmt(source, [(edge_op, target)], attr_list))
      }
    }
    current_sources = targets
  }
  expanded
}

///|
fn collect_preserved_subgraph_statements(
  edge_chain : Array[(EdgeOp, EdgeEndpoint)],
) -> Array[Statement] {
  let statements = []
  for edge_step in edge_chain {
    let (_, endpoint) = edge_step
    match endpoint.preserved_subgraph {
      Some(subgraph) => statements.push(Statement::Subgraph(subgraph))
      None => ()
    }
  }
  statements
}

///|
fn statement_requires_subgraph_preservation(stmt : Statement) -> Bool {
  match stmt {
    NodeStmt(_, Some(_)) => true
    EdgeStmt(_, _, _) => true
    AttrStmt(_, _) => true
    Assignment(_, _) => true
    Subgraph(subgraph) => subgraph_requires_preservation(subgraph)
    NodeStmt(_, None) => false
  }
}

///|
fn subgraph_requires_preservation(subgraph : Subgraph) -> Bool {
  for stmt in subgraph.statements {
    if statement_requires_subgraph_preservation(stmt) {
      return true
    }
  }
  false
}

///|
fn Parser::emit_expanded_statements(
  self : Parser,
  statements : Array[Statement],
) -> Statement? {
  if statements.is_empty() {
    loop self.current_token {
      Semicolon => {
        self.eat(Semicolon) |> ignore
        continue self.current_token
      }
      _ => break
    }
    return self.parse_statement()
  }
  for i = statements.length() - 1; i > 0; i = i - 1 {
    self.pending_statements.push(statements[i])
  }
  Some(statements[0])
}

///|
fn Parser::parse_statement(self : Parser) -> Statement? {
  match self.pending_statements.pop() {
    Some(stmt) => return Some(stmt)
    None => ()
  }

  match self.current_token {
    // Keep these as separate arms rather than rematching current_token inside
    // a grouped branch so the compiler can see the match is exhaustive.
    Graph => {
      ignore(self.eat(Graph))
      match self.parse_attr_list() {
        Some(attr_list) => Some(AttrStmt("graph", attr_list))
        None => None
      }
    }
    Node => {
      ignore(self.eat(Node))
      match self.parse_attr_list() {
        Some(attr_list) => Some(AttrStmt("node", attr_list))
        None => None
      }
    }
    Edge => {
      ignore(self.eat(Edge))
      match self.parse_attr_list() {
        Some(attr_list) => Some(AttrStmt("edge", attr_list))
        None => None
      }
    }

    // Subgraph (explicit or anonymous)
    Subgraph | LeftBrace =>
      match self.parse_subgraph() {
        Some(subgraph) =>
          match self.parse_edge_rhs() {
            Parsed(edge_chain) => {
              let start_endpoint = make_subgraph_endpoint(subgraph)
              let attr_list = self.parse_attr_list()
              let statements = []
              match start_endpoint.preserved_subgraph {
                Some(subgraph) => statements.push(Statement::Subgraph(subgraph))
                None => ()
              }
              let preserved_rhs_subgraphs = collect_preserved_subgraph_statements(
                edge_chain,
              )
              for stmt in preserved_rhs_subgraphs {
                statements.push(stmt)
              }
              let expanded = expand_edge_statements(
                start_endpoint.node_ids,
                edge_chain,
                attr_list,
              )
              for stmt in expanded {
                statements.push(stmt)
              }
              self.emit_expanded_statements(statements)
            }
            NoEdgeOp => Some(Subgraph(subgraph))
            Malformed => None
          }
        None => None
      }

    // Unhandled tokens
    Digraph
    | Strict
    | RightBrace
    | LeftBracket
    | RightBracket
    | Semicolon
    | Comma
    | Equals
    | CompassPt(_)
    | Arrow
    | Colon
    | Line
    | EOF => None
    ID(_) =>
      match self.parse_node_id() {
        Some(node_id) =>
          // Check if this is an edge or node statement
          match self.parse_edge_rhs() {
            Parsed(edge_chain) => {
              let attr_list = self.parse_attr_list()
              let statements = collect_preserved_subgraph_statements(edge_chain)
              let expanded = expand_edge_statements(
                [node_id],
                edge_chain,
                attr_list,
              )
              for stmt in expanded {
                statements.push(stmt)
              }
              self.emit_expanded_statements(statements)
            }
            NoEdgeOp =>
              // Check for assignment
              match node_id.port {
                Some(_) => {
                  // Node statement with port
                  let attr_list = self.parse_attr_list()
                  Some(NodeStmt(node_id, attr_list))
                }
                None =>
                  match self.current_token {
                    Equals => {
                      self.eat(Equals) |> ignore
                      match self.current_token {
                        ID(value) => {
                          self.eat(ID("")) |> ignore
                          Some(Assignment(node_id.id, value))
                        }
                        _ => None
                      }
                    }
                    _ => {
                      // Node statement
                      let attr_list = self.parse_attr_list()
                      Some(NodeStmt(node_id, attr_list))
                    }
                  }
              }
            Malformed => None
          }
        None => None
      }
  }
}

///|
fn Parser::parse_stmt_list(self : Parser) -> Array[Statement] {
  let statements = []
  while true {
    // Skip leading/repeated semicolons
    loop self.current_token {
      Semicolon => {
        self.eat(Semicolon) |> ignore
        continue self.current_token
      }
      _ => break
    }
    match self.parse_statement() {
      Some(stmt) => statements.push(stmt)
      None => break
    }
  }
  statements
}

///|
fn Parser::parse_subgraph(self : Parser) -> Subgraph? {
  // Optional "subgraph" keyword
  let id = loop (self.current_token, None) {
    (Subgraph, id) => {
      self.eat(Subgraph) |> ignore
      // Optional ID after subgraph
      match self.current_token {
        ID(sub_id) => {
          self.eat(ID("")) |> ignore
          continue (self.current_token, Some(sub_id))
        }
        _ => continue (self.current_token, id)
      }
    }
    (_, id) => break id
  }
  if (self.eat(LeftBrace) |> not) {
    return None
  }
  let statements = self.parse_stmt_list()
  if (self.eat(RightBrace) |> not) {
    return None
  }
  Some({ id, statements })
}

// graph : [ strict ] (graph | digraph) [ ID ] '{' stmt_list '}'

///|
fn Parser::parse_graph(self : Parser) -> Graph? {
  // Optional "strict" [ strict ]
  let strict = match self.current_token {
    Strict => {
      self.eat(Strict) |> ignore
      true
    }
    _ => false
  }

  // "graph" or "digraph" (graph | digraph)
  let directed = match self.current_token {
    Graph => {
      self.eat(Graph) |> ignore
      false
    }
    Digraph => {
      self.eat(Digraph) |> ignore
      true
    }
    _ => return None
  }

  // Optional ID [ ID ]
  let id = match self.current_token {
    ID(graph_id) => {
      self.eat(ID("")) |> ignore
      Some(graph_id)
    }
    _ => None
  }

  // '{'
  if not(self.eat(LeftBrace)) {
    return None
  }

  // statements list stmt_list '}'
  let statements = self.parse_stmt_list()

  // '}'
  if not(self.eat(RightBrace)) {
    return None
  }
  Some({ strict, directed, id, statements })
}

// Public API

///|
pub fn parse_dot(input : String) -> Result[Graph, ParseError] {
  let parser = Parser::new(input)
  match parser.parse_graph() {
    Some(graph) =>
      match parser.current_token {
        EOF => Ok(graph)
        _ =>
          Err({
            message: "unexpected tokens after graph",
            position: parser.current_token_start,
          })
      }
    None =>
      Err({
        message: "failed to parse graph",
        position: parser.current_token_start,
      })
  }
}

///|
pub fn parse_attributes(input : String) -> Array[Attribute] {
  if input == "" {
    return []
  }
  let parser = Parser::new("[" + input + "]")
  match parser.parse_attr_list() {
    Some(attr_list) if parser.current_token == EOF => attr_list.attributes
    _ => []
  }
}
