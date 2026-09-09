///|
/// A stable handle to a finite-domain variable.
pub(all) struct Var {
  index : Int
  name : String
} derive(Eq, Debug)

///|
/// Built-in constraints supported by the first MoonPlan solver kernel.
pub(all) enum Constraint {
  Equal(Var, Int)
  NotEqual(Var, Int)
  Different(Var, Var)
  OffsetDifferent(Var, Var, Int)
  LessThan(Var, Var)
  AllDifferent(Array[Var])
  SumEquals(Array[Var], Int)
  CountAtMost(Array[Var], Int, Int)
  AllowedTuples(Array[Var], Array[Array[Int]])
} derive(Eq, Debug)

///|
/// Errors rejected at the modeling boundary.
pub(all) enum ModelError {
  EmptyName
  DuplicateName(String)
  EmptyConstraintName
  DuplicateConstraintName(String)
  EmptyDomain(String)
  DuplicateDomainValue(String, Int)
  ForeignVariable(String)
  EmptyConstraint
  EmptyTupleTable
  InvalidTupleArity(Int, Int, Int)
  TupleValueOutsideDomain(Int, String, Int)
  DuplicateTuple(Int, Int)
  InvalidConstraintLimit(Int)
  InvalidSolutionLimit(Int)
  InvalidTraceLimit(Int)
} derive(Eq, Debug)

///|
/// Convert a modeling error into a concise diagnostic.
pub fn ModelError::message(self : ModelError) -> String {
  match self {
    EmptyName => "variable name must not be empty"
    DuplicateName(name) => "duplicate variable name: \{name}"
    EmptyConstraintName => "constraint name must not be empty"
    DuplicateConstraintName(name) => "duplicate constraint name: \{name}"
    EmptyDomain(name) => "variable \{name} has an empty domain"
    DuplicateDomainValue(name, value) =>
      "variable \{name} repeats domain value \{value}"
    ForeignVariable(name) => "constraint refers to unknown variable: \{name}"
    EmptyConstraint => "constraint must contain at least one variable"
    EmptyTupleTable => "allowed tuple table must contain at least one row"
    InvalidTupleArity(index, expected, actual) =>
      "tuple \{index} must contain \{expected} values, got \{actual}"
    TupleValueOutsideDomain(index, name, value) =>
      "tuple \{index} uses value \{value} outside the domain of \{name}"
    DuplicateTuple(first, duplicate) =>
      "tuple \{duplicate} duplicates tuple \{first}"
    InvalidConstraintLimit(limit) =>
      "constraint limit must not be negative, got \{limit}"
    InvalidSolutionLimit(limit) =>
      "solution limit must be positive, got \{limit}"
    InvalidTraceLimit(limit) =>
      "trace event limit must be positive, got \{limit}"
  }
}

///|
struct VariableSpec {
  variable : Var
  domain : Array[Int]
} derive(Eq, Debug)

///|
struct ConstraintSpec {
  name : String?
  constraint : Constraint
}

///|
/// A finite-domain constraint problem.
pub struct Problem {
  variables : Array[VariableSpec]
  constraints : Array[ConstraintSpec]
}

///|
/// Create an empty constraint problem.
pub fn Problem::new() -> Problem {
  { variables: [], constraints: [], }
}

///|
/// Number of variables currently declared in the model.
pub fn Problem::variable_count(self : Problem) -> Int {
  self.variables.length()
}

///|
/// Number of constraints currently declared in the model.
pub fn Problem::constraint_count(self : Problem) -> Int {
  self.constraints.length()
}

///|
fn domain_has(domain : Array[Int], value : Int) -> Bool {
  for candidate in domain {
    if candidate == value {
      return true
    }
  }
  false
}

///|
/// Declare a variable and return its stable handle.
pub fn Problem::add_variable(
  self : Problem,
  name : String,
  domain : Array[Int],
) -> Result[Var, ModelError] {
  if name.length() == 0 {
    return Err(EmptyName)
  }
  for spec in self.variables {
    if spec.variable.name == name {
      return Err(DuplicateName(name))
    }
  }
  if domain.length() == 0 {
    return Err(EmptyDomain(name))
  }
  for i = 0; i < domain.length(); i = i + 1 {
    for j = 0; j < i; j = j + 1 {
      if domain[i] == domain[j] {
        return Err(DuplicateDomainValue(name, domain[i]))
      }
    }
  }
  let variable = { index: self.variables.length(), name, }
  self.variables.push({ variable, domain: domain.copy(), })
  Ok(variable)
}

