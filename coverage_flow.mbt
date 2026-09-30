///|
/// A residual edge in the coverage preflight network.
priv struct CoverageFlowEdge {
  to : Int
  reverse : Int
  mut remaining : Int
}

///|
fn add_coverage_flow_edge(
  graph : Array[Array[CoverageFlowEdge]],
  from : Int,
  to : Int,
  capacity : Int,
) -> Unit {
  let forward : CoverageFlowEdge = {
    to,
    reverse: graph[to].length(),
    remaining: capacity,
  }
  let backward : CoverageFlowEdge = {
    to: from,
    reverse: graph[from].length(),
    remaining: 0,
  }
  graph[from].push(forward)
  graph[to].push(backward)
}

///|
fn worker_slot_pair_seen(
  pairs : Array[(Int, Int)],
  worker_index : Int,
  slot : Int,
) -> Bool {
  for pair in pairs {
    if pair.0 == worker_index && pair.1 == slot {
      return true
    }
  }
  false
}

///|
/// Compute the exact maximum coverage under skills, availability,
/// same-slot exclusivity, and a uniform worker workload cap.
/// Rest gaps and consecutive-work rules are outside this network.
fn maximum_policy_coverage(
  workers : Array[Worker],
  shifts : Array[Shift],
  limit : Int,
) -> Int {
  let pairs : Array[(Int, Int)] = []
  for worker_index = 0
      worker_index < workers.length()
      worker_index = worker_index + 1 {
    for shift in shifts {
      if worker_is_eligible(workers[worker_index], shift) &&
        !worker_slot_pair_seen(pairs, worker_index, shift.slot) {
        pairs.push((worker_index, shift.slot))
      }
    }
  }
  let pair_start = 1 + workers.length()
  let shift_start = pair_start + pairs.length()
  let sink = shift_start + shifts.length()
  let graph : Array[Array[CoverageFlowEdge]] = []
  for node_index = 0; node_index <= sink; node_index = node_index + 1 {
    graph.push([])
  }
  for worker_index = 0
      worker_index < workers.length()
      worker_index = worker_index + 1 {
    add_coverage_flow_edge(graph, 0, 1 + worker_index, limit)
  }
  for pair_index = 0; pair_index < pairs.length(); pair_index = pair_index + 1 {
    let pair = pairs[pair_index]
    let pair_node = pair_start + pair_index
    add_coverage_flow_edge(graph, 1 + pair.0, pair_node, 1)
    for shift_index = 0
        shift_index < shifts.length()
        shift_index = shift_index + 1 {
      if shifts[shift_index].slot == pair.1 &&
        worker_is_eligible(workers[pair.0], shifts[shift_index]) {
        add_coverage_flow_edge(graph, pair_node, shift_start + shift_index, 1)
      }
    }
  }
  for shift_index = 0
      shift_index < shifts.length()
      shift_index = shift_index + 1 {
    add_coverage_flow_edge(graph, shift_start + shift_index, sink, 1)
  }
  let mut covered = 0
  while true {
    let previous = Array::make(sink + 1, -1)
    let previous_edge = Array::make(sink + 1, -1)
    let queue : Array[Int] = [0]
    previous[0] = 0
    let mut head = 0
    while head < queue.length() && previous[sink] == -1 {
      let from = queue[head]
      head = head + 1
      for edge_index = 0
          edge_index < graph[from].length()
          edge_index = edge_index + 1 {
        let edge = graph[from][edge_index]
        if edge.remaining > 0 && previous[edge.to] == -1 {
          previous[edge.to] = from
          previous_edge[edge.to] = edge_index
          queue.push(edge.to)
        }
      }
    }
    if previous[sink] == -1 {
      break
    }
    let mut node = sink
    while node != 0 {
      let from = previous[node]
      let edge = graph[from][previous_edge[node]]
      edge.remaining = edge.remaining - 1
      graph[node][edge.reverse].remaining = graph[node][edge.reverse].remaining +
        1
      node = from
    }
    covered = covered + 1
  }
  covered
}
