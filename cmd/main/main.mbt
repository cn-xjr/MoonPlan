///|
fn main {
  let workers : Array[@moonplan.Worker] = [
    { id: 10, name: "Ada", skills: ["frontdesk"], available_slots: [9], },
    { id: 20, name: "Bo", skills: ["support"], available_slots: [9], },
    {
      id: 30,
      name: "Chen",
      skills: ["frontdesk", "support"],
      available_slots: [9, 10, 11],
    },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Reception", slot: 9, required_skill: "frontdesk", },
    { id: 2, name: "Help desk", slot: 9, required_skill: "support", },
    { id: 3, name: "Late support", slot: 10, required_skill: "support", },
    { id: 4, name: "Night support", slot: 11, required_skill: "support", },
  ]
  let penalties : Array[@moonplan.AssignmentPenalty] = [
    { worker_id: 30, shift_id: 1, penalty: 5, },
  ]
  println("MoonPlan staffing demo")
  match
    @moonplan.build_preferred_roster(
      workers,
      shifts,
      @moonplan.RosterPolicy::default(),
      penalties,
      64,
    ) {
    Err(error) => println("No feasible schedule: \{error.message()}")
    Ok(result) => {
      for entry in result.roster.entries {
        println(
          "  slot \{entry.shift.slot} / \{entry.shift.name}: \{entry.worker.name}",
        )
      }
      println(
        "preference penalty: \{result.total_penalty}; balance spread: \{result.balance.spread}; candidates: \{result.candidates_evaluated}",
      )
      println("searched \{result.roster.stats.nodes} assignments")
    }
  }
  match @moonplan.suggest_capped_roster_repairs(workers, shifts, 1) {
    Err(error) => println("Could not analyze repairs: \{error.message()}")
    Ok(plan) => println("repair suggestion: \{plan.summary()}")
  }
}
