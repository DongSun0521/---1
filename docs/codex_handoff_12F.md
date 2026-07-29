# 《冒险村》Stage 12F 交接：角色系统整合、反馈与阶段收尾

## 1. 阶段结论

Stage 12F 已完成第12阶段的收口，并继续遵守三条数据边界：

- `CharacterRoster` 是正式战斗/生活角色、成长、装备和编队信息的唯一真源；
- `buildings[*].jobs` 是岗位占用的运行态真源；
- `GameState.life_recruitment_state` 是尚未正式招募的候选池运行态真源。

本阶段没有增加重复角色仓库、重复成长结算、重复招募池或第二套岗位系统。

完成内容：

- 战斗结算增加实际出战角色逐人经验、前后等级、连续升级和主要属性变化；
- 生活生产、制造、制药和治疗增加建筑内“最近工作结果”及轻量通知；
- 战斗/生活角色页统一信息层级，增加经验条、头像和文字状态；
- 新增5个生活角色颜色头像及1个默认头像；
- 第12阶段主要数值集中到一个配置脚本；
- 战斗和生活等级上限统一为50级，并补齐属性、生命、队伍、ID和资源边界；
- 招募、刷新、岗位、编队、升级和解雇增加成功/失败反馈及关键确认；
- 存档升级到v6，支持v0～v5迁移和损坏数据修复；
- 新增12F专项和Stage 12总集成测试，Stage 8～12F历史回归通过。

本阶段没有实现疲劳、心情、自动排班、关系、工作动画、战斗角色招募、
品质晋升、抽卡保底、复杂天赋树或新的科研/采集生产玩法。

## 2. 新增文件

### 配置

- `scripts/data/stage12_balance_config.gd`
- `scripts/data/stage12_balance_config.gd.uid`

### 生活角色头像

- `assets/art/characters/life_portraits/life_default.svg`
- `assets/art/characters/life_portraits/life_amber.svg`
- `assets/art/characters/life_portraits/life_green.svg`
- `assets/art/characters/life_portraits/life_blue.svg`
- `assets/art/characters/life_portraits/life_purple.svg`
- `assets/art/characters/life_portraits/life_red.svg`
- 上述资源对应的Godot `.import` 文件

### 测试和交接

- `tools/smoke_stage12f_character_integration.gd`
- `tools/smoke_stage12f_character_integration.gd.uid`
- `tools/smoke_stage12_integration.gd`
- `tools/smoke_stage12_integration.gd.uid`
- `docs/codex_handoff_12F.md`

## 3. 修改文件

- `autoload/game_state.gd`
  - 集中配置查询、通知队列、最近工作结果、头像回退和统一文字状态；
  - 战斗/生活升级反馈；
  - 编队、岗位、招募、刷新、锁定和解雇的成功/失败通知；
  - 战斗结果和经验结算幂等标记。
- `features/battle/battle_view.gd`
  - 可滚动战斗结果面板；
  - 实际出战角色逐人经验和升级详情；
  - 结果确认后再离开战斗页。
- `features/main/main_view.gd`
  - 等待战斗结算确认信号后切换页面，避免结果被导航立即覆盖。
- `features/village/village_view.gd`
- 战斗/生活角色页信息整理；
- 村庄主界面底部增加可扩展功能栏，提供战斗角色和生活角色入口；
- 生活头像和经验条；
  - 建筑最近工作结果和总览轻量通知；
  - 状态文字、操作反馈、高品质刷新确认和重复点击保护；
  - 筛选会话保持、失效选择修复和列表节点清理。
- `scripts/data/character_record.gd`
  - 反序列化时按角色类型限制等级并处理满级经验需求。
- `scripts/data/combat_character_data.gd`
  - 最终战斗属性合法范围保护。
- `scripts/data/combat_stats.gd`
  - 暴击率和暴击伤害配置边界。
- `scripts/data/life_stats.gd`
  - 五项生活属性统一限制为0～100。
- `scripts/data/life_trait_database.gd`
  - 生活特性数值改为读取统一配置。
- `systems/building_system.gd`
  - 岗位数量和岗位模板改为读取统一配置。
- `systems/character_roster.gd`
  - 两类成长曲线、属性成长和上限改为读取统一配置；
  - 满级经验处理、连续升级循环边界和12F旧档修复；
  - 生活头像默认值及回退；
  - 编队和唯一ID边界。
