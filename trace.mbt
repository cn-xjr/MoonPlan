///|
/// One deterministic event emitted by the backtracking search.
pub(all) enum SearchEvent {
  TryValue(String, Int, Int)
  DeadEnd(String, Int)
  Backtrack(String, Int, Int)
  SolutionFound(Int, Int)
} derive(Eq, Debug, ToJson)

///|
/// A first-solution result together with a bounded search trace.
pub(all) struct SolveTrace {
  outcome : SolveOutcome
  events : Array[SearchEvent]
  truncated : Bool
} derive(Eq, Debug, ToJson)

///|
priv struct TraceRecorder {
  events : Array[SearchEvent]
  limit : Int
  mut truncated : Bool
}

///|
fn TraceRecorder::record(self : TraceRecorder, event : SearchEvent) -> Unit {
  if self.events.length() < self.limit {
    self.events.push(event)
  } else {
    self.truncated = true
  }
}

///|
fn record_search_event(recorder : TraceRecorder?, event : SearchEvent) -> Unit {
  match recorder {
    Some(value) => value.record(event)
    None => ()
  }
}

///|
/// Render one search event for logs and accessible user interfaces.
pub fn SearchEvent::message(self : SearchEvent) -> String {
  match self {
    TryValue(name, value, depth) => "try \{name} = \{value} at depth \{depth}"
    DeadEnd(name, depth) => "dead end at \{name}, depth \{depth}"
    Backtrack(name, value, depth) =>
      "backtrack from \{name} = \{value} at depth \{depth}"
    SolutionFound(number, depth) => "found solution \{number} at depth \{depth}"
  }
}

///|
/// Find the first solution while recording a bounded deterministic event log.
///
/// Reaching the event limit only truncates observation; it never stops or
/// changes the underlying search.
pub fn Problem::solve_with_trace(
  self : Problem,
  event_limit : Int,
) -> Result[SolveTrace, ModelError] {
  if event_limit <= 0 {
    return Err(InvalidTraceLimit(event_limit))
  }
  let assignment : Array[Int?] = Array::make(self.variables.length(), None)
  let counters : SearchCounters = { nodes: 0, backtracks: 0, }
  let solutions : Array[Solution] = []
  let recorder : TraceRecorder = {
    events: [],
    limit: event_limit,
    truncated: false,
  }
  search(self, assignment, counters, solutions, 1, Some(recorder), 0)
  let stats : SolveStats = {
    nodes: counters.nodes,
    backtracks: counters.backtracks,
    solutions: solutions.length(),
  }
  let outcome = if solutions.length() == 0 {
    Unsatisfied(stats)
  } else {
    Satisfied(solutions[0], stats)
  }
  Ok({ outcome, events: recorder.events, truncated: recorder.truncated, })
}
