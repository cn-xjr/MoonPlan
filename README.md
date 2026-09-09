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
- `LessThan`、`AllDifferent`、`SumEquals`、`CountAtMost`
- `AllowedTuples` 表约束，可表达轮班模板和任意兼容组合
- MRV（最少剩余值）变量选择和确定性回溯搜索
- 多解枚举，以及搜索节点、回溯次数等诊断数据
- 有界确定性搜索轨迹，可导出 JSON 供搜索树可视化
- 命名约束与不可满足模型的最小冲突集解释
- 排班预检、冲突证据与可执行修复建议
- `Worker`、`Shift`、`Roster` 排班领域模型
- 技能、可用时间和同一时段容量冲突检查
- 有界候选搜索与工作量均衡评分
- 每人班次数量硬上限，避免跨时段过度排班
- `RosterPolicy` 组合工作量上限与最小休息间隔
- 非负分配惩罚、偏好优化与工作量均衡同分决策
- `RosterRequest` JSON 输入、字段路径错误与稳定结果输出
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
moon check --deny-warn
moon test --deny-warn
moon run cmd/main
```

当前测试覆盖四皇后、多解枚举、不可满足问题、模型校验，以及人员技能、可用时间、同一时段冲突和工作量上限。CI 在 Linux、macOS 和 Windows 上执行全目标检查与测试。

## 下一阶段

1. 可撤销域与传播队列，提升现有计数和表约束的搜索效率。
2. 扩展加权目标，在现有分配偏好基础上支持连续工作成本和多级目标。
3. 扩展修复建议，支持休息间隔、连续工作时长和偏好冲突。
4. 基于现有 JSON 边界和搜索事件流构建 MoonBit/Wasm 可视化工作台。
5. 可复现排班基准与跨后端一致性验证。

完整设计、不变量和里程碑见 [DESIGN.md](DESIGN.md)。可执行文档版本见 [README.mbt.md](README.mbt.md)。

## 开源与来源

MoonPlan 采用 [Apache-2.0](LICENSE) 许可证。当前求解器和排班实现为原创 MoonBit 代码，不包含移植的第三方源码、外部测试数据或来源不明资产。
