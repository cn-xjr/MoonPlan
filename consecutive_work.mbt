///|
fn consecutive_slot_seen_before(shifts : Array[Shift], index : Int) -> Bool {
  for previous = 0; previous < index; previous = previous + 1 {
    if shifts[previous].slot == shifts[index].slot {
      return true
    }
  }
  false
}

///|
fn add_consecutive_work_constraints(
  model : RosterModel,
  workers : Array[Worker],
  shifts : Array[Shift],
  maximum_consecutive_slots : Int,
) -> Result[Unit, RosterError] {
  for start_index = 0
      start_index < shifts.length()
      start_index = start_index + 1 {
    if consecutive_slot_seen_before(shifts, start_index) {
      continue
    }
    let start_slot = shifts[start_index].slot
    let window_variables : Array[Var] = []
    let window_slots : Array[Int] = []
    for shift_index = 0
        shift_index < shifts.length()
        shift_index = shift_index + 1 {
      let slot = shifts[shift_index].slot
      if slot >= start_slot && slot - start_slot <= maximum_consecutive_slots {
        window_variables.push(model.variables[shift_index])
        if !int_member(window_slots, slot) {
          window_slots.push(slot)
        }
      }
    }
    if window_slots.length() > maximum_consecutive_slots {
      for worker_index = 0
          worker_index < workers.length()
          worker_index = worker_index + 1 {
        match
          model.problem.add_named_constraint(
            "worker-\{workers[worker_index].id}:consecutive-from-\{start_slot}:max-\{maximum_consecutive_slots}",
            CountAtMost(
              window_variables.copy(),
              worker_index,
              maximum_consecutive_slots,
            ),
          ) {
          Ok(_) => ()
          Err(error) => return Err(InvalidModel(error))
        }
      }
    }
  }
  Ok(())
}

///|
/// Build a roster while limiting consecutive occupied slot values.
///
/// Slot values are treated as equally sized time units. For example, a limit
/// of two permits work in slots 9 and 10, but not 9, 10, and 11. Missing slot
/// values break a sequence. Standard workload and rest policy rules still
/// apply.
pub fn build_roster_with_consecutive_limit(
  workers : Array[Worker],
  shifts : Array[Shift],
  policy : RosterPolicy,
  maximum_consecutive_slots : Int,
) -> Result[Roster, RosterError] {
  if maximum_consecutive_slots <= 0 {
    return Err(InvalidConsecutiveWorkLimit(maximum_consecutive_slots))
  }
  match validate_roster_policy(policy) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match build_roster_model(workers, shifts) {
    Err(error) => Err(error)
    Ok(model) => {
      match apply_roster_policy(model, workers, shifts, policy) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      match
        add_consecutive_work_constraints(
          model, workers, shifts, maximum_consecutive_slots,
        ) {
        Err(error) => return Err(error)
        Ok(_) => ()
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
