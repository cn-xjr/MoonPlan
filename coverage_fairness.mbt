///|
/// A roster whose workload spread was proven minimal within all hard rules.
pub(all) struct FairCoverageRoster {
  roster : CoverageRoster
  balance : BalanceScore
  windows_checked : Int
  total_nodes : Int
  total_backtracks : Int
} derive(Eq, Debug, ToJson)

///|
/// An exact fairness search can finish, prove infeasibility, or exhaust its
/// global assignment budget. An exhausted search makes no optimality claim.
pub(all) enum FairCoverageOutcome {
  FairCoverageFound(FairCoverageRoster)
  FairCoverageProvedUnsatisfiable(SolveStats, Int)
  FairCoverageBudgetExhausted(SolveStats, Int)
} derive(Eq, Debug)

///|
fn fairness_stats(nodes : Int, backtracks : Int, solutions : Int) -> SolveStats {
  { nodes, backtracks, solutions, }
}

///|
/// Find a coverage roster with the globally smallest workload spread.
///
/// Every trial constrains each worker's assignments to an inclusive range.
/// Ranges are tried in increasing width, then increasing upper bound. The
/// `node_limit` is shared by all trials; exhaustion never returns a claim of
/// optimality or infeasibility.
pub fn build_fairest_coverage_roster(
  workers : Array[Worker],
  requirements : Array[CoverageRequirement],
  policy : RosterPolicy,
  node_limit : Int,
) -> Result[FairCoverageOutcome, RosterError] {
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
  let positions = expansion.shifts.length()
  if workers.length() == 0 {
    match build_coverage_roster(workers, requirements, policy) {
      Err(error) => return Err(error)
      Ok(roster) =>
        return Ok(
          FairCoverageFound({
            roster,
            balance: { minimum_load: 0, maximum_load: 0, spread: 0, },
            windows_checked: 1,
            total_nodes: 0,
            total_backtracks: 0,
          }),
        )
    }
  }
  let average_floor = positions / workers.length()
  let average_ceil = average_floor +
    (if positions % workers.length() == 0 { 0 } else { 1 })
  let mut total_nodes = 0
  let mut total_backtracks = 0
  let mut windows_checked = 0
  for width = 0; width <= positions; width = width + 1 {
    let first_lower = if average_ceil > width {
      average_ceil - width
    } else {
      0
    }
    for lower = first_lower; lower <= average_floor; lower = lower + 1 {
      if total_nodes >= node_limit {
        return Ok(
          FairCoverageBudgetExhausted(
            fairness_stats(total_nodes, total_backtracks, 0),
            windows_checked,
          ),
        )
      }
      let model = match build_roster_model(workers, expansion.shifts) {
        Err(error) => return Err(error)
        Ok(model) => model
      }
      match apply_roster_policy(model, workers, expansion.shifts, policy) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      let quotas : Array[WorkerQuota] = []
      for worker in workers {
        quotas.push({
          worker_id: worker.id,
          minimum_shifts: lower,
          maximum_shifts: lower + width,
        })
      }
      match add_worker_quotas(model, workers, expansion.shifts, quotas) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      windows_checked = windows_checked + 1
      let search = match
        model.problem.solve_with_node_limit(node_limit - total_nodes, Mrv) {
        Err(error) => return Err(InvalidModel(error))
        Ok(outcome) => outcome
      }
      match search {
        Found(solution, stats) => {
          total_nodes = total_nodes + stats.nodes
          total_backtracks = total_backtracks + stats.backtracks
          let ordinary_roster = roster_from_solution(
            workers,
            expansion.shifts,
            model.variables,
            solution,
            stats,
          )
          let balance = balance_score(workers, ordinary_roster)
          let roster = coverage_roster_from_roster(
            ordinary_roster, requirements, expansion,
          )
          return Ok(
            FairCoverageFound({
              roster,
              balance,
              windows_checked,
              total_nodes,
              total_backtracks,
            }),
          )
        }
        ProvedUnsatisfiable(stats) => {
          total_nodes = total_nodes + stats.nodes
          total_backtracks = total_backtracks + stats.backtracks
        }
        BudgetExhausted(stats) => {
          total_nodes = total_nodes + stats.nodes
          total_backtracks = total_backtracks + stats.backtracks
          return Ok(
            FairCoverageBudgetExhausted(
              fairness_stats(total_nodes, total_backtracks, 0),
              windows_checked,
            ),
          )
        }
      }
    }
  }
  Ok(
    FairCoverageProvedUnsatisfiable(
      fairness_stats(total_nodes, total_backtracks, 0),
      windows_checked,
    ),
  )
}
