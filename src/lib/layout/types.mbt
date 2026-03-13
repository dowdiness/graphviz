// Layout data structures for graph visualization

// Point and dimension primitives

///|
pub struct Point {
  x : Double
  y : Double
} derive(Eq, Show)

///|
pub struct Size {
  width : Double
  height : Double
} derive(Eq, Show)

// Bounding box for the entire graph

///|
pub struct Bounds {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Eq, Show)

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
} derive(Eq, Show)

// Edge with routing waypoints

///|
pub struct LayoutEdge {
  from : String // Source node ID
  to : String // Target node ID
  waypoints : Array[Point] // Polyline path (including endpoints)
  reversed : Bool // True if edge was reversed for cycle removal
} derive(Eq, Show)

// Complete graph layout result

///|
pub struct GraphLayout {
  nodes : Map[String, LayoutNode] // Node ID -> layout info
  edges : Array[LayoutEdge] // All edges with routing
  bounds : Bounds // Overall graph dimensions
  layers : Array[Array[String]] // Layer structure: layer index -> node IDs
  directed : Bool // Whether the graph is directed
} derive(Show)

// Immutable node data extracted from AST

///|
struct NodeData {
  id : String
  label : String
  label_explicit : Bool
  color : String?
  color_explicit : Bool
  fontcolor : String?
  fontcolor_explicit : Bool
  fillcolor : String?
  fillcolor_explicit : Bool
} derive(Show)

// Immutable edge data

///|
struct EdgeData {
  from : String
  to : String
} derive(Eq, Show)
