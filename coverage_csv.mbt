///|
/// Quote one name and neutralize common spreadsheet formula prefixes.
fn coverage_csv_name(value : String) -> String {
  let text = if value.has_prefix("=") ||
    value.has_prefix("+") ||
    value.has_prefix("-") ||
    value.has_prefix("@") ||
    value.has_prefix("\t") ||
    value.has_prefix("\r") {
    "'" + value
  } else {
    value
  }
  if text.contains(",") ||
    text.contains("\"") ||
    text.contains("\r") ||
    text.contains("\n") {
    "\"" + text.replace_all(old="\"", new="\"\"") + "\""
  } else {
    text
  }
}

///|
/// Export filled positions as UTF-8 CSV in stable roster order.
///
/// Requirement and worker names are quoted when needed; formula-like names
/// receive a leading apostrophe to reduce formula interpretation risk.
pub fn encode_coverage_roster_csv(roster : CoverageRoster) -> String {
  let mut output = "requirement_id,requirement_name,slot,position,worker_id,worker_name"
  for entry in roster.entries {
    output = output +
      "\r\n\{entry.requirement.id},\{coverage_csv_name(entry.requirement.name)},\{entry.requirement.slot},\{entry.position},\{entry.worker.id},\{coverage_csv_name(entry.worker.name)}"
  }
  output
}
