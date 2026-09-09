///|
/// A concrete change that can make a roster model schedulable.
pub(all) enum RosterRepair {
  RenameWorkerId(Int)
  RenameShiftId(Int)
  AddQualifiedWorker(Int, String, String)
  AddSlotCapacity(Int, Int)
  RaiseWorkloadLimit(Int, Int)
} derive(Eq, Debug)

///|
/// Render one proposed repair in business-facing terms.
pub fn RosterRepair::message(self : RosterRepair) -> String {
  match self {
    RenameWorkerId(id) => "assign a unique id to the workers using id \{id}"
    RenameShiftId(id) => "assign a unique id to the shifts using id \{id}"
    AddQualifiedWorker(id, name, skill) =>
      if skill.length() == 0 {
        "add an available worker for shift \{id} (\{name})"
      } else {
        "add a worker with skill \{skill} who is available for shift \{id} (\{name})"
      }
    AddSlotCapacity(slot, missing) =>
      "make \{missing} additional eligible worker(s) available at slot \{slot}"
    RaiseWorkloadLimit(current, suggested) =>
      "raise the per-worker workload limit from \{current} to \{suggested}"
  }
}

///|
/// Scheduling facts, solver evidence, and actionable repairs in one report.
pub(all) struct RosterRepairPlan {
  issues : Array[RosterIssue]
  conflict : ConflictReport?
  repairs : Array[RosterRepair]
} derive(Eq, Debug)

///|
/// Whether the roster is feasible without applying a repair.
pub fn RosterRepairPlan::is_feasible(self : RosterRepairPlan) -> Bool {
  self.issues.length() == 0 && self.conflict is None
}

///|
/// Render the proposed changes as a compact diagnostic line.
pub fn RosterRepairPlan::summary(self : RosterRepairPlan) -> String {
  if self.is_feasible() {
    return "roster is feasible without repairs"
  }
  if self.repairs.length() == 0 {
    return "no automatic roster repair is available"
  }
  let mut output = ""
  for index = 0; index < self.repairs.length(); index = index + 1 {
    if index > 0 {
      output = output + "; "
    }
    output = output + self.repairs[index].message()
  }
  output
}

///|
fn slot_has_unstaffed_shift(
  issues : Array[RosterIssue],
  shifts : Array[Shift],
  slot : Int,
) -> Bool {
  for issue in issues {
    match issue {
      NoEligibleWorkerFound(id, name) =>
        for shift in shifts {
          if shift.id == id && shift.name == name && shift.slot == slot {
            return true
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn repair_for_issue(
  issue : RosterIssue,
  issues : Array[RosterIssue],
  shifts : Array[Shift],
) -> RosterRepair? {
  match issue {
    DuplicateWorkerIdFound(id) => Some(RenameWorkerId(id))
    DuplicateShiftIdFound(id) => Some(RenameShiftId(id))
    NoEligibleWorkerFound(id, name) => {
      let mut skill = ""
      for shift in shifts {
        if shift.id == id && shift.name == name {
          skill = shift.required_skill
          break
        }
      }
      Some(AddQualifiedWorker(id, name, skill))
    }
    SlotCoverageShortfall(slot, required, assignable) =>
      if slot_has_unstaffed_shift(issues, shifts, slot) {
        None
      } else {
        Some(AddSlotCapacity(slot, required - assignable))
      }
  }
}

///|
fn capped_model(
  workers : Array[Worker],
  shifts : Array[Shift],
  limit : Int,
) -> Result[RosterModel, RosterError] {
  match build_roster_model(workers, shifts) {
    Err(error) => Err(error)
    Ok(model) =>
      match add_workload_constraints(model, workers, limit) {
        Err(error) => Err(error)
        Ok(_) => Ok(model)
      }
  }
}

///|
fn minimum_feasible_workload_limit(
  workers : Array[Worker],
  shifts : Array[Shift],
  current : Int,
) -> Int? {
  for limit = current + 1; limit <= shifts.length(); limit = limit + 1 {
    match capped_model(workers, shifts, limit) {
      Err(_) => ()
      Ok(model) =>
        match model.problem.solve() {
          Satisfied(_, _) => return Some(limit)
          Unsatisfied(_) => ()
        }
    }
  }
  None
}

///|
/// Diagnose a roster with a uniform workload cap and propose concrete repairs.
///
/// Definite input and capacity issues are reported without search. If only the
/// cap makes the model impossible, the returned conflict contains the named
/// solver rules and the proposed limit is the smallest feasible uniform value.
pub fn suggest_capped_roster_repairs(
  workers : Array[Worker],
  shifts : Array[Shift],
  max_shifts_per_worker : Int,
) -> Result[RosterRepairPlan, RosterError] {
  if max_shifts_per_worker < 0 {
    return Err(InvalidWorkloadLimit(max_shifts_per_worker))
  }
  let analysis = analyze_roster(workers, shifts)
  if analysis.issues.length() > 0 {
    let repairs : Array[RosterRepair] = []
    for issue in analysis.issues {
      match repair_for_issue(issue, analysis.issues, shifts) {
        Some(repair) => repairs.push(repair)
        None => ()
      }
    }
    return Ok({ issues: analysis.issues, conflict: None, repairs, })
  }
  match capped_model(workers, shifts, max_shifts_per_worker) {
    Err(error) => Err(error)
    Ok(model) =>
      match model.problem.explain() {
        Consistent(_) => Ok({ issues: [], conflict: None, repairs: [], })
        Inconsistent(conflict) => {
          let repairs : Array[RosterRepair] = []
          match
            minimum_feasible_workload_limit(
              workers, shifts, max_shifts_per_worker,
            ) {
            Some(limit) =>
              repairs.push(RaiseWorkloadLimit(max_shifts_per_worker, limit))
            None => ()
          }
          Ok({ issues: [], conflict: Some(conflict), repairs, })
        }
      }
  }
}
