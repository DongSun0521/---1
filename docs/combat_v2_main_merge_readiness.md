# Combat V2-8E：主干合并准备

> 接入分支：`integration/formation-defense`。V2-8D检查点为
> `b3202bde24e956fd2d8c49acb08efa7b1daa1a62`，轻量标签
> `combat-v2-8d-formal-settlement`。V2正式总开关默认关闭，V1仍是正式默认战斗。

## V2-8A～V2-8E检查点

- V2-8A：冻结纯数据输入/输出契约和正式数据所有权。
- V2-8B：建立V1、V2不结算预览和V2结算验证的开发期双轨入口。
- V2-8C/R：读取正式队伍，按职业参考尺度映射最终属性并动态生成1～4名角色。
- V2-8D：复用V1经验、奖励、伤情和远征语义，完成会话内幂等正式结算。
- V2-8E：集中隔离Debug工具，增加默认关闭的正式路由策略、遭遇支持矩阵和回滚边界。

依赖始终单向：正式入口和结算层可以依赖契约、适配器及V2 Host；V2核心不依赖
`GameState`、`CharacterRoster`或`SaveSystem`。V2只返回本局事实，正式层拥有成长、奖励、
节点、远征与持久化。

## 默认行为与版本隔离

`FormationDefenseIntegrationPolicy`是唯一的接入策略对象：

- `formation_defense_rollout_enabled`默认`false`，仅存在于当前MainView/Coordinator运行
  生命周期，不写入GameState或v6存档，重启恢复`false`。
- Debug可见性只在策略默认构造时读取编辑器/Debug构建环境；测试可注入明确的Debug或
  Release策略。其他UI脚本不散落构建类型判断。
- Debug环境创建“V1正式战斗 / V2不结算预览 / V2结算验证”三种开发控件和扩展诊断。
- Release环境不创建开发入口、占位、隐藏点击区、确认框或快捷方式；正式V2结果只显示
  胜负、经验、奖励、伤情、远征去向与关闭按钮，不显示session、settlement、计划指纹、
  原始统计、属性映射或“未自动保存”等技术文字。
- 正式路由与Debug强制验证互相独立。正式路由不会显示“测试存档”警告。

## 正式遭遇支持矩阵

| encounter_id / 节点 | 类型 | V1敌人与奖励 | V2波次/profile/Boss | 当前正式路由能力 | 原因 |
|---|---|---|---|---|---|
| `forest_slime_pair` / `forest_edge` | 普通 | 2只森林史莱姆；矿石1 | 已验证`v2_7b_three_archetype_full_battle`；护阵、冲锋、加速profile可用；无Boss要求 | 技术上支持V2；总开关关闭时V1，开启后V2 | 正式队伍、波次、结果和结算闭环已验证 |
| `ruins_guard` / `ruins_entrance` | Boss | 遗迹守卫；矿石5、草药3、Boss核心1 | 没有V2 Boss机制或专属Boss波次 | 始终V1 | 不复制综合战冒充Boss关卡 |

未配置遭遇由正式策略明确返回V1，这是一项路由选择，不是V2失败后的静默回退。显式标记
为V2但缺失`battle_id`或对应波次配置会直接拒绝启动，不消费遭遇、不产生结算，也不会
临时改走V1。路由表同时固定真实`encounter_id`和节点ID，避免关卡错配。

## 正式路由和结算语义

开关关闭时，所有正式遭遇继续调用原`GameState.start_battle()`和V1结算。开关开启后，
只有明确支持的森林遭遇沿以下路径运行：

```text
真实遭遇 → IntegrationPolicy → BattleRouter(V2_FORMAL)
→ 正式队伍快照 → V2 Host → 事实结果 → SettlementService → GameState正式结算
```

胜利必须是`VICTORY`且村庄耐久大于0；失败必须是`DEFEAT`且耐久为0。中止不发经验、
奖励或伤情，不完成节点并阻止前往下一节点。重复终态和重复应用继续由session/settlement
账本拒绝。战斗结算不自动保存，存档版本仍为v6。

## 回滚方式

1. 保持`formation_defense_rollout_enabled=false`即可恢复全V1正式路径；这是首选回滚。
2. 如需代码级回滚，以未来的integration合并提交为边界整体回滚，不拆除V2核心目录。
3. 保留全部`combat-v2-*`历史标签，不移动、不删除检查点。

## 已知风险与阻塞项

- V2尚未全量替换V1；Boss和未配置遭遇继续使用V1。
- V2-8G已用递减收益曲线将Lv.50游侠/医生间隔加固到0.254/0.288秒；仍需人工体验确认后
  才能讨论扩大投放。
- V2正式总开关默认关闭，尚未决定实际发布投放策略。
- 正式美术、完整关卡内容、V2 Boss和规模化关卡铺量尚未完成。
- 当前结算幂等账本只在进程内存在；不支持V2战斗中的跨进程断点恢复。

## 合并main后的验证步骤

1. 确认默认主场景、V1战斗和v6存档解析不变。
2. 以Release策略启动，确认导航中没有V2开发控件、占位或调试字段。
3. 保持总开关关闭，分别进入森林和Boss遭遇，确认均走V1。
4. 在受控Debug测试中注入开启总开关，确认森林遭遇自动进入V2并完成胜/负/中止语义。
5. 确认Boss仍走V1；注入缺失V2配置时必须明确拒绝且不回退。
6. 关闭总开关并重启，确认恢复全V1路径且存档中没有开关字段。
7. 运行V2-8E专项、V2-8A～8D以及Stage 8～12历史回归。
