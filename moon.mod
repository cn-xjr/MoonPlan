// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "cn-xjr/moonplan"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/cn-xjr/MoonPlan"

license = "Apache-2.0"

keywords = [
  "constraint-programming",
  "scheduling",
  "solver",
  "optimization",
  "wasm",
]

preferred_target = "wasm-gc"

description = "An explainable finite-domain constraint solver and scheduling toolkit for MoonBit."
