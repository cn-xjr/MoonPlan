///|
/// A concrete change that can make a roster model schedulable.
pub(all) enum RosterRepair {
  RenameWorkerId(Int)
  RenameShiftId(Int)
  AddQualifiedWorker(Int, String, String)
  AddSlotCapacity(Int, Int)
  RaiseWorkloadLimit(Int, Int)
  ReduceMinimumSlotGap(Int, Int)
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
    ReduceMinimumSlotGap(current, suggested) =>
      "reduce the minimum slot gap from \{current} to \{suggested}"
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
fn policy_model(
  workers : Array[Worker],
  shifts : Array[Shift],
  policy : RosterPolicy,
) -> Result[RosterModel, RosterError] {
  match build_roster_model(workers, shifts) {
    Err(error) => Err(error)
    Ok(model) =>
      match apply_roster_policy(model, workers, shifts, policy) {
        Err(error) => Err(error)
        Ok(_) => Ok(model)
      }
  }
}

///|
fn minimum_feasible_workload_limit(
  workers : Array[Worker],
  shifts : Array[Shift],
  policy : RosterPolicy,
) -> Int? {
  match policy.max_shifts_per_worker {
    None => return None
    Some(current) =>
      for limit = current + 1; limit <= shifts.length(); limit = limit + 1 {
        match
          policy_model(workers, shifts, {
            max_shifts_per_worker: Some(limit),
            minimum_slot_gap: policy.minimum_slot_gap,
          }) {
          Err(_) => ()
          Ok(model) =>
            match model.problem.solve() {
              Satisfied(_, _) => return Some(limit)
              Unsatisfied(_) => ()
            }
        }
      }
  }
  None
}

///|
fn maximum_feasible_rest_gap_below(
  workers : Array[Worker],
  shifts : Array[Shift],
  policy : RosterPolicy,
) -> Int? {
  let mut gap = policy.minimum_slot_gap - 1
  while gap >= 0 {
    match
      policy_model(workers, shifts, {
        max_shifts_per_worker: policy.max_shifts_per_worker,
        minimum_slot_gap: gap,
      }) {
      Err(_) => ()
      Ok(model) =>
        match model.problem.solve() {
          Satisfied(_, _) => return Some(gap)
          Unsatisfied(_) => ()
        }
    }
    gap = gap - 1
  }
  None
}

///|
/// Diagnose a roster policy and propose independently feasible relaxations.
///
/// Definite input and capacity issues are reported without search. If only the
/// policy makes the model impossible, the returned conflict retains the named
/// rules. Workload suggestions choose the smallest feasible limit; rest
/// suggestions choose the largest smaller gap that restores feasibility.
pub fn suggest_roster_policy_repairs(
  workers : Array[Worker],
  shifts : Array[Shift],
  policy : RosterPolicy,
) -> Result[RosterRepairPlan, RosterError] {
  match validate_roster_policy(policy) {
    Err(error) => return Err(error)
    Ok(_) => ()
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
  match policy_model(workers, shifts, policy) {
    Err(error) => Err(error)
    Ok(model) =>
      match model.problem.explain() {
        Consistent(_) => Ok({ issues: [], conflict: None, repairs: [], })
        Inconsistent(conflict) => {
          let repairs : Array[RosterRepair] = []
          match policy.max_shifts_per_worker {
            Some(current) =>
              match minimum_feasible_workload_limit(workers, shifts, policy) {
                Some(limit) => repairs.push(RaiseWorkloadLimit(current, limit))
                None => ()
              }
            None => ()
          }
          if policy.minimum_slot_gap > 0 {
            match maximum_feasible_rest_gap_below(workers, shifts, policy) {
              Some(gap) =>
                repairs.push(ReduceMinimumSlotGap(policy.minimum_slot_gap, gap))
              None => ()
            }
          }
          Ok({ issues: [], conflict: Some(conflict), repairs, })
        }
      }
  }
}

///|
/// Diagnose a roster with a uniform workload cap and propose concrete repairs.
///
/// This compatibility helper applies no minimum rest gap. Use
/// `suggest_roster_policy_repairs` when workload and rest rules are combined.
pub fn suggest_capped_roster_repairs(
  workers : Array[Worker],
  shifts : Array[Shift],
  max_shifts_per_worker : Int,
) -> Result[RosterRepairPlan, RosterError] {
  suggest_roster_policy_repairs(workers, shifts, {
    max_shifts_per_worker: Some(max_shifts_per_worker),
    minimum_slot_gap: 0,
  })
}
