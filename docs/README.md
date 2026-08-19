# 《冒险村》文档索引

> 更新日期：2026-07-29
> 当前代码基线：Stage 12F / `5d07beb 12F`

## 从这里开始

新接手项目或开启新的 Codex 任务时，建议按以下顺序阅读：

1. [`codex_handoff_overall.md`](codex_handoff_overall.md)：当前实现、系统边界、测试、已知问题和后续建议的总说明；
2. [`GAME_DESIGN.md`](GAME_DESIGN.md)：目标玩法和产品设计的事实来源；
3. [`codex_handoff_12F.md`](codex_handoff_12F.md)：当前角色系统整合、成长反馈、存档 v6 和阶段收尾细节；
4. 本次任务涉及的具体阶段交接文档。

`codex_handoff_overall.md` 描述当前代码事实；旧阶段交接文档保留的是当时的
实现背景和验收快照。两者冲突时，先以当前代码和总交接文档为准，再检查最新
阶段文档。

## 当前完成状态

- 已完成 Stage 8～12F；
- 已形成“村庄后勤 → 远征 → 战斗 → 返程结算 → 角色/装备/村庄成长”的可运行闭环；
- 战斗角色与生活角色都统一进入 `CharacterRoster`；
- 岗位运行态位于 `buildings[*].jobs`，招募候选运行态位于
  `GameState.life_recruitment_state`；
- 当前存档版本为 v6，支持 v0～v5 迁移；
- 主界面底部已有“战斗角色”“生活角色”两个功能入口，生活角色页内进入招募；
- Stage 8～12F 共 22 个 Smoke 入口已完成独立进程回归。

完整内容、数值规则和测试命令见
[`codex_handoff_overall.md`](codex_handoff_overall.md)。

## 阶段交接文档

| 文档 | 内容 |
| --- | --- |
| [`codex_handoff_11.md`](codex_handoff_11.md) | Stage 11 总体战斗表现交接 |
| [`codex_handoff_11A.md`](codex_handoff_11A.md) | 通用战斗特效框架 |
| [`codex_handoff_12A.md`](codex_handoff_12A.md) | 正式战斗角色仓库与编队 |
| [`codex_handoff_12B.md`](codex_handoff_12B.md) | 战斗角色成长 |
| [`codex_handoff_12C.md`](codex_handoff_12C.md) | 生活角色与岗位基础 |
| [`codex_handoff_12D.md`](codex_handoff_12D.md) | 生活角色工作成长 |
| [`codex_handoff_12E.md`](codex_handoff_12E.md) | 生活角色招募、容量与解雇 |
| [`codex_handoff_12F.md`](codex_handoff_12F.md) | 角色系统整合、反馈、配置、边界与 v6 存档 |
| [`combat_v2_integration_baseline.md`](combat_v2_integration_baseline.md) | Combat V2-8A 正式数据流、输入/输出契约与接入边界 |
| [`combat_v2_dual_battle_entry.md`](combat_v2_dual_battle_entry.md) | Combat V2-8B V1/V2双轨入口、预览会话、零写入边界与人工检查 |
| [`combat_v2_formal_party_mapping.md`](combat_v2_formal_party_mapping.md) | Combat V2-8C/R 正式队伍读取、属性尺度适配、动态角色与零写入验证 |
| [`combat_v2_formal_settlement.md`](combat_v2_formal_settlement.md) | Combat V2-8D 正式结算验证、V1语义表与会话内幂等边界 |

Stage 8～10 的实现和测试入口没有单独阶段交接文件，已集中整理在
[`codex_handoff_overall.md`](codex_handoff_overall.md)。

## 设计文档

- [`GAME_DESIGN.md`](GAME_DESIGN.md)：完整目标设计；其中“当前原型状态”和
  “推荐开发阶段”已同步至 Stage 12F；
- [`GAME_DESIGN_MVP.md`](GAME_DESIGN_MVP.md)：最初 MVP 的范围、原则和验收
  标准。该 MVP 已完成并被后续阶段扩展，文中的“不做”是历史范围，不代表
  当前项目仍未实现这些功能。

## 音频资料

- [`audio/sfx_candidates.md`](audio/sfx_candidates.md)：音效候选与接入记录；
- [`audio/THIRD_PARTY_AUDIO_LICENSES.md`](audio/THIRD_PARTY_AUDIO_LICENSES.md)：
  第三方音频许可记录。

## 文档维护约定

- 每个阶段完成后更新最新阶段交接文档和总交接文档；
- 实现状态变化时同步更新 `GAME_DESIGN.md` 的第 16、17 节；
- 旧阶段文档原则上不重写，只补充明确的勘误或后续兼容说明；
- 新数值、存档版本、权威数据边界、测试入口和已知稳定性问题必须写入总交接；
- 临时 UI 选择、调试过程和已失效方案不应写成正式设计结论。
