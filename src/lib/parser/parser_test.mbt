// Comprehensive DOT Parser Tests

// Basic graph parsing tests

///|
test "parse_simple_undirected_graph" {
  let input = "graph { }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.strict, false)
      assert_eq(graph.directed, false)
      assert_eq(graph.id, None)
      assert_eq(graph.statements.length(), 0)
    }
    Err(_) => abort("Failed to parse simple graph")
  }
}

///|
test "parse_simple_directed_graph" {
  let input = "digraph { }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.strict, false)
      assert_eq(graph.directed, true)
      assert_eq(graph.id, None)
      assert_eq(graph.statements.length(), 0)
    }
    Err(_) => abort("Failed to parse simple digraph")
  }
}

///|
test "parse_graph_with_id" {
  let input = "graph MyGraph { }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.id, Some("MyGraph"))
      assert_eq(graph.directed, false)
      assert_eq(graph.statements.length(), 0)
    }
    Err(_) => abort("Failed to parse graph with id")
  }
}

///|
test "parse_strict_graph" {
  let input = "strict graph { }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.strict, true)
      assert_eq(graph.directed, false)
    }
    Err(_) => abort("Failed to parse strict graph")
  }
}

///|
test "parse_strict_digraph_with_id" {
  let input = "strict digraph G { }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.strict, true)
      assert_eq(graph.directed, true)
      assert_eq(graph.id, Some("G"))
    }
    Err(_) => abort("Failed to parse strict digraph with id")
  }
}

// Node statement tests

///|
test "parse_simple_node" {
  let input = "graph { a }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        NodeStmt(node_id, attr_list) => {
          assert_eq(node_id.id, "a")
          assert_eq(node_id.port, None)
          assert_eq(attr_list, None)
        }
        _ => abort("Expected NodeStmt")
      }
    }
    Err(_) => abort("Failed to parse node")
  }
}

///|
test "parse_node_with_attributes" {
  let input = "graph { a [color=red] }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        NodeStmt(node_id, attr_list) => {
          assert_eq(node_id.id, "a")
          match attr_list {
            Some(attrs) => {
              assert_eq(attrs.attributes.length(), 1)
              assert_eq(attrs.attributes[0].key, "color")
              assert_eq(attrs.attributes[0].value, "red")
            }
            None => abort("Expected attribute list")
          }
        }
        _ => abort("Expected NodeStmt")
      }
    }
    Err(_) => abort("Failed to parse node with attributes")
  }
}

///|
test "parse_node_with_multiple_attributes" {
  let input = "graph { a [color=red, shape=box, style=filled] }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        NodeStmt(_, attr_list) =>
          match attr_list {
            Some(attrs) => assert_eq(attrs.attributes.length(), 3)
            None => abort("Expected attribute list")
          }
        _ => abort("Expected NodeStmt")
      }
    }
    Err(_) => abort("Failed to parse node with multiple attributes")
  }
}

// Edge statement tests

///|
test "parse_simple_undirected_edge" {
  let input = "graph { a -- b }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        EdgeStmt(start, edges, attr_list) => {
          assert_eq(start.id, "a")
          assert_eq(edges.length(), 1)
          assert_eq(attr_list, None)
        }
        _ => abort("Expected EdgeStmt")
      }
    }
    Err(_) => abort("Failed to parse undirected edge")
  }
}

///|
test "parse_simple_directed_edge" {
  let input = "digraph { a -> b }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        EdgeStmt(start, edges, _) => {
          assert_eq(start.id, "a")
          assert_eq(edges.length(), 1)
        }
        _ => abort("Expected EdgeStmt")
      }
    }
    Err(_) => abort("Failed to parse directed edge")
  }
}

///|
test "parse_edge_with_attributes" {
  let input = "digraph { a -> b [color=blue, weight=2] }"
  match parse_dot(input) {
    Ok(graph) =>
      match graph.statements[0] {
        EdgeStmt(_, _, attr_list) =>
          match attr_list {
            Some(attrs) => assert_eq(attrs.attributes.length(), 2)
            None => abort("Expected attribute list")
          }
        _ => abort("Expected EdgeStmt")
      }
    Err(_) => abort("Failed to parse edge with attributes")
  }
}

