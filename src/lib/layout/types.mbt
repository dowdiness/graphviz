// Layout data structures for graph visualization

// Point and dimension primitives

///|
pub struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub struct Size {
  width : Double
  height : Double
} derive(Eq, Debug)

// Bounding box for the entire graph

///|
pub struct Bounds {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Eq, Debug)

///|
pub impl Show for Bounds with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

// Positioned node with layout information

///|
pub struct LayoutNode {
  id : String // Original node ID from AST
  label : String // Display label (defaults to id if no label attribute)
  position : Point // Top-left corner (x, y)
  size : Size // Node dimensions
  layer : Int // Vertical layer assignment (0 = top)
  order : Int // Horizontal position within layer
  color : String? // Per-node border color override
  fontcolor : String? // Per-node text color override
  fillcolor : String? // Per-node fill color override
} derive(Eq, Debug)

// Edge with routing waypoints

///|
pub struct LayoutEdge {
  from : String // Source node ID
  to : String // Target node ID
  waypoints : Array[Point] // Polyline path (including endpoints)
  reversed : Bool // True if edge was reversed for cycle removal
} derive(Eq, Debug)

// Complete graph layout result

///|
pub struct GraphLayout {
  nodes : Map[String, LayoutNode] // Node ID -> layout info
  edges : Array[LayoutEdge] // All edges with routing
  bounds : Bounds // Overall graph dimensions
  layers : Array[Array[String]] // Layer structure: layer index -> node IDs
  directed : Bool // Whether the graph is directed
} derive(Debug)

// Immutable node data extracted from AST

///|
struct NodeData {
  id : String
  label_attr : String?
  label : String
  color : String?
  fontcolor : String?
  fillcolor : String?
  explicit_attrs : @hashset.HashSet[String]
} derive(Debug)

// Immutable edge data

///|
struct EdgeData {
  from : String
  to : String
} derive(Eq, Debug)