///|
fn Problem::owns(self : Problem, variable : Var) -> Bool {
  variable.index >= 0 &&
  variable.index < self.variables.length() &&
  self.variables[variable.index].variable == variable
}

///|
fn constraint_variables(constraint : Constraint) -> Array[Var] {
  match constraint {
    Equal(variable, _) | NotEqual(variable, _) => [variable]
    Different(left, right)
    | OffsetDifferent(left, right, _)
    | LessThan(left, right) => [left, right]
    AllDifferent(variables)
    | SumEquals(variables, _)
    | CountAtMost(variables, _, _)
    | AllowedTuples(variables, _) => variables
  }
}

///|
fn stabilize_constraint(constraint : Constraint) -> Constraint {
  match constraint {
    AllDifferent(variables) => AllDifferent(variables.copy())
    SumEquals(variables, target) => SumEquals(variables.copy(), target)
    CountAtMost(variables, value, limit) =>
      CountAtMost(variables.copy(), value, limit)
    AllowedTuples(variables, tuples) => {
      let stable_tuples : Array[Array[Int]] = []
      for tuple in tuples {
        stable_tuples.push(tuple.copy())
      }
      AllowedTuples(variables.copy(), stable_tuples)
    }
    _ => constraint
  }
}

///|
/// Add a checked constraint to the problem.
pub fn Problem::add_constraint(
  self : Problem,
  constraint : Constraint,
) -> Result[Unit, ModelError] {
  self.add_constraint_spec(None, constraint)
}

///|
fn Problem::add_constraint_spec(
  self : Problem,
  name : String?,
  constraint : Constraint,
) -> Result[Unit, ModelError] {
  let stable_constraint = stabilize_constraint(constraint)
  match stable_constraint {
    CountAtMost(_, _, limit) if limit < 0 =>
      return Err(InvalidConstraintLimit(limit))
    _ => ()
  }
  let variables = constraint_variables(stable_constraint)
  if variables.length() == 0 {
    return Err(EmptyConstraint)
  }
  for variable in variables {
    if !self.owns(variable) {
      return Err(ForeignVariable(variable.name))
    }
  }
  match stable_constraint {
    AllowedTuples(tuple_variables, tuples) => {
      if tuples.length() == 0 {
        return Err(EmptyTupleTable)
      }
      for tuple_index = 0
          tuple_index < tuples.length()
          tuple_index = tuple_index + 1 {
        let tuple = tuples[tuple_index]
        if tuple.length() != tuple_variables.length() {
          return Err(
            InvalidTupleArity(
              tuple_index,
              tuple_variables.length(),
              tuple.length(),
            ),
          )
        }
        for position = 0; position < tuple.length(); position = position + 1 {
          let variable = tuple_variables[position]
          let value = tuple[position]
          if !domain_has(self.variables[variable.index].domain, value) {
            return Err(
              TupleValueOutsideDomain(tuple_index, variable.name, value),
            )
          }
        }
        for previous = 0; previous < tuple_index; previous = previous + 1 {
          if tuples[previous] == tuple {
            return Err(DuplicateTuple(previous, tuple_index))
          }
        }
      }
    }
    _ => ()
  }
  self.constraints.push({ name, constraint: stable_constraint, })
  Ok(())
}

///|
/// Add a checked constraint with a stable, human-readable name.
///
/// Names must be unique within a problem so conflict reports can map solver
/// rules back to their business meaning.
pub fn Problem::add_named_constraint(
  self : Problem,
  name : String,
  constraint : Constraint,
) -> Result[Unit, ModelError] {
  if name.length() == 0 {
    return Err(EmptyConstraintName)
  }
  for spec in self.constraints {
    if spec.name == Some(name) {
      return Err(DuplicateConstraintName(name))
    }
  }
  self.add_constraint_spec(Some(name), constraint)
}

///|
/// One named value in a solution.
pub(all) struct Binding {
  name : String
  value : Int
} derive(Eq, Debug, ToJson)

