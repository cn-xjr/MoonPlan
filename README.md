# MoonPlan

[![CI](https://github.com/cn-xjr/MoonPlan/actions/workflows/ci.yml/badge.svg)](https://github.com/cn-xjr/MoonPlan/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![MoonBit](https://img.shields.io/badge/MoonBit-wasm--gc-orange.svg)](https://www.moonbitlang.com/)

**用约束描述排班规则，让求解器给出可复现的安排。**

MoonPlan 是一个纯 MoonBit 实现的有限域约束求解与排班工具包。它面向人员排班、课程编排、资源分配、配置组合等场景，将散落在业务代码中的可用时间、技能要求和冲突规则转化为可组合、可测试的约束模型。

## 一个真实问题

假设早上 9 点同时需要前台和技术支持，10 点还需要一名技术支持。三名工作人员的技能和可用时间不同：

| 工作人员 | 技能 | 可用时段 |
| --- | --- | --- |
| Ada | 前台 | 09:00 |
| Bo | 技术支持 | 09:00 |
| Chen | 前台、技术支持 | 09:00、10:00 |

MoonPlan 会先根据技能和可用时间缩小候选域，再保证同一时段的岗位不会分配给同一个人。运行示例：

```console
$ moon run cmd/main
MoonPlan staffing demo
  slot 9 / Reception: Ada
  slot 9 / Help desk: Bo
  slot 10 / Late support: Chen
searched 3 assignments
```

## 当前能力

- 有限域整数变量与严格的模型边界检查
- `Equal`、`NotEqual`、`Different`、`OffsetDifferent`
- `LessThan`、`AllDifferent`、`SumEquals`
- MRV（最少剩余值）变量选择和确定性回溯搜索
- 多解枚举，以及搜索节点、回溯次数等诊断数据
- `Worker`、`Shift`、`Roster` 排班领域模型
- 技能、可用时间和同一时段容量冲突检查
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

## 快速开始

```bash
git clone https://github.com/cn-xjr/MoonPlan.git
cd MoonPlan
moon check --deny-warn
moon test --deny-warn
moon run cmd/main
```

当前测试覆盖四皇后、多解枚举、不可满足问题、模型校验，以及人员技能、可用时间和同一时段冲突。CI 在 Linux、macOS 和 Windows 上执行全目标检查与测试。

## 下一阶段

1. 可撤销域与传播队列，提升大规模模型的搜索效率。
2. 软约束和加权目标，支持偏好、公平性与成本优化。
3. 不可满足核心和自然语言冲突说明，回答“为什么排不出来”。
4. MoonBit/Wasm 可视化工作台，展示排班结果、搜索树和修复建议。
5. 可复现排班基准与跨后端一致性验证。

完整设计、不变量和里程碑见 [DESIGN.md](DESIGN.md)。可执行文档版本见 [README.mbt.md](README.mbt.md)。

## 开源与来源

MoonPlan 采用 [Apache-2.0](LICENSE) 许可证。当前求解器和排班实现为原创 MoonBit 代码，不包含移植的第三方源码、外部测试数据或来源不明资产。
