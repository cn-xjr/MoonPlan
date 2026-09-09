///|
/// One rule retained in an irreducible conflict set.
pub(all) struct ConflictItem {
  index : Int
  name : String?
  constraint : Constraint
} derive(Eq, Debug)

///|
/// A subset-minimal explanation for an unsatisfiable problem.
///
/// Removing any one item from this report makes the retained constraint set
/// satisfiable. `solver_runs` exposes the diagnostic cost.
pub(all) struct ConflictReport {
  items : Array[ConflictItem]
  solver_runs : Int
} derive(Eq, Debug)

///|
/// Result of checking a model for a conflict explanation.
pub(all) enum ExplainOutcome {
  Consistent(SolveStats)
  Inconsistent(ConflictReport)
} derive(Eq, Debug)

///|
fn Problem::with_included_constraints(
  self : Problem,
  included : Array[Bool],
) -> Problem {
  let constraints : Array[ConstraintSpec] = []
  for index = 0; index < self.constraints.length(); index = index + 1 {
    if included[index] {
      constraints.push(self.constraints[index])
    }
  }
  { variables: self.variables.copy(), constraints, }
}

///|
/// Explain why a problem is unsatisfiable.
///
/// The deletion-based pass returns an irreducible conflict set: every reported
/// constraint is necessary for the conflict within the returned set. The
/// original problem is not mutated.
pub fn Problem::explain(self : Problem) -> ExplainOutcome {
  match self.solve() {
    Satisfied(_, stats) => Consistent(stats)
    Unsatisfied(_) => {
      let included = Array::make(self.constraints.length(), true)
      let mut solver_runs = 1
      for index = 0; index < included.length(); index = index + 1 {
        included[index] = false
        let candidate = self.with_included_constraints(included)
        solver_runs = solver_runs + 1
        match candidate.solve() {
          Unsatisfied(_) => ()
          Satisfied(_, _) => included[index] = true
        }
      }
      let items : Array[ConflictItem] = []
      for index = 0; index < included.length(); index = index + 1 {
        if included[index] {
          let spec = self.constraints[index]
          items.push({ index, name: spec.name, constraint: spec.constraint, })
        }
      }
      Inconsistent({ items, solver_runs, })
    }
  }
}