///|
test "parse_edge_chain" {
  let input = "digraph { a -> b; b -> c }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 2)
      match graph.statements[0] {
        EdgeStmt(start, edges, _) => {
          assert_eq(start.id, "a")
          assert_eq(edges.length(), 1)
        }
        _ => abort("Expected EdgeStmt")
      }
    }
    Err(_) => abort("Failed to parse edge chain")
  }
}

// Port specification tests

///|
test "parse_node_with_port" {
  let input = "digraph { a:port1 }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        NodeStmt(node_id, _) => {
          assert_eq(node_id.id, "a")
          match node_id.port {
            Some(port) => {
              assert_eq(port.id, Some("port1"))
              assert_eq(port.compass, None)
            }
            None => abort("Expected port")
          }
        }
        _ => abort("Expected NodeStmt")
      }
    }
    Err(_) => abort("Failed to parse node with port")
  }
}

///|
test "parse_node_with_port_and_compass" {
  let input = "digraph { a:port:ne }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        NodeStmt(node_id, _) =>
          match node_id.port {
            Some(port) => {
              assert_eq(port.id, Some("port"))
              match port.compass {
                Some(compass) => assert_eq(compass, NE)
                None => abort("Expected compass point")
              }
            }
            None => abort("Expected port")
          }
        _ => abort("Expected NodeStmt")
      }
    }
    Err(_) => abort("Failed to parse node with port and compass")
  }
}

///|
test "parse_edge_with_ports" {
  let input = "digraph { a:out -> b:in }"
  match parse_dot(input) {
    Ok(graph) =>
      match graph.statements[0] {
        EdgeStmt(start, _edges, _) => {
          assert_eq(start.id, "a")
          match start.port {
            Some(port) => assert_eq(port.id, Some("out"))
            None => abort("Expected port on start node")
          }
        }
        _ => abort("Expected EdgeStmt")
      }
    Err(_) => abort("Failed to parse edge with ports")
  }
}

// Compass point tests

///|
test "parse_all_compass_points" {
  let compass_tests = [
    ("n", @parser.N),
    ("ne", @parser.NE),
    ("e", @parser.E),
    ("se", @parser.SE),
    ("s", @parser.S),
    ("sw", @parser.SW),
    ("w", @parser.W),
    ("nw", @parser.NW),
    ("c", @parser.C),
    ("_", @parser.Underscore),
  ]
  for point in compass_tests {
    let (name, expected) = point
    let input = "digraph { a:p:" + name + " }"
    match parse_dot(input) {
      Ok(graph) =>
        match graph.statements[0] {
          NodeStmt(node_id, _) =>
            match node_id.port {
              Some(port) => assert_eq(port.compass, Some(expected))
              None => abort("Expected port")
            }
          _ => abort("Expected NodeStmt")
        }
      Err(_) => abort("Failed to parse compass point " + name)
    }
  }
}

// Attribute statement tests

///|
test "parse_graph_attribute" {
  let input = "digraph { graph [rankdir=LR] }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        AttrStmt(attr_target, attr_list) => {
          assert_eq(attr_target, GraphAttr)
          assert_eq(attr_list.attributes.length(), 1)
        }
        _ => abort("Expected AttrStmt")
      }
    }
    Err(_) => abort("Failed to parse graph attribute")
  }
}

///|
test "parse_node_attribute" {
  let input = "digraph { node [shape=box, style=filled] }"
  match parse_dot(input) {
    Ok(graph) =>
      match graph.statements[0] {
        AttrStmt(attr_target, attr_list) => {
          assert_eq(attr_target, NodeAttr)
          assert_eq(attr_list.attributes.length(), 2)
        }
        _ => abort("Expected AttrStmt")
      }
    Err(_) => abort("Failed to parse node attribute")
  }
}

///|
test "parse_edge_attribute" {
  let input = "digraph { edge [color=red, penwidth=2] }"
  match parse_dot(input) {
    Ok(graph) =>
      match graph.statements[0] {
        AttrStmt(attr_target, attr_list) => {
          assert_eq(attr_target, EdgeAttr)
          assert_eq(attr_list.attributes.length(), 2)
        }
        _ => abort("Expected AttrStmt")
      }
    Err(_) => abort("Failed to parse edge attribute")
  }
}

// Assignment statement tests

///|
test "parse_assignment" {
  let input = "digraph { rankdir = LR }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        Assignment(key, value) => {
          assert_eq(key, "rankdir")
          assert_eq(value, "LR")
        }
        _ => abort("Expected Assignment")
      }
    }
    Err(_) => abort("Failed to parse assignment")
  }
}

