///|
/// A non-negative soft cost for assigning one worker to one shift.
///
/// Omitted worker-shift pairs have zero cost. Higher values express stronger
/// preferences to avoid an assignment without making it impossible.
pub(all) struct AssignmentPenalty {
  worker_id : Int
  shift_id : Int
  penalty : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Soft costs used to rank feasible rosters.
///
/// `consecutive_slot_penalty` is charged for each pair of shifts in adjacent
/// slots assigned to the same worker. A value of zero disables this cost.
pub(all) struct RosterObjective {
  assignment_penalties : Array[AssignmentPenalty]
  consecutive_slot_penalty : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Build an objective with no soft costs.
pub fn RosterObjective::default() -> RosterObjective {
  { assignment_penalties: [], consecutive_slot_penalty: 0, }
}

///|
/// One assignment preference that contributes to a roster's soft cost.
pub(all) struct AssignmentPenaltyCharge {
  worker_id : Int
  shift_id : Int
  penalty : Int
} derive(Eq, Debug, ToJson)

///|
/// One adjacent pair of shifts that contributes to fatigue cost.
pub(all) struct ConsecutiveSlotCharge {
  worker_id : Int
  earlier_shift_id : Int
  later_shift_id : Int
  penalty : Int
} derive(Eq, Debug, ToJson)

///|
/// An auditable breakdown of every soft cost charged to a roster.
pub(all) struct RosterPenaltyBreakdown {
  assignment_charges : Array[AssignmentPenaltyCharge]
  consecutive_slot_charges : Array[ConsecutiveSlotCharge]
  assignment_total : Int
  consecutive_slot_total : Int
  total_penalty : Int
} derive(Eq, Debug, ToJson)

///|
/// The lowest-penalty roster found within a bounded candidate search.
pub(all) struct PreferredRoster {
  roster : Roster
  total_penalty : Int
  penalty_breakdown : RosterPenaltyBreakdown
  balance : BalanceScore
  candidates_evaluated : Int
} derive(Eq, Debug, ToJson)

///|
fn worker_id_exists(workers : Array[Worker], worker_id : Int) -> Bool {
  for worker in workers {
    if worker.id == worker_id {
      return true
    }
  }
  false
}

///|
fn shift_id_exists(shifts : Array[Shift], shift_id : Int) -> Bool {
  for shift in shifts {
    if shift.id == shift_id {
      return true
    }
  }
  false
}

///|
fn validate_assignment_penalties(
  workers : Array[Worker],
  shifts : Array[Shift],
  penalties : Array[AssignmentPenalty],
) -> Result[Unit, RosterError] {
  for index = 0; index < penalties.length(); index = index + 1 {
    let item = penalties[index]
    if !worker_id_exists(workers, item.worker_id) {
      return Err(UnknownPenaltyWorker(item.worker_id))
    }
    if !shift_id_exists(shifts, item.shift_id) {
      return Err(UnknownPenaltyShift(item.shift_id))
    }
    if item.penalty < 0 {
      return Err(
        InvalidAssignmentPenalty(item.worker_id, item.shift_id, item.penalty),
      )
    }
    for previous = 0; previous < index; previous = previous + 1 {
      if penalties[previous].worker_id == item.worker_id &&
        penalties[previous].shift_id == item.shift_id {
        return Err(DuplicateAssignmentPenalty(item.worker_id, item.shift_id))
      }
    }
  }
  Ok(())
}

///|
fn objective_penalty_breakdown(
  roster : Roster,
  objective : RosterObjective,
) -> RosterPenaltyBreakdown {
  let assignment_charges : Array[AssignmentPenaltyCharge] = []
  let consecutive_slot_charges : Array[ConsecutiveSlotCharge] = []
  let mut assignment_total = 0
  for entry in roster.entries {
    for item in objective.assignment_penalties {
      if item.worker_id == entry.worker.id && item.shift_id == entry.shift.id {
        assignment_charges.push({
          worker_id: item.worker_id,
          shift_id: item.shift_id,
          penalty: item.penalty,
        })
        assignment_total = assignment_total + item.penalty
        break
      }
    }
  }
  let mut consecutive_slot_total = 0
  if objective.consecutive_slot_penalty > 0 {
    for left = 0; left < roster.entries.length(); left = left + 1 {
      for right = left + 1; right < roster.entries.length(); right = right + 1 {
        let left_entry = roster.entries[left]
        let right_entry = roster.entries[right]
        if left_entry.worker.id == right_entry.worker.id &&
          slot_distance(left_entry.shift.slot, right_entry.shift.slot) == 1 {
          let (earlier_shift_id, later_shift_id) = if left_entry.shift.slot <
            right_entry.shift.slot {
            (left_entry.shift.id, right_entry.shift.id)
          } else {
            (right_entry.shift.id, left_entry.shift.id)
          }
          consecutive_slot_charges.push({
            worker_id: left_entry.worker.id,
            earlier_shift_id,
            later_shift_id,
            penalty: objective.consecutive_slot_penalty,
          })
          consecutive_slot_total = consecutive_slot_total +
            objective.consecutive_slot_penalty
        }
      }
    }
  }
  {
    assignment_charges,
    consecutive_slot_charges,
    assignment_total,
    consecutive_slot_total,
    total_penalty: assignment_total + consecutive_slot_total,
  }
}

///|
fn objective_penalty(roster : Roster, objective : RosterObjective) -> Int {
  let mut total = 0
  for entry in roster.entries {
    for item in objective.assignment_penalties {
      if item.worker_id == entry.worker.id && item.shift_id == entry.shift.id {
        total = total + item.penalty
        break
      }
    }
  }
  if objective.consecutive_slot_penalty > 0 {
    for left = 0; left < roster.entries.length(); left = left + 1 {
      for right = left + 1; right < roster.entries.length(); right = right + 1 {
        if roster.entries[left].worker.id == roster.entries[right].worker.id &&
          slot_distance(
            roster.entries[left].shift.slot,
            roster.entries[right].shift.slot,
          ) ==
          1 {
          total = total + objective.consecutive_slot_penalty
        }
      }
    }
  }
  total
}

///|
fn better_preferred_roster(
  penalty : Int,
  balance : BalanceScore,
  best_penalty : Int,
  best_balance : BalanceScore,
) -> Bool {
  penalty < best_penalty ||
  (penalty == best_penalty && better_balance(balance, best_balance))
}

///|
/// Optimize soft assignment preferences under the selected hard policy.
///
/// Total penalty is minimized first. Workload balance breaks equal-penalty
/// ties, and deterministic solution order breaks any remaining tie. The
/// candidate limit keeps optimization cost explicit.
pub fn build_preferred_roster(
  workers : Array[Worker],
  shifts : Array[Shift],
  policy : RosterPolicy,
  penalties : Array[AssignmentPenalty],
  candidate_limit : Int,
) -> Result[PreferredRoster, RosterError] {
  build_preferred_roster_with_objective(
    workers,
    shifts,
    policy,
    { assignment_penalties: penalties, consecutive_slot_penalty: 0, },
    candidate_limit,
  )
}

///|
/// Optimize assignment preferences and consecutive-work cost together.
///
/// Total soft cost is minimized first. Workload balance breaks equal-cost
/// ties, and deterministic solution order breaks any remaining tie. Existing
/// callers can keep using `build_preferred_roster`, which disables the
/// consecutive-slot cost.
pub fn build_preferred_roster_with_objective(
  workers : Array[Worker],
  shifts : Array[Shift],
  policy : RosterPolicy,
  objective : RosterObjective,
  candidate_limit : Int,
) -> Result[PreferredRoster, RosterError] {
  if candidate_limit <= 0 {
    return Err(InvalidCandidateLimit(candidate_limit))
  }
  if objective.consecutive_slot_penalty < 0 {
    return Err(
      InvalidConsecutiveSlotPenalty(objective.consecutive_slot_penalty),
    )
  }
  match validate_roster_policy(policy) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match build_roster_model(workers, shifts) {
    Err(error) => Err(error)
    Ok(model) => {
      match
        validate_assignment_penalties(
          workers,
          shifts,
          objective.assignment_penalties,
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match apply_roster_policy(model, workers, shifts, policy) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
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
          let mut best_penalty = objective_penalty(best_roster, objective)
          let mut best_balance = balance_score(workers, best_roster)
          for index = 1; index < solutions.length(); index = index + 1 {
            let roster = roster_from_solution(
              workers,
              shifts,
              model.variables,
              solutions[index],
              stats,
            )
            let penalty = objective_penalty(roster, objective)
            let balance = balance_score(workers, roster)
            if better_preferred_roster(
                penalty, balance, best_penalty, best_balance,
              ) {
              best_roster = roster
              best_penalty = penalty
              best_balance = balance
            }
          }
          let best_breakdown = objective_penalty_breakdown(
            best_roster, objective,
          )
          Ok({
            roster: best_roster,
            total_penalty: best_penalty,
            penalty_breakdown: best_breakdown,
            balance: best_balance,
            candidates_evaluated: solutions.length(),
          })
        }
      }
    }
  }
}
