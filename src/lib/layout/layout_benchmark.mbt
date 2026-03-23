// Layout benchmarks — run with: moon bench --release
// Record baseline BEFORE alga integration, then compare AFTER.

///|
fn bench_dot_chain(n : Int) -> String {
  let mut s = "digraph { "
  for i in 0..<(n - 1) {
    s = s + "n" + i.to_string() + " -> n" + (i + 1).to_string() + "; "
  }
  s + "}"
}

///|
fn bench_dot_diamond(layers : Int, width : Int) -> String {
  let mut s = "digraph { "
  for layer in 0..<(layers - 1) {
    for i in 0..<width {
      for j in 0..<width {
        if (i + j) % 3 == 0 {
          let from = "n" + (layer * width + i).to_string()
          let to = "n" + ((layer + 1) * width + j).to_string()
          s = s + from + " -> " + to + "; "
        }
      }
    }
  }
  s + "}"
}

///|
fn bench_dot_cyclic(n : Int) -> String {
  let mut s = "digraph { "
  for i in 0..<n {
    let next = (i + 1) % n
    s = s + "n" + i.to_string() + " -> n" + next.to_string() + "; "
  }
  s + "}"
}

// --- Full layout pipeline ---

///|
test "bench/layout/full_chain_10" (b : @bench.T) {
  let dot = bench_dot_chain(10)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  b.bench(fn() { b.keep(compute_layout(graph)) })
}

///|
test "bench/layout/full_chain_50" (b : @bench.T) {
  let dot = bench_dot_chain(50)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  b.bench(fn() { b.keep(compute_layout(graph)) })
}

///|
test "bench/layout/full_diamond_50" (b : @bench.T) {
  let dot = bench_dot_diamond(5, 10)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  b.bench(fn() { b.keep(compute_layout(graph)) })
}

///|
test "bench/layout/full_cyclic_20" (b : @bench.T) {
  let dot = bench_dot_cyclic(20)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  b.bench(fn() { b.keep(compute_layout(graph)) })
}

// --- Isolated layer_assignment ---

///|
test "bench/layout/layer_assignment_chain_50" (b : @bench.T) {
  let dot = bench_dot_chain(50)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  let (nodes, edges) = extract_graph(graph)
  let (acyclic_edges, _) = remove_cycles(edges)
  b.bench(fn() { b.keep(assign_layers(nodes, acyclic_edges)) })
}

///|
test "bench/layout/layer_assignment_diamond_100" (b : @bench.T) {
  let dot = bench_dot_diamond(10, 10)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  let (nodes, edges) = extract_graph(graph)
  let (acyclic_edges, _) = remove_cycles(edges)
  b.bench(fn() { b.keep(assign_layers(nodes, acyclic_edges)) })
}

// --- Isolated cycle_removal ---

///|
test "bench/layout/cycle_removal_chain_50" (b : @bench.T) {
  let dot = bench_dot_chain(50)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  let (_, edges) = extract_graph(graph)
  b.bench(fn() { b.keep(remove_cycles(edges)) })
}

///|
test "bench/layout/cycle_removal_cyclic_20" (b : @bench.T) {
  let dot = bench_dot_cyclic(20)
  let graph = match @parser.parse_dot(dot) {
    Ok(g) => g
    Err(_) => abort("parse failed")
  }
  let (_, edges) = extract_graph(graph)
  b.bench(fn() { b.keep(remove_cycles(edges)) })
}