- `systems/life_recruitment_system.gd`
  - 品质、属性范围、费用、容量和姓名池改为读取统一配置；
  - 候选随机头像、正式招募后头像稳定、加载时缺失回退。
- `systems/farm_system.gd`
- `systems/food_workshop_system.gd`
- `systems/forge_system.gd`
- `systems/hospital_system.gd`
  - 有效工作完成时记录一次生活成长反馈。
- `systems/save_system.gd`
  - 当前版本升级到v6；
  - 保存/恢复通知、最近工作结果和配置版本；
  - 资源、生命、角色成长、头像和损坏结果的加载修复。
- `tools/smoke_stage12a_character_roster.gd`
- `tools/smoke_stage12b_combat_characters.gd`
  - 当前存档版本和配置化经验需求断言更新为v6规则。

## 4. 战斗成长反馈

战斗仍只在：

```gdscript
GameState.process_battle_result(result)
```

中发放经验。`BattleView` 只读取结算后写入结果的
`experience_results`，不会再次调用经验发放接口。

每个实际出战角色的结果包含：

- `character_id` / `display_name`
- `experience_gained`
- `experience_applied` / `discarded_experience`
- `old_level` / `new_level`
- `levels_gained`
- `experience` / `experience_to_next_level`
- `at_max_level`
- `stat_changes`

显示内容包括：

- 角色名称和本次经验；
- 战斗前后等级；
- 未升级或“升级 ×N”；
- 生命、攻击、防御、速度的前后值及增量；
- 满级及溢出经验说明；
- 待命角色未出战、不获得经验的明确文字。

奖励继续为：

- 普通胜利：40
- Boss胜利：100
- 失败：10

`experience_processed` 防止同一个结果重复结算经验；
`stage12f_result_processed` 防止同一个完整战斗结果重复应用远征、统计和经验。
同一角色若异常地在 `party_states` 重复出现，也只奖励一次。

## 5. 生活工作反馈

农田、食物制造、武器制造、制药和治疗只在完成有效周期、且现有岗位
经验结算返回参与者时调用：

```gdscript
GameState.record_life_work_feedback(building_id, report)
```

反馈保存于：

```gdscript
GameState.recent_life_work_results_by_building[building_id]
```

内容包括：

- 参与角色及名称；
- 获得工作经验；
- 前后等级和连续升级次数；
- `growth_by_stat` 中实际提升的生活属性；
- 最终生产倍率；
- 基础产出、实际产出和额外产出；
- 治疗完成标记或效果文字。

展示方式是建筑详情中的“最近工作结果”、上一日汇总和最多30条的轻量通知
队列，不会为每个生产周期强制弹窗。原有
`life_work_settlement_keys` 继续保证一个生产周期只能发放一次工作经验。

## 6. 角色页、头像和状态

### 战斗角色页

保留现有角色动画预览和业务接口，整理为：

- 名称、职业、品质、等级；
- 当前经验条或“已满级”；
- 当前生命、伤势、最终属性；
- 装备、技能、特性；
- 出战/待命和编队顺序；
- 编队操作反馈。

### 生活角色页

整理为：

- 头像；
- 名称、品质、等级；
- 工作经验条或“已满级”；
- 农业、制造、采集、研究、医疗；
- 擅长方向和特性；
- 当前建筑、岗位、岗位效率和工作状态；
- 锁定、解雇和岗位操作反馈。

生活角色列表在滚动容器内。筛选和排序保存在页面实例的本次会话状态，
不写正式存档；排序只处理角色快照，不修改
`CharacterRoster.character_order`。数据变化后会验证当前选择，被解雇角色
不再作为选择保留；筛选结果为空时仍会把内部选择切换到有效正式角色。

### 头像

候选生成时从 `Stage12BalanceConfig.LIFE_PORTRAIT_PATHS` 随机选择路径。
角色记录只保存 `portrait_path`，不保存纹理对象或动画。

- 招募时完整角色记录进入 `CharacterRoster`，路径保持不变；
- v6存档按原路径保存和恢复；
- 默认三名生活角色使用固定颜色头像；
- 空路径或资源缺失统一回退到 `life_default.svg`；
- 头像允许重复，不参与候选ID或生成合法性判断；
- 战斗角色继续使用原有角色资源。

统一文字状态：

- `◆ 出战` / `◇ 待命`
- `✚ 受伤`
- `○ 空闲` / `● 工作中` / `× 不可用`
- `■ 已锁定`
- 候选卡的锁定文字
- 招募页的容量已满文字

图形符号旁始终有文字，不只依赖颜色。

