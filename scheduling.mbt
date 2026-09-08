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
/// Domain-specific scheduling failures.
pub(all) enum RosterError {
  DuplicateWorkerId(Int)
  DuplicateShiftId(Int)
  NoEligibleWorker(Int, String)
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
    InvalidModel(error) => "invalid constraint model: \{error.message()}"
    Unsatisfiable(stats) =>
      "no feasible roster after \{stats.nodes} assignments and \{stats.backtracks} backtracks"
  }
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
/// Assign one eligible worker to every shift.
///
/// Workers may serve again in a different slot, but cannot cover two shifts in
/// the same slot. Skill and availability rules are compiled into variable
/// domains before search starts.
pub fn build_roster(
  workers : Array[Worker],
  shifts : Array[Shift],
) -> Result[Roster, RosterError] {
  match duplicate_worker_id(workers) {
    Some(id) => return Err(DuplicateWorkerId(id))
    None => ()
  }
  match duplicate_shift_id(shifts) {
    Some(id) => return Err(DuplicateShiftId(id))
    None => ()
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
  match problem.solve() {
    Unsatisfied(stats) => Err(Unsatisfiable(stats))
    Satisfied(solution, stats) => {
      let entries : Array[RosterEntry] = []
      for index = 0; index < shifts.length(); index = index + 1 {
        match solution.get(variables[index].name) {
          Some(worker_index) =>
            entries.push({
              shift: shifts[index],
              worker: workers[worker_index],
            })
          None => ()
        }
      }
      Ok({ entries, stats, })
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