// Subgraph tests

///|
test "parse_subgraph" {
  let input = "digraph { subgraph { a } }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        Subgraph(subgraph) => {
          assert_eq(subgraph.id, None)
          assert_eq(subgraph.statements.length(), 1)
        }
        _ => abort("Expected Subgraph")
      }
    }
    Err(_) => abort("Failed to parse subgraph")
  }
}

///|
test "parse_named_subgraph" {
  let input = "digraph { subgraph cluster_0 { a } }"
  match parse_dot(input) {
    Ok(graph) =>
      match graph.statements[0] {
        Subgraph(subgraph) => {
          assert_eq(subgraph.id, Some("cluster_0"))
          assert_eq(subgraph.statements.length(), 1)
        }
        _ => abort("Expected Subgraph")
      }
    Err(_) => abort("Failed to parse named subgraph")
  }
}

///|
test "parse_nested_subgraphs" {
  let input = "digraph { subgraph { subgraph { a } } }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 1)
      match graph.statements[0] {
        Subgraph(outer) => {
          assert_eq(outer.statements.length(), 1)
          match outer.statements[0] {
            Subgraph(inner) => assert_eq(inner.statements.length(), 1)
            _ => abort("Expected nested subgraph")
          }
        }
        _ => abort("Expected Subgraph")
      }
    }
    Err(_) => abort("Failed to parse nested subgraphs")
  }
}

// Complex graph tests

///|
test "parse_complex_digraph" {
  let input =
    #|digraph G {
    #|  graph [rankdir=LR];
    #|  node [shape=box];
    #|  a [color=red];
    #|  b [color=blue];
    #|  a -> b [label=edge1];
    #|  b -> c;
    #|}
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.id, Some("G"))
      assert_eq(graph.directed, true)
      assert_eq(graph.statements.length(), 6)
    }
    Err(_) => abort("Failed to parse complex digraph")
  }
}

///|
test "parse_graph_with_multiple_edges" {
  let input = "graph { a -- b; b -- c; c -- d }"
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 3)
    Err(_) => abort("Failed to parse multiple edges")
  }
}

///|
test "parse_optional_semicolons" {
  let input = "digraph { a b c }"
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 3)
    Err(_) => abort("Failed to parse optional semicolons")
  }
}

///|
test "parse_mixed_statements" {
  let input =
    #|digraph {
    #|  a
    #|  a -> b
    #|  b [color=red]
    #|}
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 3)
    Err(_) => abort("Failed to parse mixed statements")
  }
}

// Real-world examples

///|
test "parse_automaton_graph" {
  let dot_automaton =
    #|digraph {
    #|  graph [rankdir=LR];
    #|  node [shape=record];
    #|  0 [label="0 | [&bull; S, $]"];
    #|  1 [label="1 | [S &bull;, $]"];
    #|  2 [label="2 | [S &rarr; a &bull; S b, $]"];
    #|  0 -> 1 [label=S];
    #|  0 -> 2 [label=a];
    #|  2 -> 1 [label=b];
    #|}
  match parse_dot(dot_automaton) {
    Ok(graph) => {
      assert_eq(graph.directed, true)
      assert_true(graph.statements.length() >= 6)
    }
    Err(_) => abort("Failed to parse automaton graph")
  }
}

///|
test "parse_state_machine" {
  let input =
    #|digraph finite_state_machine {
    #|  rankdir=LR;
    #|  size="8,5"
    #|  node [shape = doublecircle]; S0 S1 S2;
    #|  node [shape = circle];
    #|  S0 -> S1 [ label = "a" ];
    #|  S1 -> S2 [ label = "a" ];
    #|  S0 -> S0 [ label = "b" ];
    #|}
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.id, Some("finite_state_machine"))
      assert_eq(graph.directed, true)
    }
    Err(_) => abort("Failed to parse state machine")
  }
}

///|
test "parse_record_shaped_node" {
  let input = "digraph { a [shape=record, label=\"field1|field2\"] }"
  match parse_dot(input) {
    Ok(graph) =>
      match graph.statements[0] {
        NodeStmt(_, attr_list) =>
          match attr_list {
            Some(attrs) => assert_eq(attrs.attributes.length(), 2)
            None => abort("Expected attributes")
          }
        _ => abort("Expected NodeStmt")
      }
    Err(_) => abort("Failed to parse record shaped node")
  }
}

