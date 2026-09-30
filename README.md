# MoonPlan

[![CI](https://github.com/cn-xjr/MoonPlan/actions/workflows/ci.yml/badge.svg)](https://github.com/cn-xjr/MoonPlan/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![MoonBit](https://img.shields.io/badge/MoonBit-wasm--gc-orange.svg)](https://www.moonbitlang.com/)

**用约束描述排班规则，让求解器给出可复现的安排。**

MoonPlan 是一个纯 MoonBit 实现的有限域约束求解与排班工具包。它面向人员排班、课程编排、资源分配、配置组合等场景，将散落在业务代码中的可用时间、技能要求和冲突规则转化为可组合、可测试的约束模型。

## 一个真实问题

假设早上 9 点同时需要前台和技术支持，10 点和 11 点还各需要一名技术支持。三名工作人员的技能和可用时间不同：

| 工作人员 | 技能 | 可用时段 |
| --- | --- | --- |
| Ada | 前台 | 09:00 |
| Bo | 技术支持 | 09:00 |
| Chen | 前台、技术支持 | 09:00、10:00、11:00 |

MoonPlan 会先根据技能和可用时间缩小候选域，再保证同一时段的岗位不会分配给同一个人，并在可行方案中同时考虑分配偏好和工作量均衡。运行示例：

```console
$ moon run cmd/main
MoonPlan staffing demo
  slot 9 / Reception: Ada
  slot 9 / Help desk: Bo
  slot 10 / Late support: Chen
  slot 11 / Night support: Chen
preference penalty: 0; balance spread: 1; candidates: 3
searched 7 assignments
repair suggestion: raise the per-worker workload limit from 1 to 2
```

## 当前能力

- 有限域整数变量与严格的模型边界检查
- `Equal`、`NotEqual`、`Different`、`OffsetDifferent`
- `LessThan`、`AllDifferent`、`SumEquals`、`CountAtMost`、`CountBetween`
- `AllowedTuples` 表约束，可表达轮班模板和任意兼容组合
- `Element` 索引查表约束，可把方案编号映射为成本或资源属性
- `LinearEquals`、`LinearAtMost` 加权线性约束，可表达预算、工时和容量关系
- MRV 默认搜索，以及可选的 degree 同分决策与 LCV 值排序
- 多解枚举，以及搜索节点、回溯次数等诊断数据
- 有节点上限的求解，可明确区分找到解、证明无解与预算耗尽
- 有界确定性搜索轨迹，可导出 JSON 供搜索树可视化
- 命名约束与不可满足模型的最小冲突集解释
- 排班预检、冲突证据，以及工作量上限与休息间隔修复建议
- `Worker`、`Shift`、`Roster` 排班领域模型
- `CoverageRequirement` 直接表达同一岗位、同一时段的多人覆盖需求
- `CoverageRequest` 支持多人覆盖需求的 JSON 导入、求解与结果导出
- `encode_coverage_roster_csv` 可把岗位名额导出为稳定、正确转义的表格数据
- `analyze_coverage` 在求解前定位原始岗位需求的人员资格与时段容量缺口
- `encode_coverage_analysis` 提供带稳定问题代码与原始业务 ID 的预检 JSON
- `analyze_coverage_with_policy` 联合检查技能、可用时段、同一时段互斥和统一工作量上限，提前报告跨时段技能瓶颈
- 技能、可用时间和同一时段容量冲突检查
- 有界候选搜索与工作量均衡评分
- 每人班次数量硬上限，避免跨时段过度排班
- `WorkerQuota` 按人员设置最少与最多班次
- `RosterPolicy` 组合工作量上限与最小休息间隔
- 连续工作时段硬上限，避免人员覆盖过长的连续班次
- `CoverageRequest::solve_with_consecutive_limit` 将连续工作上限应用于多人岗位覆盖
- 非负分配惩罚、偏好优化与工作量均衡同分决策
- 可组合排班目标，可在分配偏好之外累计相邻班次疲劳成本
- 支持加权总分、分配偏好优先、连续班次优先三种目标排序
- 优化结果附带结构化惩罚明细，可追溯具体分配偏好和连续班次成本
- 兼容基础与组合目标的 JSON 请求、字段路径错误与稳定结果输出
- 二分图匹配驱动的排班预检与容量冲突解释
- 无解、无合格人员和重复标识等明确错误

## 架构

```mermaid
flowchart LR
    A[人员与班次] --> B[排班建模层]
    B --> C[有限域约束模型]
    C --> D[MRV 搜索与剪枝]
    D --> E[可行排班]
    D --> F[搜索统计 / 冲突证据]
```

项目保持求解内核与业务建模分离：应用可以直接使用排班 API，也可以使用底层约束构建课程表、资源配置或谜题求解器。

使用 `add_named_constraint` 可以为业务规则保留稳定名称。模型无解时，`Problem::explain` 会返回一个不可再删减的冲突集合；其中每项包含原始约束序号、名称和类型化约束，便于界面或领域层生成可读说明。`suggest_capped_roster_repairs` 进一步把预检问题和求解器冲突转换成增补合格人员、增加时段容量或提高工作量上限等建议，并计算可行的最小统一上限。

## 快速开始

```bash
git clone https://github.com/cn-xjr/MoonPlan.git
cd MoonPlan
moon check
moon test
moon run cmd/main
moon run cmd/week
```

`cmd/week` 给出七天的岗位覆盖示例：每天早班两名客服、晚班一名前台，包含预先请假的员工与每人最多四班的限制。测试会核对全部 21 个名额、人员资格和工作量上限。CI 对可用的 Wasm、WasmGC 与 JS 目标执行检查和测试；原生目标保留给本地工具链验证。

外部脚本也可以把 `CoverageRequest` JSON 作为 `--json` 参数传给 `cmd/coverage`。命令输出带 `roster` 和 `error` 字段的 JSON；以下 PowerShell 示例读取仓库内的样本文件：

```powershell
moon run cmd/coverage --json (Get-Content examples/coverage.json -Raw)
moon run cmd/coverage --json (Get-Content examples/coverage.json -Raw) --format csv
moon run cmd/coverage --json (Get-Content examples/coverage.json -Raw) --check
moon run cmd/coverage --json (Get-Content examples/coverage.json -Raw) --node-limit 100
```

CSV 输出按岗位名额逐行列出需求与人员；名称中的逗号、引号、换行会正确转义，类似公式的名称会作为文本处理。输入或排班失败时仍返回包含 `error` 的 JSON。
`--check` 返回 `preflight_passed` 和结构化 `issues`。当设置统一工作量上限时，它还会计算技能、可用时段和岗位需求之间的最大可覆盖名额；`policy_shortfall` 表示这些规则联合后出现的缺口。休息间隔等规则仍由完整求解器判断，因此预检通过不保证有解。`--node-limit N` 返回带 `status` 和 `stats` 的有界结果：`found` 表示找到排班，`unsatisfiable` 表示在预算内证明无解，`budget_exhausted` 表示搜索尚未完成，不能当作无解。

`examples/coverage_week.json` 是一个可公开复现的六时段、多技能、多人覆盖样例，包含前台、支持和带班资格，可用同一组命令验证预检、求解和预算行为。

## 下一阶段

1. 为排班示例增加直接读取文件和标准输入的命令行入口与更丰富的真实业务规则。
2. 在现有多级目标排序上增加新的软成本维度与分支定界优化。
3. 扩展修复建议，覆盖连续工作硬上限和偏好冲突。
4. 基于现有 JSON 边界和搜索事件流构建 MoonBit/Wasm 可视化工作台。
5. 可复现排班基准与跨后端一致性验证。

完整设计、不变量和里程碑见 [DESIGN.md](DESIGN.md)。可执行文档版本见 [README.mbt.md](README.mbt.md)。

## 开源与来源

MoonPlan 采用 [Apache-2.0](LICENSE) 许可证。当前求解器和排班实现为原创 MoonBit 代码，不包含移植的第三方源码、外部测试数据或来源不明资产。
