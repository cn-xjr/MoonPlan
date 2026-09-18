///|
test "finds a solution at the exact node budget" {
  let problem = @moonplan.Problem::new()
  let worker = problem.add_variable("worker", [7]).unwrap()
  problem.add_constraint(@moonplan.Equal(worker, 7)).unwrap()
  match problem.solve_with_node_limit(1, @moonplan.Mrv).unwrap() {
    @moonplan.Found(solution, stats) => {
      assert_eq(solution.get("worker"), Some(7))
      assert_eq(stats.nodes, 1)
    }
    _ => fail("one attempted assignment must find the solution")
  }
}

///|
test "reports an incomplete search without claiming unsatisfiability" {
  let problem = @moonplan.Problem::new()
  let first = problem.add_variable("first", [0, 1]).unwrap()
  let second = problem.add_variable("second", [0, 1]).unwrap()
  let third = problem.add_variable("third", [0, 1]).unwrap()
  problem.add_constraint(@moonplan.Different(first, second)).unwrap()
  problem.add_constraint(@moonplan.Different(second, third)).unwrap()
  problem.add_constraint(@moonplan.Different(first, third)).unwrap()
  match problem.solve_with_node_limit(1, @moonplan.DegreeLcv).unwrap() {
    @moonplan.BudgetExhausted(stats) => {
      assert_eq(stats.nodes, 1)
      assert_eq(stats.solutions, 0)
    }
    _ => fail("a one-node search cannot prove this model unsatisfiable")
  }
  match problem.solve_with_node_limit(4, @moonplan.DegreeLcv).unwrap() {
    @moonplan.ProvedUnsatisfiable(stats) => assert_eq(stats.nodes, 4)
    _ => fail("an exactly sufficient budget must prove unsatisfiability")
  }
}

///|
test "proves a root contradiction without spending a node" {
  let problem = @moonplan.Problem::new()
  let worker = problem.add_variable("worker", [1]).unwrap()
  problem.add_constraint(@moonplan.Equal(worker, 1)).unwrap()
  problem.add_constraint(@moonplan.NotEqual(worker, 1)).unwrap()
  match problem.solve_with_node_limit(1, @moonplan.Mrv).unwrap() {
    @moonplan.ProvedUnsatisfiable(stats) => assert_eq(stats.nodes, 0)
    _ => fail("a root contradiction is already proven")
  }
}

///|
test "rejects a non-positive node budget" {
  assert_true(
    @moonplan.Problem::new().solve_with_node_limit(0, @moonplan.Mrv)
    is Err(@moonplan.InvalidNodeLimit(0)),
  )
}

///|
test "solves an empty model without spending a node" {
  match
    @moonplan.Problem::new().solve_with_node_limit(1, @moonplan.Mrv).unwrap() {
    @moonplan.Found(_, stats) => assert_eq(stats.nodes, 0)
    _ => fail("an empty model has one empty solution")
  }
}
