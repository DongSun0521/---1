# Combat V2-8B：V1/V2双轨战斗入口

> V2-8A契约检查点：`d058597c61504d2f04697f5c172fe260f484cd80`，轻量标签
> `combat-v2-8a-integration-contract`。V2-8B只建立开发期接入预览，不执行正式结算。

## 入口和依赖方向

正式主场景仍为`features/main/main.tscn`。`MainView`在原导航栏增加“开发战斗入口”，
干净启动时固定选择“V1正式战斗（默认）”。V1模式调用原来的
`GameState.start_battle(encounter_id)`，之后仍由`BattleSystem`、`BattleView`和
`GameState.process_battle_result()`完成正式流程；原远征遭遇调用链没有被替换。

只有明确选择“V2接入预览（不结算）”并点击“启动所选”时，正式侧才按以下方向工作：

```text
MainView
  → FormationDefenseBattleRouter
  → FormationDefensePreviewRequestBuilder
  → FormationDefensePreviewHost
  → 冻结 formation_defense_prototype 场景
  → V2-8A输出契约
  → Router校验并返回MainView调试摘要
```

Router和Host不是Autoload。冻结V2核心仍不依赖`GameState`、`CharacterRoster`或
`SaveSystem`。场景加载失败、非法请求和错误session只会清理预览并返回安全视图，绝不
自动改走V1。

## 临时原型角色边界

V2-8B尚未进行正式队伍映射。请求构造器集中生成四名冻结原型角色：

- `prototype:guard`
- `prototype:hunter`
- `prototype:mage`
- `prototype:doctor`

显示名会标记“原型”，`injury_state`固定为`prototype_untracked`。这些ID不会与正式
`CharacterRoster`稳定ID混用，战果也不会反馈为正式经验、生命、伤情或奖励。该临时
映射将在V2-8C由正式角色快照替换。

预览固定运行`v2_7b_three_archetype_full_battle`，种子从冻结配置读取为2703；游侠500、
法师450以及角色、怪物、阵型、大招和波次数值均未调整。

## 会话与结果

每次预览创建运行时唯一的`battle_session_id`。测试可以注入确定性工厂，正式运行使用
微秒时钟加单次运行递增序号。同一时刻最多一个会话；重复点击、重复终态、旧session、
session不匹配和非法输出都会被拒绝。

胜利、失败和中止都只生成一次V2-8A结果。Host从原型现有快照收集时长、村庄耐久、
生成/击败/漏怪、完成波数和原型角色本局事实。Router再次校验请求/结果session、battle
和完整角色ID集合，随后清空活动会话。`settlement_id`只显示为
`formation-defense:v1:<battle_session_id>`，不消费、不保存。

返回主界面后显示的开发摘要包含session、settlement、正式来源节点或“无正式遭遇上下文”、
V2 battle ID、结果、时长、村庄耐久和敌人统计，并明确显示：
“V2-8B接入预览未执行正式结算”。摘要没有领取奖励入口。

## 中止与Esc

预览顶部始终提供“退出预览”。中止输出`ABORTED`并清理敌人、Wave Director任务、阵型、
弹道、集火和大招节点。Esc先检查V2内部大招瞄准或调试抽屉；存在内部层时只由原型处理，
没有内部层时才安全中止整局，避免一次Esc同时关闭内部层并退出。

## 正式数据零写入

V2入口只从`GameState`读取当前遭遇ID和节点ID作为来源文字。请求角色来自冻结原型配置，
Host和Router不查找正式单例，也不调用V1完成/结算和`SaveSystem`。专项会在胜利、失败、
中止和场景加载失败前后比较：

- `CharacterRoster`完整序列化数据；
- 正式资源和统计；
- 远征、V1战斗、待结算和最后战果；
- 远征临时货物；
- 存档文件存在性、大小和修改时间。

允许改变的仅有当前UI、非持久化路由模式、单局V2对象和调试摘要。

## 人工检查步骤

1. 运行`features/main/main.tscn`，确认导航栏默认显示“V1正式战斗（默认）”。
2. 通过原冒险/远征遭遇启动一次V1，确认旧战斗、结果确认和返回流程不变。
3. 返回后选择“V2接入预览（不结算）”，点击“启动所选”。
4. 完成一局，确认返回原安全视图并出现“不结算”摘要。
5. 对比正式资源、经验、伤情、远征节点和临时货物，确认均未变化。
6. 再启动一局，点击预览顶部“退出预览”或在无内部浮层时按Esc。
7. 确认显示`ABORTED`摘要，并可再次进入V2。
8. 重启游戏，确认模式恢复V1。

原型独立调试仍可直接运行
`prototype/formation_defense/scenes/formation_defense_prototype.tscn`；此时场景选择、开始、
重开和部署调试控件保持原样。接入预览模式会隐藏这些可能误导正式玩家的原型控制。
