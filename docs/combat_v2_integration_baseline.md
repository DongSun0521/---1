# Combat V2-8A：正式接入基线与数据契约

> 代码基线：`integration/formation-defense` 的非快进合并提交
> `1718dd992046b28d919b4acdb5c814776f9c8a05`。本阶段只定义数据边界，
> 不接通正式入口、不替换 V1 战斗、不执行正式结算。

## 当前正式 V1 数据流

1. `project.godot` 的默认场景是 `features/main/main.tscn`。`MainView` 同时挂载村庄、
   远征和旧战斗视图，通过 `GameState` 信号切换可见区域，并不更换主场景。
2. 玩家在 `ExpeditionView` 选择相邻节点；`ExpeditionSystem.move_to_next_node()` 返回
   `starts_battle` 和 `encounter_id`。`GameState.move_to_next_expedition_node()` 随后调用
   `start_battle(encounter_id)`，`MainView` 收到 `battle_started` 后显示
   `features/battle/battle_view.tscn`。
3. 正式队伍由 `CharacterRoster.get_party_character_ids()` 提供，规则是 1～4 名、稳定
   `character_id` 唯一，并按 `party_slot` 排序。`GameState` 将正式角色记录重建成
   `adventurers` 深拷贝，旧 `BattleSystem.start_battle()` 再复制为单局 `party_states`。
4. 最终战斗属性由正式侧先计算。`CombatCharacterData.calculate_final_stat_details()`
   合并基础值、等级成长、装备、村庄、伤情和远征餐食临时加成；
   `CharacterRoster.create_party_unit_state()` 只消费这些结果。V1 开战时
   `EquipmentSystem.create_battle_equipment_snapshot()` 还会把装备词缀快照附到单位。
5. `BattleSystem` 拥有 V1 回合、当前生命、冷却、敌人和战斗日志。胜利或失败时，
   `finish_battle()` 把角色生命写回正式运行态，并返回 `party_states`、敌人、遭遇和
   临时奖励字段。这里“战斗模块计算矿石/草药/核心数值”是需要后续迁移的现状，
   V2 契约不继承这个所有权。
6. `BattleView` 先展示待结算结果，再调用 `GameState.complete_pending_battle_result()`。
   `GameState.process_battle_result()` 按实际出战 `character_id` 发放经验；胜利交给
   `ExpeditionSystem.apply_battle_victory()` 标记节点并加入远征货物，失败则结束远征、
   折算货物并由 `HospitalSystem` 处理伤情。玩家确认结果后，胜利回远征视图，失败回村庄。
7. 正常返村时 `ExpeditionSystem.return_to_village()` 才把远征货物转入正式资源。
   `SaveSystem` 是唯一持久化实现，当前版本为 v6；代码只暴露显式
   `GameState.save_game/load_game` 包装，战斗结算本身不会自动写存档。

## 阵型塔防 V2 当前运行时数据流

V2 目前从 `formation_defense_config.gd` 选择测试方案与 `battle_id`，由
`FormationDefenseWaveDirector` 生成敌人，原型控制器管理角色、指挥、大招、村庄耐久、
胜负和本局统计。它不读取正式单例，也不写奖励、经验、进度或存档。

接入后的目标方向是单向的：

`正式数据源 → 正式适配层计算并深拷贝请求 → V2单局运行 → 事实结果 → 正式结算层`

V2 只拥有当前生命/能量、临时效果、部署与目标、敌人/阵型/波次状态及本局统计。
正式角色成长、装备结果、关卡进度、资源奖励和持久化永远不归 V2 所有。

## V2-8A 契约

### 输入 `FormationDefenseBattleContract` v1

| 字段 | 含义 |
| --- | --- |
| `contract_version` | 固定为 1 |
| `battle_session_id` | 单次战斗稳定 ID，用于请求/结果匹配 |
| `battle_id` | 正式遭遇 ID |
| `random_seed` | 本局独立确定性随机种子 |
| `party` | 1～4 名正式角色的深拷贝快照 |
| `party[*].character_id` | `CharacterRoster` 稳定 ID，不依赖数组位置 |
| `display_name/profession_id/role_display_name/party_slot` | 显示、职业和正式编队顺序 |
| `final_stats` | 正式侧算好的 `max_hp/attack/defense/speed/attack_speed/crit_rate/crit_damage` |
| `equipped_skill_ids/ultimate_id` | 本局已选择技能和大招的稳定配置 ID |
| `battle_visual_id/injury_state` | 本局必需表现引用与正式伤情快照 |
| `battle_config_ref` | `wave_config_id` 与实际允许的 `enemy_profile_ids` |
| `encounter_context` | 来源模式和正式远征节点 ID |

