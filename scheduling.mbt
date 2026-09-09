///|
/// A person who can be assigned to shifts.
pub(all) struct Worker {
  id : Int
  name : String
  skills : Array[String]
  available_slots : Array[Int]
} derive(Eq, Debug)

///|
/// A unit of work that needs exactly one eligible worker.
pub(all) struct Shift {
  id : Int
  name : String
  slot : Int
  required_skill : String
} derive(Eq, Debug)

///|
/// One resolved worker-to-shift assignment.
pub(all) struct RosterEntry {
  shift : Shift
  worker : Worker
} derive(Eq, Debug)

///|
/// A feasible roster together with search evidence.
pub(all) struct Roster {
  entries : Array[RosterEntry]
  stats : SolveStats
} derive(Eq, Debug)

///|
/// A workload balance score. Lower spread and lower maximum load are better.
pub(all) struct BalanceScore {
  minimum_load : Int
  maximum_load : Int
  spread : Int
} derive(Eq, Debug)

///|
/// The best roster found within a bounded candidate search.
pub(all) struct OptimizedRoster {
  roster : Roster
  balance : BalanceScore
  candidates_evaluated : Int
} derive(Eq, Debug)

///|
/// Domain-specific scheduling failures.
pub(all) enum RosterError {
  DuplicateWorkerId(Int)
  DuplicateShiftId(Int)
  NoEligibleWorker(Int, String)
  InsufficientSlotCapacity(Int, Int, Int)
  InvalidCandidateLimit(Int)
  InvalidWorkloadLimit(Int)
  InvalidModel(ModelError)
  Unsatisfiable(SolveStats)
} derive(Eq, Debug)

///|
/// Explain a scheduling failure without exposing solver internals.
pub fn RosterError::message(self : RosterError) -> String {
  match self {
    DuplicateWorkerId(id) => "duplicate worker id: \{id}"
    DuplicateShiftId(id) => "duplicate shift id: \{id}"
    NoEligibleWorker(id, name) =>
      "shift \{id} (\{name}) has no worker with the required skill and availability"
    InsufficientSlotCapacity(slot, required, assignable) =>
      "slot \{slot} requires \{required} workers, but at most \{assignable} shifts can be covered"
    InvalidCandidateLimit(limit) =>
      "candidate limit must be positive, got \{limit}"
    InvalidWorkloadLimit(limit) =>
      "workload limit must not be negative, got \{limit}"
    InvalidModel(error) => "invalid constraint model: \{error.message()}"
    Unsatisfiable(stats) =>
      "no feasible roster after \{stats.nodes} assignments and \{stats.backtracks} backtracks"
  }
}

///|
priv struct RosterModel {
  problem : Problem
  variables : Array[Var]
}

///|
fn string_member(values : Array[String], expected : String) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
fn int_member(values : Array[Int], expected : Int) -> Bool {
  for value in values {
    if value == expected {
      return true
    }
  }
  false
}

///|
fn worker_is_eligible(worker : Worker, shift : Shift) -> Bool {
  int_member(worker.available_slots, shift.slot) &&
  (
    shift.required_skill.length() == 0 ||
    string_member(worker.skills, shift.required_skill)
  )
}

///|
fn duplicate_worker_id(workers : Array[Worker]) -> Int? {
  for i = 0; i < workers.length(); i = i + 1 {
    for j = 0; j < i; j = j + 1 {
      if workers[i].id == workers[j].id {
        return Some(workers[i].id)
      }
    }
  }
  None
}

///|
fn duplicate_shift_id(shifts : Array[Shift]) -> Int? {
  for i = 0; i < shifts.length(); i = i + 1 {
    for j = 0; j < i; j = j + 1 {
      if shifts[i].id == shifts[j].id {
        return Some(shifts[i].id)
      }
    }
  }
  None
}

///|
fn build_roster_model(
  workers : Array[Worker],
  shifts : Array[Shift],
) -> Result[RosterModel, RosterError] {
  let analysis = analyze_roster(workers, shifts)
  if analysis.issues.length() > 0 {
    match analysis.issues[0] {
      DuplicateWorkerIdFound(id) => return Err(DuplicateWorkerId(id))
      DuplicateShiftIdFound(id) => return Err(DuplicateShiftId(id))
      NoEligibleWorkerFound(id, name) => return Err(NoEligibleWorker(id, name))
      SlotCoverageShortfall(slot, required, assignable) =>
        return Err(InsufficientSlotCapacity(slot, required, assignable))
    }
  }
  let problem = Problem::new()
  let variables : Array[Var] = []
  for shift in shifts {
    let eligible : Array[Int] = []
    for worker_index = 0
        worker_index < workers.length()
        worker_index = worker_index + 1 {
      if worker_is_eligible(workers[worker_index], shift) {
        eligible.push(worker_index)
      }
    }
    if eligible.length() == 0 {
      return Err(NoEligibleWorker(shift.id, shift.name))
    }
    match problem.add_variable("shift-\{shift.id}", eligible) {
      Ok(variable) => variables.push(variable)
      Err(error) => return Err(InvalidModel(error))
    }
  }
  for left = 0; left < shifts.length(); left = left + 1 {
    for right = left + 1; right < shifts.length(); right = right + 1 {
      if shifts[left].slot == shifts[right].slot {
        match
          problem.add_constraint(Different(variables[left], variables[right])) {
          Ok(_) => ()
          Err(error) => return Err(InvalidModel(error))
        }
      }
    }
  }
  Ok({ problem, variables, })
}

