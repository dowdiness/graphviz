// Layout data structures for graph visualization

// Point and dimension primitives

///|
#derive(Eq, Debug)
pub struct Point {
  x : Double
  y : Double
}

///|
#derive(Eq, Debug)
pub struct Size {
  width : Double
  height : Double
}

// Bounding box for the entire graph

///|
#derive(Eq, Debug)
pub struct Bounds {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
pub impl Show for Bounds with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

// Positioned node with layout information

///|
#derive(Eq, Debug)
pub struct LayoutNode {
  id : String // Original node ID from AST
  label : String // Display label (defaults to id if no label attribute)
  position : Point // Top-left corner (x, y)
  size : Size // Node dimensions
  layer : Int32 // Vertical layer assignment (0 = top)
  order : Int32 // Horizontal position within layer
  color : String? // Per-node border color override
  fontcolor : String? // Per-node text color override
  fillcolor : String? // Per-node fill color override
}

// Edge with routing waypoints

///|
#derive(Eq, Debug)
pub struct LayoutEdge {
  from : String // Source node ID
  to : String // Target node ID
  waypoints : Array[Point] // Polyline path (including endpoints)
  reversed : Bool // True if edge was reversed for cycle removal
}

// Complete graph layout result

///|
#derive(Debug)
pub struct GraphLayout {
  nodes : Map[String, LayoutNode] // Node ID -> layout info
  edges : Array[LayoutEdge] // All edges with routing
  bounds : Bounds // Overall graph dimensions
  layers : Array[Array[String]] // Layer structure: layer index -> node IDs
  directed : Bool // Whether the graph is directed
}

// Immutable node data extracted from AST

///|
#derive(Debug)
struct NodeData {
  id : String
  label_attr : String?
  label : String
  color : String?
  fontcolor : String?
  fillcolor : String?
  explicit_attrs : @hashset.HashSet[String]
}

// Immutable edge data

///|
#derive(Eq, Debug)
struct EdgeData {
  from : String
  to : String
}

///|
pub extend Bounds with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Bounds with Eq::{equal, not_equal}

///|
pub extend Bounds with Show::{output, to_string}

///|
pub extend EdgeData with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend EdgeData with Eq::{equal, not_equal}

///|
pub extend GraphLayout with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend LayoutEdge with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend LayoutEdge with Eq::{equal, not_equal}

///|
pub extend LayoutNode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend LayoutNode with Eq::{equal, not_equal}

///|
pub extend NodeData with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Point with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Point with Eq::{equal, not_equal}

///|
pub extend Size with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Size with Eq::{equal, not_equal}
