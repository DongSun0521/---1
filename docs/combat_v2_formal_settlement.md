# Combat V2-8D 正式结算验证

V2-8D为阵型塔防增加一条必须手动选择、只允许从真实未解决远征遭遇启动的正式
结算验证路径。V1仍是默认正式战斗；`V2_INTEGRATION_PREVIEW`仍然严格零结算。

## V1真实结算语义

| 结果 | 经验 | 奖励/货物 | 伤情 | 节点 | 远征 | 返回位置 |
|---|---|---|---|---|---|---|
| 普通胜利 | 实际参战角色每人40 | 遭遇奖励进入远征临时货物；森林战为矿石1 | 战斗结算时不新增；返村时按剩余生命不高于50%判定 | 当前战斗节点完成 | 保持进行中 | 远征 |
| Boss胜利 | 实际参战角色每人100 | 临时矿石5、草药3、Boss核心1 | 与普通胜利相同 | Boss节点完成并设置`boss_defeated` | 保持进行中，等待玩家返村 | 远征 |
| 失败 | 实际参战角色每人10 | 不发胜利奖励；已有矿石/草药临时货物各带回一半，其余补给不返还 | 实际参战角色全部标记受伤，并恢复战斗外生命 | 不完成 | 立即结束并重置远征 | 村庄 |
| 中止 | V1没有现成的战斗内中止结算；V2-8D定义为0 | 无 | 无 | 不完成 | 保持进行中、遭遇可重试 | 远征 |

规则来源：遭遇和奖励来自`systems/battle_system.gd`，经验来自
`Stage12BalanceConfig.BATTLE_EXPERIENCE_REWARDS`，成长写入复用
`GameState.grant_character_experience()`，临时货物和远征状态复用
`ExpeditionSystem.apply_battle_victory/failure()`，失败伤情复用
`HospitalSystem.process_expedition_injuries_for_characters()`。V1与V2均不在结算时自动调用
`SaveSystem`。

## 边界与数据流

```text
V2纯事实结果
→ FormationDefenseBattleAdapter（请求/结果一致性）
→ FormationDefenseSettlementService.prepare_settlement（纯计划）
→ FormationDefenseSettlementService.apply_settlement（会话内幂等）
→ GameState.apply_formation_defense_settlement_plan
→ CharacterRoster / ExpeditionSystem / HospitalSystem
```

结算计划包含`settlement_id`、session、battle/encounter/node、胜负、请求中的正式参战
ID、每人经验、临时货物、伤情变化、V2生命比例映射后的正式运行生命、节点变化、远征
继续或结束以及返回位置。正式遭遇、当前节点、队伍ID、奖励、经验和全部角色生命更新在
任何写入前完整验证。V2结果契约仍不包含经验、奖励、资源或存档字段。

V2生命使用“V2剩余生命/V2最大生命”的比例映射回该正式角色当前最大生命；倒下事实
映射为0。失败伤情仍服从V1的“参战角色全部受伤”规则，不另造V2伤情算法。

## 三种模式

- `V1`：默认值，完全走原有战斗和结算。
- `V2_INTEGRATION_PREVIEW`：正式队伍进入V2，胜负和中止均不结算。
- `V2_SETTLEMENT_VALIDATION`：界面显示“V2正式结算验证（会改变测试存档）”，只能在
  活动远征的真实未解决遭遇启动，且启动前必须确认警告。

正式遭遇到V2验证配置的映射集中在
`FormationDefensePreviewRequestBuilder.SETTLEMENT_WAVE_CONFIG_BY_ENCOUNTER`。映射缺失会
拒绝，不会自动回退V1。移动到战斗节点时，正式远征通过可选路由回调进入当前选择模式；
没有路由回调的历史调用继续默认启动V1。

## 幂等范围

正式ID固定为：

```text
formation-defense:v1:<battle_session_id>
```

结算服务记录`UNSEEN → PROCESSING → APPLIED`，拒绝同一结果重复到达、同一session不同
结算ID、不同内容计划、冲突终态、旧session、预览结果和中止后的延迟结果。中止只把
session置为`CLOSED`，不消费正式结算ID。

中止、结算拒绝或运行错误返回后，未解决的战斗节点会阻止继续前进；玩家只能重试
当前遭遇或安全返回村庄。旧的结算摘要会在新战斗开始时清空，错误路径会显示独立的
“未执行正式结算”摘要，不会继续显示上一局结果。

该账本仅存在于当前GameState/进程生命周期，防止同一运行会话重复结算；它不跨进程、
不跨存档恢复，也没有战斗结果重放入口。未来若需要断点恢复，必须单独升级存档版本并
实现持久化结算账本。当前存档仍为v6。

## 人工检查

请使用测试存档：

1. 启动正式主场景，确认战斗模式默认是V1。
2. 确认“V2接入预览（不结算）”仍可运行。
3. 出发远征，并在到达真实战斗节点前选择“V2正式结算验证（会改变测试存档）”。
4. 到达节点后确认警告，完成战斗并核对经验、临时货物、节点和远征状态。
5. 摘要应显示“V2-8D正式结算已应用，未自动保存”。
6. 再进入未解决遭遇并中止，确认经验、奖励、伤情和节点均不变。
7. 重复点击关闭摘要不会再次结算。
8. 重启游戏后模式恢复V1；只有用户之后主动保存，内存中的正式变化才会写入文件。

V2-8D当时未处理Lv.50游侠/医生的实时攻速风险；后续V2-8G已在正式属性尺度适配边界加入
递减收益曲线与0.20秒安全下限，未改动本页结算语义。

> V2-8E保留本页Debug结算验证映射以继续回归V2-8D语义，但正式投放不再使用该映射。
> 正式路由只读取集中支持矩阵；森林遭遇技术上支持V2，Boss明确保持V1，且总开关默认
> 关闭。详见[`combat_v2_main_merge_readiness.md`](combat_v2_main_merge_readiness.md)。