///|
/// A complete assignment satisfying every constraint.
pub(all) struct Solution {
  bindings : Array[Binding]
} derive(Eq, Debug, ToJson)

///|
/// Look up a value by variable name.
pub fn Solution::get(self : Solution, name : String) -> Int? {
  for binding in self.bindings {
    if binding.name == name {
      return Some(binding.value)
    }
  }
  None
}

///|
/// Search telemetry useful for diagnostics and visualizations.
pub(all) struct SolveStats {
  nodes : Int
  backtracks : Int
  solutions : Int
} derive(Eq, Debug, ToJson)

///|
/// Solver result with an explicit unsatisfiable branch.
pub(all) enum SolveOutcome {
  Satisfied(Solution, SolveStats)
  Unsatisfied(SolveStats)
} derive(Eq, Debug, ToJson)

///|
priv struct SearchCounters {
  mut nodes : Int
  mut backtracks : Int
}

///|
fn assigned(assignment : Array[Int?], variable : Var) -> Int? {
  assignment[variable.index]
}

///|
fn all_distinct(values : Array[Int]) -> Bool {
  for i = 0; i < values.length(); i = i + 1 {
    for j = 0; j < i; j = j + 1 {
      if values[i] == values[j] {
        return false
      }
    }
  }
  true
}

///|
fn domain_bounds(domain : Array[Int]) -> (Int, Int) {
  let mut low = domain[0]
  let mut high = domain[0]
  for value in domain {
    if value < low {
      low = value
    }
    if value > high {
      high = value
    }
  }
  (low, high)
}

///|
fn constraint_possible(
  problem : Problem,
  assignment : Array[Int?],
  constraint : Constraint,
) -> Bool {
  match constraint {
    Equal(variable, expected) =>
      match assigned(assignment, variable) {
        Some(value) => value == expected
        None => domain_has(problem.variables[variable.index].domain, expected)
      }
    NotEqual(variable, forbidden) =>
      match assigned(assignment, variable) {
        Some(value) => value != forbidden
        None => true
      }
    Different(left, right) =>
      match (assigned(assignment, left), assigned(assignment, right)) {
        (Some(a), Some(b)) => a != b
        _ => true
      }
    OffsetDifferent(left, right, offset) =>
      match (assigned(assignment, left), assigned(assignment, right)) {
        (Some(a), Some(b)) => a != b + offset
        _ => true
      }
    LessThan(left, right) =>
      match (assigned(assignment, left), assigned(assignment, right)) {
        (Some(a), Some(b)) => a < b
        (Some(a), None) => {
          let (_, high) = domain_bounds(problem.variables[right.index].domain)
          a < high
        }
        (None, Some(b)) => {
          let (low, _) = domain_bounds(problem.variables[left.index].domain)
          low < b
        }
        _ => true
      }
    AllDifferent(variables) => {
      let values : Array[Int] = []
      for variable in variables {
        match assigned(assignment, variable) {
          Some(value) => values.push(value)
          None => ()
        }
      }
      all_distinct(values)
    }
    SumEquals(variables, target) => {
      let mut low = 0
      let mut high = 0
      for variable in variables {
        match assigned(assignment, variable) {
          Some(value) => {
            low = low + value
            high = high + value
          }
          None => {
            let (domain_low, domain_high) = domain_bounds(
              problem.variables[variable.index].domain,
            )
            low = low + domain_low
            high = high + domain_high
          }
        }
      }
      target >= low && target <= high
    }
    CountAtMost(variables, expected, limit) => {
      let mut count = 0
      for variable in variables {
        match assigned(assignment, variable) {
          Some(value) if value == expected => count = count + 1
          _ => ()
        }
      }
      count <= limit
    }
    AllowedTuples(variables, tuples) => {
      for tuple in tuples {
        let mut compatible = true
        for position = 0; position < variables.length(); position = position + 1 {
          match assigned(assignment, variables[position]) {
            Some(value) if value != tuple[position] => {
              compatible = false
              break
            }
            _ => ()
          }
        }
        if compatible {
          return true
        }
      }
      false
    }
  }
}

