///|
/// A definite input or slot-capacity problem in a coverage request.
pub(all) enum CoverageIssue {
  CoverageDuplicateWorkerId(Int)
  CoverageNoEligibleWorker(Int, String)
  CoverageSlotShortfall(Int, Int, Int)
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
