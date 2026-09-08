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
