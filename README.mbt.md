# MoonPlan

MoonPlan 是一个使用纯 MoonBit 实现的**可解释有限域约束求解与排班工具包**。它的目标不是只给出“有解/无解”，而是让业务建模者能够描述排班、资源分配、课程编排和配置组合问题，并获得可复现的解、搜索轨迹与冲突解释。

当前仓库已经完成第一个可运行闭环：变量与有限域建模、模型边界检查、MRV（最少剩余值）变量选择、确定性回溯搜索，以及把人员技能、可用时段和同一时段冲突编译为约束的排班 API。

## 为什么值得做

排班和资源分配广泛存在于门店、医院、实验室、赛事和学校，但业务规则经常被写成难以验证的循环和条件分支。MoonPlan 将这些规则提升为可组合约束，同时利用 MoonBit 的代数数据类型、模式匹配、多后端和 Wasm 能力，最终提供浏览器内可交互的建模、求解和解释工作台。

生态查重于 2026-09-09 覆盖 Mooncakes 与 GitHub 的 constraint solver、CSP、scheduling、SAT、planning 等关键词；已发现线性规划项目，但尚未发现面向有限域约束、可解释排班和 Wasm 工作台的高度重合 MoonBit 包。

## 已实现

- 有限域整数变量与稳定变量句柄
- `Equal`、`NotEqual`、`Different`、`OffsetDifferent`
- `LessThan`、`AllDifferent`、`SumEquals`、`CountAtMost`
- `AllowedTuples` 轮班模板与任意兼容组合表约束
- `Element` 索引查表约束，可把方案编号映射为成本或资源属性
- `LinearEquals`、`LinearAtMost` 加权线性约束，可表达预算、工时和容量关系
- MRV 默认搜索，以及可选的 degree 同分决策与 LCV 值排序
- 节点数、回溯数和解数量统计
- `solve_with_node_limit` 有界求解与明确的未完成结果
- `solve_with_trace` 有界确定性搜索事件与 JSON 导出
- 命名约束与不可满足模型的最小冲突集解释
- `suggest_capped_roster_repairs` 排班修复建议与最小可行上限
- `suggest_roster_policy_repairs` 组合策略诊断与最小休息间隔放宽建议
- N 皇后、不可满足模型和人员排班测试
- `Worker`、`Shift`、`Roster` 领域模型与可运行的人员排班示例
- `build_balanced_roster` 有界候选优化与工作量均衡评分
- `build_capped_roster` 每人班次数量硬上限
- `RosterPolicy` 与 `build_roster_with_policy` 最小休息间隔组合规则
- `AssignmentPenalty` 与 `build_preferred_roster` 软偏好优化
- `RosterObjective` 与相邻班次疲劳成本优化
- 基础请求与 `RosterOptimizationRequest` 组合目标 JSON 集成边界
- `analyze_roster` 二分图匹配预检与容量冲突解释

## 运行

```bash
moon check
moon test
moon run cmd/main
```

示例会先生成满足技能和时段约束的排班，再演示当每人最多一班导致无解时，自动建议将统一工作量上限提高到二班。

底层模型可以通过 `add_named_constraint` 保留业务规则名称。无解时调用 `Problem::explain`，即可获得包含原始序号、规则名称和类型化约束的不可再删减冲突集合；策略修复 API 会继续把预检事实和冲突证据转换为增补合格人员、增加时段容量、提高工作量上限或放宽休息间隔等具体建议。

## 路线图

1. **求解器内核**：可撤销域与约束传播队列。
2. **真实排班层**：班次、人员、技能、工作量上限、最小休息间隔、分配偏好与相邻班次成本。
3. **优化与解释**：将现有均衡评分、冲突集和基础修复建议扩展为分支定界、加权目标与复杂规则修复。
4. **可视化工作台**：在现有 JSON 边界和搜索事件流上接入 Wasm 求解、甘特图/日历视图与交互解释。
5. **工程成熟度**：跨后端一致性、基准语料、属性测试、Mooncakes 发布与下游示例。

详细边界和里程碑见 [DESIGN.md](DESIGN.md)。

## 开源说明

项目采用 Apache-2.0 许可证。当前核心实现为原创 MoonBit 代码，不包含复制的第三方源码、测试数据或生成资产。
