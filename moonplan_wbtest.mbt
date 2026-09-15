///|
test "integer domains are inclusive" {
  assert_eq(int_domain(2, 5), [2, 3, 4, 5])
  assert_eq(int_domain(5, 2), [])
}

///|
test "sum bounds prune impossible partial assignments" {
  let problem = Problem::new()
  let a = problem.add_variable("a", [1, 2]).unwrap()
  let b = problem.add_variable("b", [1, 2]).unwrap()
  problem.add_constraint(SumEquals([a, b], 9)).unwrap()
  let assignment : Array[Int?] = [None, None]
  assert_false(all_constraints_possible(problem, assignment))
}

///|
test "degree tie break chooses the most connected variable" {
  let problem = Problem::new()
  let leaf_a = problem.add_variable("leaf-a", [0, 1]).unwrap()
  let leaf_b = problem.add_variable("leaf-b", [0, 1]).unwrap()
  let hub = problem.add_variable("hub", [0, 1]).unwrap()
  problem.add_constraint(Different(hub, leaf_a)).unwrap()
  problem.add_constraint(Different(hub, leaf_b)).unwrap()
  let assignment : Array[Int?] = [None, None, None]
  match choose_variable(problem, assignment, DegreeLcv) {
    None => fail("the model has unassigned variables")
    Some((index, _)) => assert_eq(index, hub.index)
  }
}

///|
test "LCV tries the value that preserves more choices first" {
  let problem = Problem::new()
  let left = problem.add_variable("left", [1, 0]).unwrap()
  let right = problem.add_variable("right", [0, 1, 2]).unwrap()
  problem.add_constraint(LessThan(left, right)).unwrap()
  let assignment : Array[Int?] = [None, None]
  match choose_variable(problem, assignment, Mrv) {
    None => fail("the model has unassigned variables")
    Some((_, values)) => assert_eq(values, [1, 0])
  }
  match choose_variable(problem, assignment, DegreeLcv) {
    None => fail("the model has unassigned variables")
    Some((_, values)) => assert_eq(values, [0, 1])
  }
}
