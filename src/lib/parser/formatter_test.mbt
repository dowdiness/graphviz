// Formatter Tests

///|
test "format_simple_graph" {
  let input = "graph { a }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      assert_true(formatted.contains("graph"))
      assert_true(formatted.contains("a"))
    }
    Err(_) => abort("Failed to parse simple graph")
  }
}

///|
test "format_digraph" {
  let input = "digraph { a -> b }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      assert_true(formatted.contains("digraph"))
    }
    Err(_) => abort("Failed to parse digraph")
  }
}

///|
test "format_strict_graph" {
  let input = "strict graph { a }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      assert_true(formatted.contains("strict"))
    }
    Err(_) => abort("Failed to parse strict graph")
  }
}

///|
test "format_preserves_non_bmp_identifier" {
  let graph : Graph = {
    strict: false,
    directed: true,
    id: Some("🚀"),
    statements: [],
  }
  let formatted = format_graph(graph)
  assert_true(formatted.contains("🚀"))
}

///|
test "format_preserves_non_bmp_attribute_value" {
  let graph : Graph = {
    strict: false,
    directed: true,
    id: None,
    statements: [
      NodeStmt(
        { id: "a", port: None },
        Some({ attributes: [{ key: "label", value: "go 🚀" }] }),
      ),
    ],
  }
  let formatted = format_graph(graph)
  assert_true(formatted.contains("go 🚀"))
}

///|
test "format_id_quotes_keywords_and_digit_leading_mixed_ids" {
  assert_eq(format_id("graph"), "\"graph\"")
  assert_eq(format_id("strict"), "\"strict\"")
  assert_eq(format_id("1foo"), "\"1foo\"")
  assert_eq(format_id("123"), "123")
}

///|
test "format_graph_roundtrips_dotted_ids" {
  let graph : Graph = {
    strict: false,
    directed: true,
    id: None,
    statements: [
      NodeStmt({ id: ".5", port: None }, None),
      NodeStmt({ id: "1.", port: None }, None),
      NodeStmt({ id: ".foo", port: None }, None),
    ],
  }
  let formatted = format_graph(graph)
  match parse_dot(formatted) {
    Ok(parsed) => {
      assert_eq(parsed.statements.length(), 3)
      match parsed.statements[0] {
        NodeStmt(node_id, _) => assert_eq(node_id.id, ".5")
        _ => abort("Expected first roundtripped statement to be NodeStmt")
      }
      match parsed.statements[1] {
        NodeStmt(node_id, _) => assert_eq(node_id.id, "1.")
        _ => abort("Expected second roundtripped statement to be NodeStmt")
      }
      match parsed.statements[2] {
        NodeStmt(node_id, _) => assert_eq(node_id.id, ".foo")
        _ => abort("Expected third roundtripped statement to be NodeStmt")
      }
    }
    Err(_) => abort("Failed to roundtrip dotted ids")
  }
}

///|
test "format_subgraph_renders_nested_statements" {
  let input = "digraph { subgraph cluster_0 { a; b -> c } }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      assert_true(formatted.contains("subgraph cluster_0 {"))
      assert_true(formatted.contains("a;"))
      assert_true(formatted.contains("b -> c;"))
      assert_true(not(formatted.contains("{ ... }")))
    }
    Err(_) => abort("Failed to parse graph with subgraph")
  }
}

///|
test "format_attr_list_quotes_keyword_attribute_keys" {
  let graph : Graph = {
    strict: false,
    directed: true,
    id: None,
    statements: [
      NodeStmt(
        { id: "a", port: None },
        Some({ attributes: [{ key: "graph", value: "x" }] }),
      ),
    ],
  }
  let formatted = format_graph(graph)
  assert_true(formatted.contains("\"graph\"=\"x\""))
}

///|
test "format_edge_stmt_preserves_ports_and_compass" {
  let input = "digraph { a:out:ne -> b:in:sw }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      assert_true(formatted.contains("a:out:ne -> b:in:sw"))
    }
    Err(_) => abort("Failed to parse graph with ported edge")
  }
}

///|
test "format_edge_stmt_preserves_compass_only_ports" {
  let input = "digraph { a:n -> b:s }"
  match parse_dot(input) {
    Ok(graph) => {
      let formatted = format_graph(graph)
      assert_true(formatted.contains("a:n -> b:s"))
      assert_true(not(formatted.contains("a::n")))
      assert_true(not(formatted.contains("b::s")))
      assert_true(parse_dot(formatted) is Ok(_))
    }
    Err(_) => abort("Failed to parse graph with compass-only ports")
  }
}
