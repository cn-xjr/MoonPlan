///|
test "structured coverage findings retain their original identifiers" {
  let analysis : @moonplan.CoverageAnalysis = {
    issues: [
      @moonplan.CoverageDuplicateWorkerId(4),
      @moonplan.CoverageNoEligibleWorker(17, "Night desk"),
      @moonplan.CoverageSlotShortfall(9, 3, 1),
    ],
  }
  let output = @moonplan.encode_coverage_analysis(analysis, 2)
  assert_true(output.contains("\"preflight_passed\": false"))
  assert_true(output.contains("\"code\": \"duplicate_worker_id\""))
  assert_true(output.contains("\"worker_id\": 4"))
  assert_true(output.contains("\"code\": \"no_eligible_worker\""))
  assert_true(output.contains("\"requirement_id\": 17"))
  assert_true(output.contains("\"requirement_name\": \"Night desk\""))
  assert_true(output.contains("\"code\": \"slot_shortfall\""))
  assert_true(output.contains("\"slot\": 9"))
  assert_true(output.contains("\"required\": 3"))
  assert_true(output.contains("\"assignable\": 1"))
}

///|
test "passing coverage preflight encodes an empty issue list" {
  let analysis : @moonplan.CoverageAnalysis = { issues: [], }
  assert_eq(
    @moonplan.encode_coverage_analysis(analysis, 0),
    "{\"preflight_passed\":true,\"issues\":[]}",
  )
}