///|
fn roster_from_solution(
  workers : Array[Worker],
  shifts : Array[Shift],
  variables : Array[Var],
  solution : Solution,
  stats : SolveStats,
) -> Roster {
  let entries : Array[RosterEntry] = []
  for index = 0; index < shifts.length(); index = index + 1 {
    match solution.get(variables[index].name) {
      Some(worker_index) =>
        entries.push({ shift: shifts[index], worker: workers[worker_index], })
      None => ()
    }
  }
  { entries, stats, }
}

///|
/// Assign one eligible worker to every shift.
///
/// Workers may serve again in a different slot, but cannot cover two shifts in
/// the same slot. Skill and availability rules are compiled into variable
/// domains before search starts.
pub fn build_roster(
  workers : Array[Worker],
  shifts : Array[Shift],
) -> Result[Roster, RosterError] {
  match build_roster_model(workers, shifts) {
    Err(error) => Err(error)
    Ok(model) =>
      match model.problem.solve() {
        Unsatisfied(stats) => Err(Unsatisfiable(stats))
        Satisfied(solution, stats) =>
          Ok(
            roster_from_solution(
              workers,
              shifts,
              model.variables,
              solution,
              stats,
            ),
          )
      }
  }
}

///|
/// Assign every shift while limiting each worker's total workload.
///
/// A zero limit is valid for an empty schedule. If the limit makes a non-empty
/// schedule impossible, the result reports an unsatisfiable model with search
/// statistics.
pub fn build_capped_roster(
  workers : Array[Worker],
  shifts : Array[Shift],
  max_shifts_per_worker : Int,
) -> Result[Roster, RosterError] {
  if max_shifts_per_worker < 0 {
    return Err(InvalidWorkloadLimit(max_shifts_per_worker))
  }
  match build_roster_model(workers, shifts) {
    Err(error) => Err(error)
    Ok(model) => {
      if model.variables.length() > 0 {
        for worker_index = 0
            worker_index < workers.length()
            worker_index = worker_index + 1 {
          match
            model.problem.add_constraint(
              CountAtMost(
                model.variables.copy(),
                worker_index,
                max_shifts_per_worker,
              ),
            ) {
            Ok(_) => ()
            Err(error) => return Err(InvalidModel(error))
          }
        }
      }
      match model.problem.solve() {
        Unsatisfied(stats) => Err(Unsatisfiable(stats))
        Satisfied(solution, stats) =>
          Ok(
            roster_from_solution(
              workers,
              shifts,
              model.variables,
              solution,
              stats,
            ),
          )
      }
    }
  }
}

///|
/// Find the worker assigned to a shift id.
pub fn Roster::worker_for_shift(self : Roster, shift_id : Int) -> Worker? {
  for entry in self.entries {
    if entry.shift.id == shift_id {
      return Some(entry.worker)
    }
  }
  None
}

///|
/// Count how many shifts were assigned to a worker id.
pub fn Roster::assignment_count(self : Roster, worker_id : Int) -> Int {
  let mut count = 0
  for entry in self.entries {
    if entry.worker.id == worker_id {
      count = count + 1
    }
  }
  count
}

///|
fn balance_score(workers : Array[Worker], roster : Roster) -> BalanceScore {
  if workers.length() == 0 {
    return { minimum_load: 0, maximum_load: 0, spread: 0, }
  }
  let mut minimum_load = roster.entries.length()
  let mut maximum_load = 0
  for worker in workers {
    let load = roster.assignment_count(worker.id)
    if load < minimum_load {
      minimum_load = load
    }
    if load > maximum_load {
      maximum_load = load
    }
  }
  { minimum_load, maximum_load, spread: maximum_load - minimum_load, }
}

///|
fn better_balance(candidate : BalanceScore, current : BalanceScore) -> Bool {
  candidate.spread < current.spread ||
  (
    candidate.spread == current.spread &&
    candidate.maximum_load < current.maximum_load
  )
}

///|
/// Find a feasible roster with the smallest workload spread among a bounded
/// number of deterministic candidates.
///
/// The limit makes optimization cost explicit. Increasing it may discover a
/// fairer roster, while the returned candidate count records the evidence used
/// for the decision.
pub fn build_balanced_roster(
  workers : Array[Worker],
  shifts : Array[Shift],
  candidate_limit : Int,
) -> Result[OptimizedRoster, RosterError] {
  if candidate_limit <= 0 {
    return Err(InvalidCandidateLimit(candidate_limit))
  }
  match build_roster_model(workers, shifts) {
    Err(error) => Err(error)
    Ok(model) =>
      match model.problem.solve_all(candidate_limit) {
        Err(error) => Err(InvalidModel(error))
        Ok((solutions, stats)) => {
          if solutions.length() == 0 {
            return Err(Unsatisfiable(stats))
          }
          let mut best_roster = roster_from_solution(
            workers,
            shifts,
            model.variables,
            solutions[0],
            stats,
          )
          let mut best_balance = balance_score(workers, best_roster)
          for index = 1; index < solutions.length(); index = index + 1 {
            let candidate = roster_from_solution(
              workers,
              shifts,
              model.variables,
              solutions[index],
              stats,
            )
            let candidate_balance = balance_score(workers, candidate)
            if better_balance(candidate_balance, best_balance) {
              best_roster = candidate
              best_balance = candidate_balance
            }
          }
          Ok({
            roster: best_roster,
            balance: best_balance,
            candidates_evaluated: solutions.length(),
          })
        }
      }
  }
}