///|
test "parse_dot rejects malformed attribute_without_value" {
  let parsed = parse_dot("digraph { a [color] }")
  inspect(parsed is Err(_), content="true")
}

// Whitespace and comment tests

///|
test "parse_with_extra_whitespace" {
  let input = "digraph   {   a  ->  b   }"
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 1)
    Err(_) => abort("Failed to parse with extra whitespace")
  }
}

///|
test "parse_with_newlines" {
  let input =
    #|digraph {
    #|  a ->
    #|    b
    #|}
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 1)
    Err(_) => abort("Failed to parse with newlines")
  }
}

///|
test "parse_with_line_comments" {
  let input =
    #|digraph {
    #|  // This is a comment
    #|  a -> b
    #|}
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 1)
    Err(_) => abort("Failed to parse with line comments")
  }
}

///|
test "parse_with_block_comments" {
  let input =
    #|digraph {
    #|  /* This is a
    #|     block comment */
    #|  a -> b
    #|}
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 1)
    Err(_) => abort("Failed to parse with block comments")
  }
}

///|
test "parse_with_hash_comments" {
  let input =
    #|digraph {
    #|  # This is a hash comment
    #|  a -> b
    #|}
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 1)
    Err(_) => abort("Failed to parse with hash comments")
  }
}

// Identifier variations

///|
test "parse_numeric_identifiers" {
  let input = "digraph { 0; 1; 123 }"
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 3)
    Err(_) => abort("Failed to parse numeric identifiers")
  }
}

///|
test "parse_quoted_identifiers" {
  let input = "digraph { \"hello world\" -> \"goodbye world\" }"
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 1)
    Err(_) => abort("Failed to parse quoted identifiers")
  }
}

///|
test "parse_identifiers_with_underscores" {
  let input = "digraph { node_1 -> node_2 }"
  match parse_dot(input) {
    Ok(graph) => assert_eq(graph.statements.length(), 1)
    Err(_) => abort("Failed to parse identifiers with underscores")
  }
}

// Error cases (should return Err)

///|
test "parse_missing_braces" {
  let input = "digraph"
  match parse_dot(input) {
    Ok(_) => abort("Should fail on missing braces")
    Err(_) => () // Expected
  }
}

///|
test "parse_missing_closing_brace" {
  let input = "digraph { a ->"
  match parse_dot(input) {
    Ok(_) => abort("Should fail on missing closing brace")
    Err(_) => () // Expected
  }
}

///|
test "parse_invalid_graph_type" {
  let input = "invalid { a }"
  match parse_dot(input) {
    Ok(_) => abort("Should fail on invalid graph type")
    Err(_) => () // Expected
  }
}

///|
test "parse_empty_input" {
  let input = ""
  match parse_dot(input) {
    Ok(_) => abort("Should fail on empty input")
    Err(_) => () // Expected
  }
}

///|
test "parse_dotted_ids_as_single_tokens" {
  let input = "digraph { .5; 1.; .foo }"
  match parse_dot(input) {
    Ok(graph) => {
      assert_eq(graph.statements.length(), 3)
      match graph.statements[0] {
        NodeStmt(node_id, _) => assert_eq(node_id.id, ".5")
        _ => abort("Expected first statement to be NodeStmt")
      }
      match graph.statements[1] {
        NodeStmt(node_id, _) => assert_eq(node_id.id, "1.")
        _ => abort("Expected second statement to be NodeStmt")
      }
      match graph.statements[2] {
        NodeStmt(node_id, _) => assert_eq(node_id.id, ".foo")
        _ => abort("Expected third statement to be NodeStmt")
      }
    }
    Err(_) => abort("Failed to parse dotted id variants")
  }
}

///|
test "parse_attributes_requires_full_input_consumption" {
  let valid = parse_attributes("a=b, c=d")
  assert_eq(valid.length(), 2)

  let invalid = parse_attributes("a=b] trailing")
  assert_eq(invalid.length(), 0)
}

///|
test "parse_dot rejects trailing tokens after closing brace" {
  let parsed = parse_dot("digraph { a -> b; } garbage")
  inspect(parsed is Err(_), content="true")
}

///|
test "parse_dot handles non-comment slash without hanging" {
  let parsed = parse_dot("/")
  inspect(parsed is Err(_), content="true")
}