契约只接受字符串、数字、布尔、数组和字典；Node、Resource/RefCounted、Callable、Signal、
Vector 等运行对象全部拒绝。规范化结果会重新构造所有嵌套容器并固定角色顺序，修改它
不会反向影响正式数据。

### 输出 `FormationDefenseBattleContract` v1

| 字段 | 含义 |
| --- | --- |
| `contract_version/battle_session_id/battle_id` | 与请求匹配 |
| `settlement_id` | `formation-defense:v1:<battle_session_id>`，供正式层幂等结算 |
| `outcome` | `VICTORY`、`DEFEAT` 或 `ABORTED` |
| `duration_seconds` | 已发生的战斗时长 |
| `village_durability` | 剩余值与最大值 |
| `party_results` | 按稳定角色 ID 返回倒下、剩余生命和本局统计 |
| `battle_statistics` | 生成、击败、漏怪和完成波次数 |

输出只陈述事实，禁止奖励、经验、装备、关卡进度或存档字段。剩余生命和倒下状态是否
跨战斗持久化仍由现有正式返程/伤情规则决定，V2 不引入长期伤亡。

## 适配层与所有权

`FormationDefenseBattleAdapter` 是纯数据边界：调用方先从正式系统解析队伍和最终属性，
再传入普通 Dictionary；适配器从不查找 `/root/GameState`。结果转换会校验 session、battle
及完整角色 ID 集合，并生成按角色 ID 索引的正式结算输入，但不会执行结算。

| 数据/动作 | 唯一所有者 | V2-8A 边界 |
| --- | --- | --- |
| 正式角色、编队、等级、装备、伤情 | `CharacterRoster`（由 `GameState` 协调） | 只接收已解析快照 |
| 最终角色属性 | 正式角色/装备/村庄/餐食计算链 | V2 不重复计算 |
| 单局生命、能量、部署、目标、阵型、波次 | V2 战斗运行时 | 战斗结束后只返回事实 |
| 经验与成长 | `GameState` + `CharacterRoster` | 正式结算层依据事实计算 |
| 关卡、远征货物和正式资源 | `GameState` + `ExpeditionSystem` | 正式结算层写入 |
| 奖励表 | 正式遭遇/关卡配置 | 不进入 V2 输出 |
| 存档与迁移 | `SaveSystem` | 本阶段不调用，版本仍为 v6 |

依赖方向为：正式入口/结算层可以依赖契约与适配器；V2 核心脚本不得依赖
`GameState`、`CharacterRoster` 或 `SaveSystem`。

## 建议接入顺序

1. **V2-8B**：在正式侧建立请求构建器和双轨开发入口，仅创建快照并启动 V2；V1 仍默认。
2. **V2-8C**：让 V2 角色部署与战斗初始化消费请求快照，移除运行时对固定四角色数值的依赖。
3. **V2-8D**：接通结果返回和幂等正式结算，奖励/经验只查正式遭遇配置；补齐中止语义。
4. **V2-8E**：接通探索/村庄导航和失败/退出/返程流程，保留可回退的 V1/V2 双轨验证。
5. **V2-8F**：完成存档中断恢复策略、全量回归和上线切换评审；通过前不替换 V1。

## 已确认问题与暂缓事项

- V1 `BattleSystem.finish_battle()` 仍生成奖励数值；后续应由正式结算依据遭遇配置计算，
  本阶段只记录，不重写。
- 正式角色目前没有独立的大招装备字段，V2-8B 必须明确“职业默认大招”或正式负载来源，
  不得让 V2 反向成为正式配置源。
- V1 当前生命会在远征内延续，失败/返村后按既有规则恢复并处理伤情；村庄耐久与角色倒下
  如何映射到该规则留给 V2-8D。
- `SaveSystem` 会序列化进行中的 V1 `battle_state`，但尚无 V2 中断恢复格式；V2-8F 前不扩存档版本。
- V2-8A检查点本身没有玩家可见切换按钮、正式入口或结算写入。后续V2-8B已在正式
  主界面增加开发期双轨入口，但V2仍只生成并展示契约结果，不执行正式结算；详见
  [`combat_v2_dual_battle_entry.md`](combat_v2_dual_battle_entry.md)。
- V2-8C已让该预览读取正式队伍和最终属性，并动态生成1～4名V2角色；读取发生在正式侧
  边界，契约、适配器、Router、Host与V2核心仍只处理深拷贝纯数据。角色结果仍不进入
  `GameState`结算。V2-8C-R进一步用“正式最终/职业参考比例 × 冻结V2基准”显式适配
  回合制正式属性与实时V2属性的数值尺度，契约仍接收可直接运行的V2就绪值；详见
  [`combat_v2_formal_party_mapping.md`](combat_v2_formal_party_mapping.md)。
