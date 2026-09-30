///|
/// A staffing demand that requires several distinct workers in one slot.
pub(all) struct CoverageRequirement {
  id : Int
  name : String
  slot : Int
  required_skill : String
  workers_needed : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
/// One filled position within a coverage requirement.
///
/// Positions are numbered from one in deterministic requirement order.
pub(all) struct CoverageEntry {
  requirement : CoverageRequirement
  position : Int
  worker : Worker
} derive(Eq, Debug, ToJson)

///|
/// A fulfilled set of staffing demands together with solver evidence.
pub(all) struct CoverageRoster {
  entries : Array[CoverageEntry]
  stats : SolveStats
} derive(Eq, Debug, ToJson)

///|
/// A bounded coverage search distinguishes a roster from a proof of
/// infeasibility and from an incomplete search.
pub(all) enum CoverageSolveOutcome {
  CoverageFound(CoverageRoster)
  CoverageProvedUnsatisfiable(SolveStats)
  CoverageBudgetExhausted(SolveStats)
} derive(Eq, Debug)

///|
priv struct CoverageExpansion {
  shifts : Array[Shift]
  requirement_indexes : Array[Int]
  positions : Array[Int]
}

///|
fn validate_coverage_requirements(
  requirements : Array[CoverageRequirement],
) -> Result[Unit, RosterError] {
  for index = 0; index < requirements.length(); index = index + 1 {
    let requirement = requirements[index]
    if requirement.workers_needed <= 0 {
      return Err(
        InvalidCoverageWorkerCount(requirement.id, requirement.workers_needed),
      )
    }
    for previous = 0; previous < index; previous = previous + 1 {
      if requirements[previous].id == requirement.id {
        return Err(DuplicateCoverageRequirementId(requirement.id))
      }
    }
  }
  Ok(())
}

///|
fn expand_coverage_requirements(
  requirements : Array[CoverageRequirement],
) -> CoverageExpansion {
  let shifts : Array[Shift] = []
  let requirement_indexes : Array[Int] = []
  let positions : Array[Int] = []
  for requirement_index = 0
      requirement_index < requirements.length()
      requirement_index = requirement_index + 1 {
    let requirement = requirements[requirement_index]
    for position = 1
        position <= requirement.workers_needed
        position = position + 1 {
      shifts.push({
        id: shifts.length(),
        name: "\{requirement.name} #\{position}",
        slot: requirement.slot,
        required_skill: requirement.required_skill,
      })
      requirement_indexes.push(requirement_index)
      positions.push(position)
    }
  }
  { shifts, requirement_indexes, positions, }
}

///|
fn coverage_roster_from_roster(
  roster : Roster,
  requirements : Array[CoverageRequirement],
  expansion : CoverageExpansion,
) -> CoverageRoster {
  let entries : Array[CoverageEntry] = []
  for entry in roster.entries {
    let shift_index = entry.shift.id
    entries.push({
      requirement: requirements[expansion.requirement_indexes[shift_index]],
      position: expansion.positions[shift_index],
      worker: entry.worker,
    })
  }
  { entries, stats: roster.stats, }
}

///|
/// Fill every requested position under the standard roster policy.
///
/// A worker cannot fill two positions in the same slot. Skill, availability,
/// workload, and rest rules are enforced by the regular roster model.
pub fn build_coverage_roster(
  workers : Array[Worker],
  requirements : Array[CoverageRequirement],
  policy : RosterPolicy,
) -> Result[CoverageRoster, RosterError] {
  match validate_coverage_requirements(requirements) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let expansion = expand_coverage_requirements(requirements)
  match build_roster_with_policy(workers, expansion.shifts, policy) {
    Err(error) => Err(error)
    Ok(roster) =>
      Ok(coverage_roster_from_roster(roster, requirements, expansion))
  }
}

///|
/// Fill multi-worker demands while limiting consecutive occupied slots.
///
/// This applies the same skill, availability, workload, and rest policy as
/// `build_coverage_roster`, plus the requested consecutive-work limit.
pub fn build_coverage_roster_with_consecutive_limit(
  workers : Array[Worker],
  requirements : Array[CoverageRequirement],
  policy : RosterPolicy,
  maximum_consecutive_slots : Int,
) -> Result[CoverageRoster, RosterError] {
  match validate_coverage_requirements(requirements) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let expansion = expand_coverage_requirements(requirements)
  match
    build_roster_with_consecutive_limit(
      workers,
      expansion.shifts,
      policy,
      maximum_consecutive_slots,
    ) {
    Err(error) => Err(error)
    Ok(roster) =>
      Ok(coverage_roster_from_roster(roster, requirements, expansion))
  }
}

///|
/// Search for a coverage roster within at most `node_limit` assignments.
///
/// Exhausting the budget does not prove that a roster is impossible. Model
/// validation errors are returned separately from all three search outcomes.
pub fn build_coverage_roster_with_node_limit(
  workers : Array[Worker],
  requirements : Array[CoverageRequirement],
  policy : RosterPolicy,
  node_limit : Int,
) -> Result[CoverageSolveOutcome, RosterError] {
  if node_limit <= 0 {
    return Err(InvalidModel(InvalidNodeLimit(node_limit)))
  }
  match validate_coverage_requirements(requirements) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match validate_roster_policy(policy) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let expansion = expand_coverage_requirements(requirements)
  let model = match build_roster_model(workers, expansion.shifts) {
    Err(error) => return Err(error)
    Ok(model) => model
  }
  match apply_roster_policy(model, workers, expansion.shifts, policy) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match model.problem.solve_with_node_limit(node_limit, Mrv) {
    Err(error) => Err(InvalidModel(error))
    Ok(Found(solution, stats)) =>
      Ok(
        CoverageFound(
          coverage_roster_from_roster(
            roster_from_solution(
              workers,
              expansion.shifts,
              model.variables,
              solution,
              stats,
            ),
            requirements,
            expansion,
          ),
        ),
      )
    Ok(ProvedUnsatisfiable(stats)) => Ok(CoverageProvedUnsatisfiable(stats))
    Ok(BudgetExhausted(stats)) => Ok(CoverageBudgetExhausted(stats))
  }
}

///|
/// Return the workers assigned to one coverage requirement, in position order.
pub fn CoverageRoster::workers_for_requirement(
  self : CoverageRoster,
  requirement_id : Int,
) -> Array[Worker] {
  let workers : Array[Worker] = []
  for entry in self.entries {
    if entry.requirement.id == requirement_id {
      workers.push(entry.worker)
    }
  }
  workers
}
