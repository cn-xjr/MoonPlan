///|
/// A concrete reason why a roster model cannot be scheduled as written.
pub(all) enum RosterIssue {
  DuplicateWorkerIdFound(Int)
  DuplicateShiftIdFound(Int)
  NoEligibleWorkerFound(Int, String)
  SlotCoverageShortfall(Int, Int, Int)
} derive(Eq, Debug)

///|
/// Explain one roster issue in business-facing terms.
pub fn RosterIssue::message(self : RosterIssue) -> String {
  match self {
    DuplicateWorkerIdFound(id) => "worker id \{id} is declared more than once"
    DuplicateShiftIdFound(id) => "shift id \{id} is declared more than once"
    NoEligibleWorkerFound(id, name) =>
      "shift \{id} (\{name}) has no worker with the required skill and availability"
    SlotCoverageShortfall(slot, required, assignable) =>
      "slot \{slot} requires \{required} workers, but at most \{assignable} shifts can be covered"
  }
}

///|
/// Preflight result that may contain several independent modeling issues.
pub(all) struct RosterAnalysis {
  issues : Array[RosterIssue]
} derive(Eq, Debug)

///|
/// Whether no definite scheduling conflict was found during preflight.
pub fn RosterAnalysis::is_feasible(self : RosterAnalysis) -> Bool {
  self.issues.length() == 0
}

///|
/// Render all discovered issues as a compact diagnostic line.
pub fn RosterAnalysis::summary(self : RosterAnalysis) -> String {
  if self.issues.length() == 0 {
    return "roster model passed preflight analysis"
  }
  let mut output = ""
  for index = 0; index < self.issues.length(); index = index + 1 {
    if index > 0 {
      output = output + "; "
    }
    output = output + self.issues[index].message()
  }
  output
}

///|
fn augment_shift(
  shift_index : Int,
  shifts : Array[Shift],
  workers : Array[Worker],
  visited : Array[Bool],
  worker_to_shift : Array[Int],
) -> Bool {
  for worker_index = 0
      worker_index < workers.length()
      worker_index = worker_index + 1 {
    if !visited[worker_index] &&
      worker_is_eligible(workers[worker_index], shifts[shift_index]) {
      visited[worker_index] = true
      let previous_shift = worker_to_shift[worker_index]
      if previous_shift == -1 ||
        augment_shift(previous_shift, shifts, workers, visited, worker_to_shift) {
        worker_to_shift[worker_index] = shift_index
        return true
      }
    }
  }
  false
}

///|
fn maximum_slot_coverage(workers : Array[Worker], shifts : Array[Shift]) -> Int {
  let worker_to_shift = Array::make(workers.length(), -1)
  let mut covered = 0
  for shift_index = 0
      shift_index < shifts.length()
      shift_index = shift_index + 1 {
    let visited = Array::make(workers.length(), false)
    if augment_shift(shift_index, shifts, workers, visited, worker_to_shift) {
      covered = covered + 1
    }
  }
  covered
}

///|
fn slot_seen_before(shifts : Array[Shift], index : Int) -> Bool {
  for previous = 0; previous < index; previous = previous + 1 {
    if shifts[previous].slot == shifts[index].slot {
      return true
    }
  }
  false
}

///|
/// Analyze definite roster conflicts before running the full solver.
///
/// Slot capacity uses maximum bipartite matching instead of only counting
/// available workers, so skill bottlenecks are reported accurately.
pub fn analyze_roster(
  workers : Array[Worker],
  shifts : Array[Shift],
) -> RosterAnalysis {
  let issues : Array[RosterIssue] = []
  match duplicate_worker_id(workers) {
    Some(id) => issues.push(DuplicateWorkerIdFound(id))
    None => ()
  }
  match duplicate_shift_id(shifts) {
    Some(id) => issues.push(DuplicateShiftIdFound(id))
    None => ()
  }
  for shift in shifts {
    let mut found = false
    for worker in workers {
      if worker_is_eligible(worker, shift) {
        found = true
        break
      }
    }
    if !found {
      issues.push(NoEligibleWorkerFound(shift.id, shift.name))
    }
  }
  for index = 0; index < shifts.length(); index = index + 1 {
    if !slot_seen_before(shifts, index) {
      let slot_shifts : Array[Shift] = []
      for shift in shifts {
        if shift.slot == shifts[index].slot {
          slot_shifts.push(shift)
        }
      }
      let coverage = maximum_slot_coverage(workers, slot_shifts)
      if coverage < slot_shifts.length() {
        issues.push(
          SlotCoverageShortfall(
            shifts[index].slot,
            slot_shifts.length(),
            coverage,
          ),
        )
      }
    }
  }
  { issues, }
}
