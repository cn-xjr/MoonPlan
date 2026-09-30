///|
fn available_days(days : Int, absent_day : Int, shift_kind : Int) -> Array[Int] {
  let slots : Array[Int] = []
  for day = 0; day < days; day = day + 1 {
    if day != absent_day {
      slots.push(day * 2 + shift_kind)
    }
  }
  slots
}

///|
fn benchmark_request(days : Int) -> @moonplan.CoverageRequest {
  let support_workers = (days * 2 + 3) / 4 + 1
  let front_workers = (days + 3) / 4 + 1
  let workers : Array[@moonplan.Worker] = []
  for index = 0; index < support_workers; index = index + 1 {
    workers.push({
      id: index + 1,
      name: "Support \{index + 1}",
      skills: ["support"],
      available_slots: available_days(days, index % days, 0),
    })
  }
  for index = 0; index < front_workers; index = index + 1 {
    workers.push({
      id: support_workers + index + 1,
      name: "Front \{index + 1}",
      skills: ["front"],
      available_slots: available_days(days, index % days, 1),
    })
  }
  let requirements : Array[@moonplan.CoverageRequirement] = []
  for day = 0; day < days; day = day + 1 {
    requirements.push({
      id: day * 2 + 1,
      name: "Support day \{day + 1}",
      slot: day * 2,
      required_skill: "support",
      workers_needed: 2,
    })
    requirements.push({
      id: day * 2 + 2,
      name: "Front day \{day + 1}",
      slot: day * 2 + 1,
      required_skill: "front",
      workers_needed: 1,
    })
  }
  {
    workers,
    requirements,
    policy: { max_shifts_per_worker: Some(4), minimum_slot_gap: 0, },
  }
}

///|
fn outcome_stats(
  outcome : @moonplan.CoverageSolveOutcome,
) -> (String, Int, Int) {
  match outcome {
    @moonplan.CoverageFound(roster) =>
      ("found", roster.stats.nodes, roster.stats.backtracks)
    @moonplan.CoverageProvedUnsatisfiable(stats) =>
      ("unsatisfiable", stats.nodes, stats.backtracks)
    @moonplan.CoverageBudgetExhausted(stats) =>
      ("budget_exhausted", stats.nodes, stats.backtracks)
  }
}

///|
fn run_case(
  days : Int,
  strategy : @moonplan.SearchStrategy,
  label : String,
  repetitions : Int,
) -> Unit raise {
  let request = benchmark_request(days)
  let start = @env.now()
  let mut status = ""
  let mut nodes = 0
  let mut backtracks = 0
  for iteration = 0; iteration < repetitions; iteration = iteration + 1 {
    let outcome = match request.solve_with_strategy(2000, strategy) {
      Err(error) => fail(error.message())
      Ok(outcome) => outcome
    }
    let (current_status, current_nodes, current_backtracks) = outcome_stats(
      outcome,
    )
    if iteration > 0 &&
      (
        status != current_status ||
        nodes != current_nodes ||
        backtracks != current_backtracks
      ) {
      fail("the same benchmark input produced different search evidence")
    }
    status = current_status
    nodes = current_nodes
    backtracks = current_backtracks
  }
  let elapsed = @env.now() - start
  println(
    "coverage_\{days}d,\{label},\{days * 3},\{repetitions},\{status},\{nodes},\{backtracks},\{elapsed}",
  )
}

///|
fn queens_problem(size : Int) -> @moonplan.Problem {
  let problem = @moonplan.Problem::new()
  let queens : Array[@moonplan.Var] = []
  for column = 0; column < size; column = column + 1 {
    queens.push(
      problem
      .add_variable("q\{column}", @moonplan.int_domain(0, size - 1))
      .unwrap(),
    )
  }
  problem.add_constraint(@moonplan.AllDifferent(queens.copy())).unwrap()
  for left = 0; left < size; left = left + 1 {
    for right = left + 1; right < size; right = right + 1 {
      let delta = right - left
      problem
      .add_constraint(
        @moonplan.OffsetDifferent(queens[right], queens[left], delta),
      )
      .unwrap()
      problem
      .add_constraint(
        @moonplan.OffsetDifferent(queens[right], queens[left], -delta),
      )
      .unwrap()
    }
  }
  problem
}

///|
fn run_queens(
  size : Int,
  strategy : @moonplan.SearchStrategy,
  label : String,
  repetitions : Int,
) -> Unit raise {
  let problem = queens_problem(size)
  let start = @env.now()
  let mut status = ""
  let mut nodes = 0
  let mut backtracks = 0
  for iteration = 0; iteration < repetitions; iteration = iteration + 1 {
    let outcome = problem.solve_with_node_limit(20000, strategy).unwrap()
    let (current_status, current_nodes, current_backtracks) = match outcome {
      @moonplan.Found(_, stats) => ("found", stats.nodes, stats.backtracks)
      @moonplan.ProvedUnsatisfiable(stats) =>
        ("unsatisfiable", stats.nodes, stats.backtracks)
      @moonplan.BudgetExhausted(stats) =>
        ("budget_exhausted", stats.nodes, stats.backtracks)
    }
    if iteration > 0 &&
      (
        status != current_status ||
        nodes != current_nodes ||
        backtracks != current_backtracks
      ) {
      fail("the same queens model produced different search evidence")
    }
    status = current_status
    nodes = current_nodes
    backtracks = current_backtracks
  }
  let elapsed = @env.now() - start
  println(
    "queens_\{size},\{label},\{size},\{repetitions},\{status},\{nodes},\{backtracks},\{elapsed}",
  )
}

///|
fn main raise {
  println(
    "case,strategy,variables,repetitions,status,nodes,backtracks,total_ms",
  )
  for days in [4, 7, 10] {
    let repetitions = if days == 10 { 2 } else { 5 }
    run_case(days, @moonplan.Mrv, "mrv", repetitions)
    run_case(days, @moonplan.DegreeLcv, "degree_lcv", repetitions)
  }
  for size in [8, 10] {
    let repetitions = if size == 10 { 1 } else { 3 }
    run_queens(size, @moonplan.Mrv, "mrv", repetitions)
    run_queens(size, @moonplan.DegreeLcv, "degree_lcv", repetitions)
  }
}