///|
test "parse_dot still accepts valid comments in graph body" {
  let parsed = parse_dot("digraph { a -> b; // trailing comment\n }")
  match parsed {
    Ok(graph) => {
      inspect(graph.directed, content="true")
      inspect(graph.statements.length(), content="1")
    }
    Err(_) => abort("expected parser to accept valid comment")
  }
}

///|
test "parse_dot rejects unterminated block comments" {
  let parsed = parse_dot("digraph { a -> b; /* unterminated")
  inspect(parsed is Err(_), content="true")
}

///|
test "parse_attributes accepts decimal numerals" {
  let attrs = parse_attributes("penwidth=1.5")
  inspect(attrs.length(), content="1")
  inspect(attrs[0].key, content="penwidth")
  inspect(attrs[0].value, content="1.5")
}

///|
test "parse_dot accepts edge statement with subgraph start operand" {
  let parsed = parse_dot("digraph { subgraph { a } -> b; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="1")
      match graph.statements[0] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="a")
          inspect(edges.length(), content="1")
          inspect(edges[0].1.id, content="b")
        }
        _ => abort("expected edge statement")
      }
    }
    Err(_) => abort("expected parser to accept subgraph edge start operand")
  }
}

///|
test "parse_dot accepts edge statement with subgraph target operand" {
  let parsed = parse_dot("digraph { a -> subgraph { b }; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="1")
      match graph.statements[0] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="a")
          inspect(edges.length(), content="1")
          inspect(edges[0].1.id, content="b")
        }
        _ => abort("expected edge statement")
      }
    }
    Err(_) => abort("expected parser to accept subgraph edge target operand")
  }
}

///|
test "parse_dot expands subgraph start operand with multiple nodes" {
  let parsed = parse_dot("digraph { { a; b; } -> c; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="2")
      match graph.statements[0] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="a")
          inspect(edges.length(), content="1")
          inspect(edges[0].1.id, content="c")
        }
        _ => abort("expected expanded edge statement")
      }
      match graph.statements[1] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="b")
          inspect(edges.length(), content="1")
          inspect(edges[0].1.id, content="c")
        }
        _ => abort("expected expanded edge statement")
      }
    }
    Err(_) => abort("expected parser to expand multi-node subgraph start")
  }
}

///|
test "parse_dot expands subgraph target operand with multiple nodes" {
  let parsed = parse_dot("digraph { a -> { b; c; }; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="2")
      match graph.statements[0] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="a")
          inspect(edges[0].1.id, content="b")
        }
        _ => abort("expected expanded edge statement")
      }
      match graph.statements[1] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="a")
          inspect(edges[0].1.id, content="c")
        }
        _ => abort("expected expanded edge statement")
      }
    }
    Err(_) => abort("expected parser to expand multi-node subgraph target")
  }
}

///|
test "parse_dot accepts edge statement from empty subgraph endpoint as no-op" {
  let parsed = parse_dot("digraph { subgraph cluster_0 { } -> b; }")
  match parsed {
    Ok(graph) => inspect(graph.statements.length(), content="0")
    Err(_) => abort("expected parser to accept empty subgraph edge operand")
  }
}

///|
test "parse_dot continues after empty subgraph edge no-op" {
  let parsed = parse_dot("digraph { subgraph { } -> b; c; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="1")
      match graph.statements[0] {
        NodeStmt(node_id, _) => inspect(node_id.id, content="c")
        _ => abort("expected node statement after no-op edge")
      }
    }
    Err(_) => abort("expected parser to continue after empty subgraph edge")
  }
}

///|
test "parse_dot preserves_nontrivial_subgraph_start_operand_contents" {
  let parsed = parse_dot("digraph { subgraph { a [color=red]; b -> c } -> d; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="4")
      match graph.statements[0] {
        Subgraph(subgraph) => {
          inspect(subgraph.statements.length(), content="2")
          match subgraph.statements[0] {
            NodeStmt(node_id, Some(attrs)) => {
              inspect(node_id.id, content="a")
              inspect(attrs.attributes[0].key, content="color")
              inspect(attrs.attributes[0].value, content="red")
            }
            _ => abort("expected attributed node in preserved subgraph")
          }
          match subgraph.statements[1] {
            EdgeStmt(start, edges, _) => {
              inspect(start.id, content="b")
              inspect(edges[0].1.id, content="c")
            }
            _ => abort("expected inner edge in preserved subgraph")
          }
        }
        _ => abort("expected preserved subgraph statement")
      }
      match graph.statements[1] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="a")
          inspect(edges[0].1.id, content="d")
        }
        _ => abort("expected expanded edge from preserved subgraph node")
      }
    }
    Err(_) => abort("expected parser to preserve non-trivial subgraph operand")
  }
}

