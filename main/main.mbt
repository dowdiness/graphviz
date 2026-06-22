///|
fn test_layout(name : String, dot : String) -> Unit {
  println("=== \{name} ===\n")
  match @parser.parse_dot(dot) {
    Ok(graph) => {
      let layout = @layout.compute_layout(graph)
      println("Layout Results:")
      println("  Nodes: \{layout.nodes.length()}")
      println("  Edges: \{layout.edges.length()}")
      println("  Layers: \{layout.layers.length()}")
      println("  Directed: \{layout.directed}")
      println("  Bounds: \{layout.bounds}\n")
      println("Node Positions:")
      layout.nodes.each(fn(id, node) {
        println(
          "  \{id}: layer=\{node.layer}, pos=(\{node.position.x}, \{node.position.y})",
        )
      })
      println("\nEdge Routes:")
      for edge in layout.edges {
        let rev = if edge.reversed { " (reversed)" } else { "" }
        println("  \{edge.from} -> \{edge.to}\{rev}")
      }

      // Save to files
      let safe_name = name.replace(old=" ", new="_")
      let svg_filename = "\{safe_name}.svg"
      let html_filename = "\{safe_name}.html"
      match @svg.save_svg(layout, svg_filename) {
        Ok(_) => println("\nSaved SVG to: \{svg_filename}")
        Err(e) => println("\nError saving SVG: \{e}")
      }
      match @svg.save_html(layout, html_filename, name) {
        Ok(_) => println("Saved HTML to: \{html_filename}")
        Err(e) => println("Error saving HTML: \{e}")
      }
      println("\nSVG Preview:")
      println("---")
      println(@svg.render_svg(layout))
      println("---\n")
    }
    Err(e) => println("Parse error at position \{e.position}: \{e.message}\n")
  }
}

///|
/// Parse DOT string and return Graph (for JavaScript FFI)
/// Returns empty string on parse error
pub fn parse_dot(dot_string : String) -> String {
  match @parser.parse_dot(dot_string) {
    Ok(graph) => @parser.format_graph(graph)
    Err(e) =>
      "{\"error\": \"Parse error at position \{e.position}: \{e.message}\"}"
  }
}

///|
/// Render DOT string to SVG (for JavaScript FFI)
/// Returns SVG string, or error message on parse failure
pub fn render_dot_to_svg(dot_string : String) -> String {
  match @parser.parse_dot(dot_string) {
    Ok(graph) => {
      let layout = @layout.compute_layout(graph)
      @svg.render_svg(layout)
    }
    Err(e) => "<!-- Parse error at position \{e.position}: \{e.message} -->"
  }
}

///|
fn main {
  // Test 1: Simple
  test_layout("Simple", "digraph { a -> b }")

  // Test 2: Automaton (from parser tests)
  let automaton =
    #|digraph {
    #|  0 -> 1
    #|  0 -> 2
    #|  2 -> 3
    #|  2 -> 4
    #|  3 -> 5
    #|  4 -> 6
    #|  4 -> 4
    #|  6 -> 7
    #|}
  test_layout("Automaton", automaton)
}
