///|
/// A definite input or slot-capacity problem in a coverage request.
pub(all) enum CoverageIssue {
  CoverageDuplicateWorkerId(Int)
  CoverageNoEligibleWorker(Int, String)
  CoverageSlotShortfall(Int, Int, Int)
  CoverageWorkloadShortfall(Int, Int)
} derive(Eq, Debug)

///|
pub fn CoverageIssue::message(self : CoverageIssue) -> String {
  match self {
    CoverageDuplicateWorkerId(id) =>
      "worker id \{id} is declared more than once"
    CoverageNoEligibleWorker(id, name) =>
      "coverage requirement \{id} (\{name}) has no eligible worker"
    CoverageSlotShortfall(slot, required, assignable) =>
      "slot \{slot} needs \{required} workers, but at most \{assignable} positions can be filled"
    CoverageWorkloadShortfall(required, assignable) =>
      "coverage needs \{required} assignments, but worker workload limits allow at most \{assignable}"
  }
}

///|
/// Preflight issues reported against original coverage demand identifiers.
pub(all) struct CoverageAnalysis {
  issues : Array[CoverageIssue]
} derive(Eq, Debug)

///|
pub fn CoverageAnalysis::is_feasible(self : CoverageAnalysis) -> Bool {
  self.issues.length() == 0
}

///|
pub fn CoverageAnalysis::summary(self : CoverageAnalysis) -> String {
  if self.is_feasible() {
    return "coverage request passed preflight analysis"
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
/// Find definite demand conflicts before applying workload or rest policy.
///
/// This does not prove that a policy-constrained roster is feasible.
pub fn analyze_coverage(
  workers : Array[Worker],
  requirements : Array[CoverageRequirement],
) -> Result[CoverageAnalysis, RosterError] {
  match validate_coverage_requirements(requirements) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let expansion = expand_coverage_requirements(requirements)
  let roster_analysis = analyze_roster(workers, expansion.shifts)
  let issues : Array[CoverageIssue] = []
  let reported = Array::make(requirements.length(), false)
  for issue in roster_analysis.issues {
    match issue {
      DuplicateWorkerIdFound(id) => issues.push(CoverageDuplicateWorkerId(id))
      NoEligibleWorkerFound(shift_id, _) => {
        let index = expansion.requirement_indexes[shift_id]
        if !reported[index] {
          let requirement = requirements[index]
          issues.push(
            CoverageNoEligibleWorker(requirement.id, requirement.name),
          )
          reported[index] = true
        }
      }
      SlotCoverageShortfall(slot, required, assignable) =>
        issues.push(CoverageSlotShortfall(slot, required, assignable))
      DuplicateShiftIdFound(_) => ()
    }
  }
  Ok({ issues, })
}

///|
/// Find definite coverage conflicts under the requested roster policy.
///
/// The workload bound counts each worker's distinct eligible slots, capped
/// by their workload limit. Rest rules can make capacity smaller, so a
/// passing analysis is not a proof that a roster exists.
pub fn analyze_coverage_with_policy(
  workers : Array[Worker],
  requirements : Array[CoverageRequirement],
  policy : RosterPolicy,
) -> Result[CoverageAnalysis, RosterError] {
  match validate_roster_policy(policy) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let analysis = match analyze_coverage(workers, requirements) {
    Err(error) => return Err(error)
    Ok(analysis) => analysis
  }
  if !analysis.is_feasible() {
    return Ok(analysis)
  }
  match policy.max_shifts_per_worker {
    None => Ok(analysis)
    Some(limit) => {
      let mut required = 0
      for requirement in requirements {
        required = required + requirement.workers_needed
      }
      let mut assignable = 0
      for worker in workers {
        let slots : Array[Int] = []
        for requirement in requirements {
          if worker.skills.contains(requirement.required_skill) &&
            worker.available_slots.contains(requirement.slot) &&
            !int_member(slots, requirement.slot) {
            slots.push(requirement.slot)
          }
        }
        let worker_capacity = if slots.length() < limit {
          slots.length()
        } else {
          limit
        }
        assignable = assignable + worker_capacity
      }
      if assignable < required {
        analysis.issues.push(CoverageWorkloadShortfall(required, assignable))
      }
      Ok(analysis)
    }
  }
}
