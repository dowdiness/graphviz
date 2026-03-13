// DOT Language Parser in MoonBit
// Based on the grammar from https://graphviz.org/doc/info/lang.html

// Specification of the DOT language grammar:

//      graph : [ strict ] (graph | digraph) [ ID ] '{' stmt_list '}'
//  stmt_list : [ stmt [ ';' ] stmt_list ]
//       stmt : node_stmt
//            | edge_stmt
//            | attr_stmt
//            | ID '=' ID
//            | subgraph
//  attr_stmt : (graph | node | edge) attr_list
//  attr_list : '[' [ a_list ] ']' [ attr_list ]
//     a_list : ID '=' ID [ (';' | ',') ] [ a_list ]
//  edge_stmt : (node_id | subgraph) edgeRHS [ attr_list ]
//    edgeRHS : edgeop (node_id | subgraph) [ edgeRHS ]
//  node_stmt : node_id [ attr_list ]
//    node_id : ID [ port ]
//       port : ':' ID [ ':' compass_pt ]
//            | ':' compass_pt
//   subgraph : [ subgraph [ ID ] ] '{' stmt_list '}'
// compass_pt : n | ne | e | se | s | sw | w | nw | c | _

// Token types for the DOT language

///|
priv enum Token {
  // Keywords
  Strict
  Graph
  Digraph
  Node
  Edge
  Subgraph

  // Identifiers and literals
  ID(String)
  LeftBrace

  // Operators and punctuation
  RightBrace // }
  LeftBracket // [
  RightBracket // ]
  Colon // :
  Semicolon // ;
  Comma // ,
  Equals // =
  Arrow // ->
  Line // --

  // Compass points
  CompassPt(String) // n, ne, e, se, s, sw, w, nw, c, _
  EOF // End of file
} derive(Eq, Show)

// AST node types

///|
pub(all) enum CompassPoint {
  N
  NE
  E
  SE
  S
  SW
  W
  NW
  C
  Underscore
} derive(Eq, Show)

///|
pub(all) struct Port {
  mut id : String?
  mut compass : CompassPoint?
} derive(Eq, Show)

///|
pub(all) struct NodeId {
  id : String
  port : Port?
} derive(Eq, Show)

///|
pub(all) enum EdgeOp {
  Directed // ->
  Undirected // --
} derive(Eq, Show)

///|
pub(all) struct Attribute {
  key : String
  value : String
} derive(Eq, Show)

///|
pub(all) struct AttributeList {
  attributes : Array[Attribute]
} derive(Eq, Show)

///|
pub(all) enum Statement {
  NodeStmt(NodeId, AttributeList?)
  EdgeStmt(NodeId, Array[(EdgeOp, NodeId)], AttributeList?)
  AttrStmt(String, AttributeList) // "graph", "node", or "edge"
  Assignment(String, String)
  Subgraph(Subgraph)
} derive(Eq, Show)

///|
pub(all) struct Subgraph {
  id : String?
  statements : Array[Statement]
} derive(Eq, Show)

///|
pub(all) struct Graph {
  strict : Bool
  directed : Bool
  id : String?
  statements : Array[Statement]
} derive(Eq, Show)

///|
pub(all) struct ParseError {
  message : String
  position : Int // UTF-16 code unit index
} derive(Show)