///|
fn all_constraints_possible(
  problem : Problem,
  assignment : Array[Int?],
) -> Bool {
  for spec in problem.constraints {
    if !constraint_possible(problem, assignment, spec.constraint) {
      return false
    }
  }
  true
}

///|
fn viable_values(
  problem : Problem,
  assignment : Array[Int?],
  index : Int,
) -> Array[Int] {
  let result : Array[Int] = []
  for value in problem.variables[index].domain {
    assignment[index] = Some(value)
    if all_constraints_possible(problem, assignment) {
      result.push(value)
    }
  }
  assignment[index] = None
  result
}

///|
fn choose_variable(
  problem : Problem,
  assignment : Array[Int?],
) -> (Int, Array[Int])? {
  let mut best_index = -1
  let mut best_values : Array[Int] = []
  for index = 0; index < assignment.length(); index = index + 1 {
    if assignment[index] is None {
      let values = viable_values(problem, assignment, index)
      if best_index == -1 || values.length() < best_values.length() {
        best_index = index
        best_values = values
      }
    }
  }
  if best_index == -1 {
    None
  } else {
    Some((best_index, best_values))
  }
}

///|
fn make_solution(problem : Problem, assignment : Array[Int?]) -> Solution {
  let bindings : Array[Binding] = []
  for index = 0; index < problem.variables.length(); index = index + 1 {
    match assignment[index] {
      Some(value) =>
        bindings.push({ name: problem.variables[index].variable.name, value, })
      None => ()
    }
  }
  { bindings, }
}

///|
fn search(
  problem : Problem,
  assignment : Array[Int?],
  counters : SearchCounters,
  solutions : Array[Solution],
  limit : Int,
  recorder : TraceRecorder?,
  depth : Int,
) -> Unit {
  if solutions.length() >= limit {
    return
  }
  match choose_variable(problem, assignment) {
    None =>
      if all_constraints_possible(problem, assignment) {
        solutions.push(make_solution(problem, assignment))
        record_search_event(recorder, SolutionFound(solutions.length(), depth))
      }
    Some((index, values)) => {
      if values.length() == 0 {
        counters.backtracks = counters.backtracks + 1
        record_search_event(
          recorder,
          DeadEnd(problem.variables[index].variable.name, depth),
        )
        return
      }
      let before = solutions.length()
      for value in values {
        if solutions.length() >= limit {
          break
        }
        let branch_before = solutions.length()
        let variable_name = problem.variables[index].variable.name
        record_search_event(recorder, TryValue(variable_name, value, depth))
        assignment[index] = Some(value)
        counters.nodes = counters.nodes + 1
        search(
          problem,
          assignment,
          counters,
          solutions,
          limit,
          recorder,
          depth + 1,
        )
        assignment[index] = None
        if solutions.length() == branch_before {
          record_search_event(recorder, Backtrack(variable_name, value, depth))
        }
      }
      if solutions.length() == before {
        counters.backtracks = counters.backtracks + 1
      }
    }
  }
}

///|
/// Enumerate up to `limit` solutions in deterministic order.
pub fn Problem::solve_all(
  self : Problem,
  limit : Int,
) -> Result[(Array[Solution], SolveStats), ModelError] {
  if limit <= 0 {
    return Err(InvalidSolutionLimit(limit))
  }
  let assignment : Array[Int?] = Array::make(self.variables.length(), None)
  let counters : SearchCounters = { nodes: 0, backtracks: 0, }
  let solutions : Array[Solution] = []
  search(self, assignment, counters, solutions, limit, None, 0)
  Ok(
    (
      solutions,
      {
        nodes: counters.nodes,
        backtracks: counters.backtracks,
        solutions: solutions.length(),
      },
    ),
  )
}

///|
/// Find the first solution using MRV-guided deterministic backtracking.
pub fn Problem::solve(self : Problem) -> SolveOutcome {
  let (solutions, stats) = self.solve_all(1).unwrap()
  if solutions.length() == 0 {
    Unsatisfied(stats)
  } else {
    Satisfied(solutions[0], stats)
  }
}

///|
/// Build an inclusive integer domain.
pub fn int_domain(first : Int, last : Int) -> Array[Int] {
  let values : Array[Int] = []
  if first <= last {
    for value = first; value <= last; value = value + 1 {
      values.push(value)
    }
  }
  values
}
