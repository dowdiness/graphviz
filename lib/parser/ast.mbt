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
  EOF // End of file
} derive(Eq)

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
} derive(Eq, Debug)

///|
pub impl Show for CompassPoint with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub(all) struct Port {
  mut id : String?
  mut compass : CompassPoint?
} derive(Eq, Debug)

///|
pub impl Show for Port with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub(all) struct NodeId {
  id : String
  port : Port?
} derive(Eq, Debug)

///|
pub(all) enum EdgeOp {
  Directed // ->
  Undirected // --
} derive(Eq, Debug)

///|
pub(all) struct Attribute {
  key : String
  value : String
} derive(Eq, Debug)

///|
pub(all) struct AttributeList {
  attributes : Array[Attribute]
} derive(Eq, Debug)

///|
pub impl Show for AttributeList with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub(all) enum AttrTarget {
  GraphAttr
  NodeAttr
  EdgeAttr
} derive(Eq, Debug)

///|
pub impl Show for AttrTarget with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub(all) enum Statement {
  NodeStmt(NodeId, AttributeList?)
  EdgeStmt(NodeId, Array[(EdgeOp, NodeId)], AttributeList?)
  AttrStmt(AttrTarget, AttributeList)
  Assignment(String, String)
  Subgraph(Subgraph)
} derive(Eq, Debug)

///|
pub(all) struct Subgraph {
  id : String?
  statements : Array[Statement]
} derive(Eq, Debug)

///|
pub(all) struct Graph {
  strict : Bool
  directed : Bool
  id : String?
  statements : Array[Statement]
} derive(Eq, Debug)

///|
pub(all) struct ParseError {
  message : String
  position : Int // UTF-16 code unit index
} derive(Debug)

// DOT language keywords — shared by lexer and formatter.

///|
fn is_dot_keyword(s : String) -> Bool {
  let normalized = s.to_lower()
  match normalized {
    "strict" | "graph" | "digraph" | "node" | "edge" | "subgraph" => true
    _ => false
  }
}

///|
pub extend AttrTarget with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AttrTarget with Eq::{equal, not_equal}

///|
pub extend AttrTarget with Show::{output, to_string}

///|
pub extend Attribute with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Attribute with Eq::{equal, not_equal}

///|
pub extend AttributeList with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AttributeList with Eq::{equal, not_equal}

///|
pub extend AttributeList with Show::{output, to_string}

///|
pub extend CompassPoint with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CompassPoint with Eq::{equal, not_equal}

///|
pub extend CompassPoint with Show::{output, to_string}

///|
pub extend EdgeOp with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend EdgeOp with Eq::{equal, not_equal}

///|
pub extend Graph with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Graph with Eq::{equal, not_equal}

///|
pub extend NodeId with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NodeId with Eq::{equal, not_equal}

///|
pub extend ParseError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Port with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Port with Eq::{equal, not_equal}

///|
pub extend Port with Show::{output, to_string}

///|
pub extend Statement with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Statement with Eq::{equal, not_equal}

///|
pub extend Subgraph with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Subgraph with Eq::{equal, not_equal}