## 7. 数值集中配置

集中位置：

```text
scripts/data/stage12_balance_config.gd
```

当前集中项：

- 战斗普通胜利/Boss/失败经验；
- 战斗和生活升级需求曲线；
- 四名战斗角色的等级属性成长；
- 工作基础经验和生活属性成长；
- 生活属性及暴击率/暴击伤害边界；
- 品质概率和各品质属性范围；
- 招募费用、刷新费用和姓名池；
- 民居容量公式；
- 各建筑岗位模板和1～4级岗位数量；
- 全部生活特性数值；
- 生活头像池和默认头像；
- 两类等级上限、队伍人数和通知数量上限。

业务层通过配置常量或 `GameState.get_stage12_balance_config()` 读取，UI不再
重复保存这些玩法数值。

## 8. 等级上限和边界规则

当前配置：

```text
战斗角色上限 = 50
生活角色上限 = 50
```

满级规则统一为：

- 不再升级；
- `experience_to_next_level = 0`；
- 当前经验归零；
- 新获得经验作为 `discarded_experience` 反馈，不累积；
- UI显示“已满级”，不显示错误升级需求；
- 升级循环以等级上限和正数需求为双重退出条件。

其他边界：

- 五项生活属性：0～100；
- 暴击率：0～1；
- 暴击伤害：0～5；
- 最大生命至少1，攻击、防御、速度和攻速不小于0；
- 当前生命加载和升级后不超过最终最大生命；
- 队伍必须有1～4名不重复的正式战斗角色；
- 创建序号和角色ID由 `CharacterRoster` 唯一生成并在加载时校正；
- 资源和堆叠物品加载后不小于0；
- 招募、刷新等扣费在事务开始前检查，不允许负资源。

## 9. 操作反馈、确认和重复点击保护

统一轻量反馈覆盖：

- 招募成功、粮食不足、容量已满；
- 候选刷新成功和候选锁定；
- 岗位分配、岗位替换、角色撤下；
- 战斗/生活角色升级；
- 解雇成功；
- 远征或战斗期间禁止改队；
- 角色、岗位或目标状态变化等无效操作原因。

高风险确认：

- 解雇任何生活角色；
- 工作中角色解雇时明确说明会先自动撤岗；
- 刷新列表前检测未锁定的稀有及以上候选，列出名称并确认；
- 已锁定候选不进入被替换集合，确认流程不会删除它们。

重复保护：

- UI对招募、刷新、岗位分配/替换和撤下使用短时动作锁；
- 后端招募再次校验候选仍存在、容量和资源；
- 战斗结果有双层幂等标记；
- 工作周期有结算键；
- 岗位系统拒绝同一角色重复占用和非替换式覆盖。

## 10. v6存档与迁移

```gdscript
SaveSystem.CURRENT_SAVE_VERSION = 6
```

v6新增键：

- `stage12_config_version`
- `gameplay_notifications`
- `recent_life_work_results_by_building`
- `next_gameplay_notification_sequence`

头像路径、等级、经验和属性继续位于正式角色
`character_roster` 或候选 `life_recruitment_state` 的角色字典中。

加载顺序：

1. 恢复或初始化 `CharacterRoster`；
2. 依次执行12B、12C、12D、12E和12F默认值/迁移；
3. 修复等级、经验、生活属性、战斗成长配置和生活头像；
4. 恢复资源、建筑、装备、生产、医院、远征和战斗运行态；
5. 将负资源/物品归零、当前生命限制到最终最大生命；
6. 丢弃结构损坏的待结算/最近战斗结果；
7. 校验候选ID、锁定状态和头像并补齐缺槽；
8. 清理损坏通知和无效建筑工作反馈；
9. 按建筑等级恢复岗位并修复角色/岗位双向引用。

v0～v5缺少新键时使用空通知和空最近工作结果，不会因纯UI反馈数据缺失
拒绝加载。旧角色的成长、装备、岗位、候选锁定、资源、建筑、生产、
医院、远征和战斗字段沿用原迁移链。

## 11. 测试结果

### 12F专项

`tools/smoke_stage12f_character_integration.gd` 通过，覆盖：

