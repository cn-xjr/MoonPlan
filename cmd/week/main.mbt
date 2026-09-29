///|
fn slots_for_shift(shift : Int, absent_day : Int) -> Array[Int] {
  let slots : Array[Int] = []
  for day = 0; day < 7; day = day + 1 {
    if day != absent_day {
      slots.push(day * 2 + shift)
    }
  }
  slots
}

///|
fn weekly_request() -> @moonplan.CoverageRequest {
  let workers : Array[@moonplan.Worker] = [
    {
      id: 1,
      name: "An",
      skills: ["support"],
      available_slots: slots_for_shift(0, 0),
    },
    {
      id: 2,
      name: "Bo",
      skills: ["support"],
      available_slots: slots_for_shift(0, 2),
    },
    {
      id: 3,
      name: "Cai",
      skills: ["support"],
      available_slots: slots_for_shift(0, 4),
    },
    {
      id: 4,
      name: "Du",
      skills: ["support"],
      available_slots: slots_for_shift(0, 6),
    },
    {
      id: 5,
      name: "En",
      skills: ["reception"],
      available_slots: slots_for_shift(1, 1),
    },
    {
      id: 6,
      name: "Fang",
      skills: ["reception"],
      available_slots: slots_for_shift(1, 5),
    },
  ]
  let requirements : Array[@moonplan.CoverageRequirement] = []
  for day = 0; day < 7; day = day + 1 {
    requirements.push({
      id: day * 2 + 1,
      name: "Morning support",
      slot: day * 2,
      required_skill: "support",
      workers_needed: 2,
    })
    requirements.push({
      id: day * 2 + 2,
      name: "Evening reception",
      slot: day * 2 + 1,
      required_skill: "reception",
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
fn main {
  let days = [
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
  ]
  let request = weekly_request()
  println("MoonPlan seven-day coverage example")
  match request.solve() {
    Err(error) => println("No feasible schedule: \{error.message()}")
    Ok(roster) => {
      for requirement in request.requirements {
        let day = days[requirement.slot / 2]
        println(
          "\{day} / \{requirement.name} (\{requirement.workers_needed} needed):",
        )
        for worker in roster.workers_for_requirement(requirement.id) {
          println("  \{worker.name}")
        }
      }
      println(
        "Filled \{roster.entries.length()} positions; searched \{roster.stats.nodes} nodes",
      )
    }
  }
}
