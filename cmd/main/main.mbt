///|
fn main {
  let workers : Array[@moonplan.Worker] = [
    { id: 10, name: "Ada", skills: ["frontdesk"], available_slots: [9], },
    { id: 20, name: "Bo", skills: ["support"], available_slots: [9], },
    {
      id: 30,
      name: "Chen",
      skills: ["frontdesk", "support"],
      available_slots: [9, 10],
    },
  ]
  let shifts : Array[@moonplan.Shift] = [
    { id: 1, name: "Reception", slot: 9, required_skill: "frontdesk", },
    { id: 2, name: "Help desk", slot: 9, required_skill: "support", },
    { id: 3, name: "Late support", slot: 10, required_skill: "support", },
  ]
  println("MoonPlan staffing demo")
  match @moonplan.build_roster(workers, shifts) {
    Err(error) => println("No feasible schedule: \{error.message()}")
    Ok(roster) => {
      for entry in roster.entries {
        println(
          "  slot \{entry.shift.slot} / \{entry.shift.name}: \{entry.worker.name}",
        )
      }
      println("searched \{roster.stats.nodes} assignments")
    }
  }
}
