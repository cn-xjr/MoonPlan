///|
priv struct CoverageFindingJson {
  code : String
  message : String
  worker_id : Int?
  requirement_id : Int?
  requirement_name : String?
  slot : Int?
  required : Int?
  assignable : Int?
} derive(ToJson)

///|
priv struct CoverageAnalysisJson {
  preflight_passed : Bool
  issues : Array[CoverageFindingJson]
} derive(ToJson)

///|
fn CoverageIssue::to_finding_json(self : CoverageIssue) -> CoverageFindingJson {
  match self {
    CoverageDuplicateWorkerId(id) =>
      {
        code: "duplicate_worker_id",
        message: self.message(),
        worker_id: Some(id),
        requirement_id: None,
        requirement_name: None,
        slot: None,
        required: None,
        assignable: None,
      }
    CoverageNoEligibleWorker(id, name) =>
      {
        code: "no_eligible_worker",
        message: self.message(),
        worker_id: None,
        requirement_id: Some(id),
        requirement_name: Some(name),
        slot: None,
        required: None,
        assignable: None,
      }
    CoverageSlotShortfall(slot, required, assignable) =>
      {
        code: "slot_shortfall",
        message: self.message(),
        worker_id: None,
        requirement_id: None,
        requirement_name: None,
        slot: Some(slot),
        required: Some(required),
        assignable: Some(assignable),
      }
  }
}

///|
/// Encode definite coverage issues with stable machine-readable codes.
///
/// A passing preflight is not proof that workload or rest rules can be met.
pub fn encode_coverage_analysis(
  analysis : CoverageAnalysis,
  indent : Int,
) -> String {
  let issues : Array[CoverageFindingJson] = []
  for issue in analysis.issues {
    issues.push(issue.to_finding_json())
  }
  let result : CoverageAnalysisJson = {
    preflight_passed: analysis.is_feasible(),
    issues,
  }
  @json.to_json(result).stringify(indent~)
}