- 集中配置内容；
- 队伍1～4人、重复角色和远征中改队保护；
- 生命、暴击、资源、唯一ID边界；
- 普通胜利、Boss胜利和失败10经验；
- 实际出战列表去重、待命不获经验；
- 结算重复处理不重复发经验；
- 前后等级、连续升级和主要属性变化格式；
- 战斗/生活满级和生活属性100上限；
- 有效生产经验、最近结果、最终倍率、额外产出和结算键；
- 招募、刷新、锁定、资源不足、工作中解雇和岗位清理反馈；
- 候选随机头像、招募后稳定、缺失回退；
- 筛选/排序会话保持、仓库顺序不变、失效选择修复；
- 高品质未锁定候选刷新确认；
- 缺少 `settled_day`、空项目报告和损坏锻造报告的旧运行态日报容错；
- v6 JSON往返；
- v0～v5迁移及非法等级、经验、属性、头像修复；
- 战斗/生活页面核心控件。

### Stage 12总集成

`tools/smoke_stage12_integration.gd` 通过，串联验证：

- 正式编队；
- 正式生活角色岗位；
- 候选招募后进入同一岗位系统；
- 有效生产成长及反馈；
- 战斗成长及反馈；
- v6存档后编队、成长、头像、岗位和工作反馈保持；
- 生产、锻造、医院、远征和战斗运行态仍存在。

### 历史回归

每个Smoke使用独立Godot进程运行：

- Stage 8：通过
- Stage 9A数据/UI、9B、9C、9D：通过
- Stage 10A～10E：通过
- Stage 11A～11D：通过
- Stage 12A～12E：通过
- Stage 12F专项：通过
- Stage 12总集成：通过

项目脚本解析：

```powershell
tools\godot.bat --headless --path . --quit
```

通过。

## 12. Godot警告与稳定性记录

环境：

- Windows
- Godot `4.6.3.stable.official.7d41c59c4`
- headless模式

预期降级警告：

- 11A故意查询不存在的特效；
- 11C故意查询不存在的怪物投射物；
- 11D故意播放未配置音频。

对应Smoke均以退出码0通过。

未解决：

- 普通独立运行
  `smoke_stage11b_player_presentations.gd` 功能通过、退出码0，但退出时仍可能
  报 `ObjectDB instances leaked` 和 `2 resources still in use`；
- 使用以下详细日志调用复查时可复现Godot原生崩溃：

```powershell
tools\godot.bat --verbose --headless --path . `
  --script res://tools/smoke_stage11b_player_presentations.gd
```

- 日志为 `CrashHandlerException: Program crashed with signal 11`，官方PE/COFF
  构建没有可用调试符号，只有14层 `no debug info` 的C++回溯；
- 崩溃后进程停留在崩溃处理器，需要终止残留进程；
- 同一测试不带 `--verbose` 本轮已完整通过，其他Stage 8～12F独立进程也通过。

该问题位于高频战斗表现压力测试/引擎退出路径，当前没有证据指向12F成长、
招募、岗位或存档逻辑。为了避免以猜测修改战斗对象生命周期，本阶段仅记录
稳定复现方式，没有为消除警告破坏现有逻辑。

## 13. Stage 13建议优先级

1. 先建立11B原生崩溃的最小复现，尝试带调试符号的Godot构建或升级到已
   修复的稳定版本，确认是引擎、渲染驱动还是项目生命周期问题。
2. 基于 `Stage12BalanceConfig` 做小规模实玩数据采样和经济曲线调优，不先
   扩大玩法面。
3. 将当前轻量通知扩展为可展开的通知中心，并增加分类/合并规则，避免中后期
   高频生产信息淹没重要操作反馈。
4. 用正式生活角色头像逐步替换颜色占位，同时保留现有路径回退协议和存档
   兼容。
5. 在稳定基线上再选择一个明确的下一阶段玩法主题；疲劳、心情、自动排班、
   关系和大型天赋树不应一次并行展开。

## 14. Stage 12F后的界面与兼容修复

2026-07-29 在不改变 Stage 12 数据权威边界的前提下补充了两项正式修复：

1. 村庄主界面底部新增统一功能栏，当前提供“战斗角色”和“生活角色”两个
   按钮。旧的隐蔽角色热点已移除；生活角色页面标题区继续提供“招募”入口，
   后续页面可以沿用同一功能栏扩展。
2. 村庄日报读取旧运行态时不再直接访问缺失的 `settled_day`；同时兼容空项目
   报告、缺失字段和损坏的锻造报告，避免旧存档/旧进程状态打开村庄页面时中断。

`smoke_stage12f_character_integration.gd` 已增加上述日报回退和功能栏按钮
覆盖。修复没有新建角色、成长、招募或岗位系统，也没有改变 v6 存档结构。