///|
test "parse_dot preserves_nontrivial_subgraph_target_operand_contents" {
  let parsed = parse_dot("digraph { a -> subgraph { b [color=red]; c -> d }; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="4")
      match graph.statements[0] {
        Subgraph(subgraph) => {
          inspect(subgraph.statements.length(), content="2")
          match subgraph.statements[0] {
            NodeStmt(node_id, Some(attrs)) => {
              inspect(node_id.id, content="b")
              inspect(attrs.attributes[0].key, content="color")
              inspect(attrs.attributes[0].value, content="red")
            }
            _ => abort("expected attributed node in preserved subgraph")
          }
          match subgraph.statements[1] {
            EdgeStmt(start, edges, _) => {
              inspect(start.id, content="c")
              inspect(edges[0].1.id, content="d")
            }
            _ => abort("expected inner edge in preserved subgraph")
          }
        }
        _ => abort("expected preserved subgraph statement")
      }
      match graph.statements[1] {
        EdgeStmt(start, edges, _) => {
          inspect(start.id, content="a")
          inspect(edges[0].1.id, content="b")
        }
        _ => abort("expected expanded edge into preserved subgraph node")
      }
    }
    Err(_) => abort("expected parser to preserve non-trivial subgraph target")
  }
}

///|
test "parse_dot accepts empty subgraph target operand as no-op" {
  let parsed = parse_dot("digraph { a -> subgraph { }; b; }")
  match parsed {
    Ok(graph) => {
      inspect(graph.statements.length(), content="1")
      match graph.statements[0] {
        NodeStmt(node_id, _) => inspect(node_id.id, content="b")
        _ => abort("expected node statement after no-op edge")
      }
    }
    Err(_) => abort("expected parser to accept empty subgraph edge target")
  }
}

///|
test "parse_dot rejects missing port id after colon" {
  let parsed = parse_dot("digraph { a: -> b; }")
  inspect(parsed is Err(_), content="true")
}

///|
test "parse_dot rejects trailing colon without compass point" {
  let parsed = parse_dot("digraph { a:port: -> b; }")
  inspect(parsed is Err(_), content="true")
}

///|
test "parse_dot accepts valid port with compass point" {
  let parsed = parse_dot("digraph { a:port:n -> b; }")
  match parsed {
    Ok(graph) => inspect(graph.statements.length(), content="1")
    Err(_) => abort("expected parser to accept valid port syntax")
  }
}

///|
test "parse_dot accepts compass-like port id with explicit compass suffix" {
  let parsed = parse_dot("digraph { a:n:sw -> b; }")
  match parsed {
    Ok(graph) =>
      match graph.statements[0] {
        EdgeStmt(start, _edges, _) =>
          match start.port {
            Some(port) => {
              match port.id {
                Some(id) => inspect(id, content="n")
                None => abort("expected explicit port id")
              }
              match port.compass {
                Some(SW) => inspect(true, content="true")
                _ => abort("expected sw compass point")
              }
            }
            None => abort("expected parsed port")
          }
        _ => abort("expected edge statement")
      }
    Err(_) => abort("expected parser to accept a:n:sw")
  }
}

///|
test "parse_dot rejects malformed edge rhs after consumed operator" {
  let parsed = parse_dot("digraph { a -> ; }")
  inspect(parsed is Err(_), content="true")
}

///|
test "parse_dot_error_has_position_for_missing_brace" {
  match parse_dot("digraph") {
    Ok(_) => abort("should fail")
    Err(e) => {
      inspect(e.position > 0, content="true")
      inspect(e.message.length() > 0, content="true")
    }
  }
}

///|
test "parse_dot_error_has_position_for_trailing_tokens" {
  match parse_dot("digraph { a } extra") {
    Ok(_) => abort("should fail")
    Err(e) => {
      inspect(e.message.contains("unexpected"), content="true")
      inspect(e.position, content="14")
    }
  }
}
