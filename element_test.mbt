///|
test "selects a value by element index" {
  let problem = @moonplan.Problem::new()
  let index = problem.add_variable("plan", [0, 1, 2]).unwrap()
  let cost = problem.add_variable("cost", [12, 20, 35]).unwrap()
  problem.add_constraint(@moonplan.Element(index, [12, 20, 35], cost)).unwrap()
  problem.add_constraint(@moonplan.Equal(index, 1)).unwrap()
  match problem.solve() {
    @moonplan.Unsatisfied(_) => fail("the selected plan must have a cost")
    @moonplan.Satisfied(solution, _) => {
      assert_eq(solution.get("plan"), Some(1))
      assert_eq(solution.get("cost"), Some(20))
    }
  }
}

///|
test "prunes element indexes that cannot produce the target" {
  let problem = @moonplan.Problem::new()
  let index = problem.add_variable("plan", [0, 1, 2]).unwrap()
  let cost = problem.add_variable("cost", [20, 35]).unwrap()
  problem.add_constraint(@moonplan.Element(index, [12, 20, 35], cost)).unwrap()
  problem.add_constraint(@moonplan.Equal(cost, 35)).unwrap()
  match problem.solve() {
    @moonplan.Unsatisfied(_) => fail("one plan must produce the target cost")
    @moonplan.Satisfied(solution, _) => {
      assert_eq(solution.get("plan"), Some(2))
      assert_eq(solution.get("cost"), Some(35))
    }
  }
}

///|
test "reports an element relation with no compatible value" {
  let problem = @moonplan.Problem::new()
  let index = problem.add_variable("plan", [0, 1]).unwrap()
  let cost = problem.add_variable("cost", [99]).unwrap()
  problem.add_constraint(@moonplan.Element(index, [12, 20], cost)).unwrap()
  assert_true(problem.solve() is @moonplan.Unsatisfied(_))
}

///|
test "validates element table boundaries" {
  let problem = @moonplan.Problem::new()
  let valid_index = problem.add_variable("valid", [0]).unwrap()
  let invalid_index = problem.add_variable("invalid", [-1, 1]).unwrap()
  let target = problem.add_variable("target", [10]).unwrap()
  assert_true(
    problem.add_constraint(@moonplan.Element(valid_index, [], target))
    is Err(@moonplan.EmptyElementTable),
  )
  assert_true(
    problem.add_constraint(@moonplan.Element(invalid_index, [10], target))
    is Err(@moonplan.ElementIndexOutsideTable("invalid", -1, 1)),
  )
}

///|
test "keeps element values stable after caller mutation" {
  let problem = @moonplan.Problem::new()
  let index = problem.add_variable("plan", [0]).unwrap()
  let target = problem.add_variable("cost", [10, 99]).unwrap()
  let values = [10]
  problem.add_constraint(@moonplan.Element(index, values, target)).unwrap()
  values[0] = 99
  match problem.solve() {
    @moonplan.Unsatisfied(_) =>
      fail("the copied value table must remain usable")
    @moonplan.Satisfied(solution, _) =>
      assert_eq(solution.get("cost"), Some(10))
  }
}
