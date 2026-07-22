# 《冒险村》第11阶段交接文档

更新日期：2026-07-22  
适用基线：已完成第10阶段，并在当前工作区实现第11阶段 11A～11D 的版本

## 1. 文档用途

本文档汇总第11阶段的战斗表现工作，供后续 Codex 或开发者直接续接。第11阶段已经完成以下主线：

- 11A：通用特效、投射物和战斗表现框架；
- 11B：我方四名角色的正式技能表现与节奏调优；
- 11C：普通小怪远程攻击、树精地刺复查及敌方表现验收；
- 11D：临时战斗音效、镜头震动、屏幕闪光、命中停顿和最终反馈验收。

当前版本的核心原则没有改变：`BattleSystem` 和 `EnemyAI` 负责产生完整战斗结果，表现层只读取结果并安排动画、投射物、特效、音效、数值反馈和状态切换。表现层不重新计算伤害或治疗，不重新选择目标，不重新扣除药品，也不改变技能冷却、装备词条和行动顺序。

## 2. 当前完成状态

第11阶段代码与自动化验收已经完成。以下内容已处于可运行状态：

- 我方战士、游侠、法师、治疗者拥有相互独立的释放帧、锚点、投射物和命中特效配置；
- 普通小怪能够从自身锚点向左发射魔法弹，两只实例互不共享运行状态；
- 树精普通攻击和群体地刺使用不同视觉配置；
- 群体奥术冲击和群体地刺只播放一次源动画及一次主要音效，并等待各目标表现收束；
- 治疗术和药品使用现有治疗光圈，药品跳过源角色攻击动画；
- 战士防御使用纯表现 Tween，不改变防御规则；
- 命中、治疗、死亡的反馈顺序由表现队列统一控制；
- 投射物、特效、音频、Tween、Timer、闪光和命中停顿在战斗结束或场景退出时统一清理；
- 18 个临时战斗音效已经注册并接入，素材均来自 Kenney 的 CC0 资源包；
- 100 次混合表现循环、100 次敌方行动、10 场清理循环和三种分辨率的自动验收均已通过。

仍建议在正式发布前进行一次人工实机验收，重点确认音量、音色统一性、震动强度、闪光舒适度以及不同角色素材的脚底和手部锚点观感。

## 3. 稳定架构与数据流

当前数据流如下：

```text
BattleSystem / EnemyAI
        ↓ 生成完整结果与 presentation_events
BattleView 表现队列
        ↓ 读取行动及目标结果
BattleEffectRegistry / BattleActionVisualProfile
        ↓ 选择动画、投射物、特效、音效和反馈参数
BattleUnitView / BattleProjectilePlayer / BattleEffectPlayer
        ↓
在 impact 时机展示既有伤害、治疗、受击或死亡
        ↓
清理临时节点并完成一次表现事件
        ↓
继续原有回合流程
```

必须继续遵守：

- 不在表现层调用伤害公式；
- 不在投射物碰撞中结算伤害；
- 不根据数值大小重复生成视觉或音频反馈；
- 不在特效层重新选择目标；
- 不让缺失资源阻断表现队列；
- 不因表现参数调整而改动战斗速度、行动顺序或冷却规则。

## 4. 第11阶段主要代码文件

### 4.1 战斗场景与单位视图

- `features/battle/battle_view.gd`
  - 串联表现队列、输入锁、行动聚合、数值反馈、受击/死亡、胜负反馈和退出清理；
  - 创建并维护 Ground、Projectile、Impact、FloatingText 和 Overlay 等表现层；
  - 群体行动只完成一次，目标缺失时安全收束。
- `scripts/battle/battle_unit_view.gd`
  - 管理单位动画、角色级锚点、视觉受击偏移、Tween 复位和死亡最终帧；
  - 锚点偏移来自角色视觉配置，不使用全局屏幕坐标。
- `scripts/data/battle_visual_registry.gd`
  - 保存各角色和怪物的视觉缩放及锚点偏移。

### 4.2 表现数据与播放器

- `scripts/battle/effects/battle_effect_data.gd`
- `scripts/battle/effects/battle_projectile_data.gd`
- `scripts/battle/effects/battle_action_visual_profile.gd`
- `scripts/battle/effects/battle_effect_context.gd`
- `scripts/battle/effects/battle_effect_handle.gd`
- `scripts/battle/effects/battle_effect_backend.gd`
- `scripts/battle/effects/battle_effect_registry.gd`
- `scripts/battle/effects/battle_effect_player.gd`
- `scripts/battle/effects/battle_projectile_player.gd`

`BattleEffectRegistry.initialize_defaults()` 当前以代码注册默认资源和行动配置。没有为每个行动单独创建 `.tres` Profile；这是现阶段稳定的适配方式，后续若要资源化，应保持 action_id 与现有注册结果完全一致，并分批迁移。

### 4.3 11D 反馈系统

- `scripts/battle/effects/battle_audio_player.gd`
  - 固定 12 路 `AudioStreamPlayer` 池；
  - 使用 `SFX` Audio Bus；
  - 支持资源缓存、同一 sound_id 的最大实例数、最短触发间隔、缺失资源一次性警告和全部停止。
- `scripts/battle/effects/battle_camera_effects.gd`
  - 仅对战斗世界层执行镜头震动；
  - 屏幕闪光位于 Overlay 层，不覆盖底部操作逻辑；
  - 命中停顿只暂停表现世界，计时器始终继续运行。
- `scripts/battle/effects/battle_presentation_settings.gd`
  - 提供主音量、SFX 音量、震动、闪光和命中停顿的运行时开关；
  - 当前仅在进程生命周期内保持，不写入存档，也尚未接入设置界面。
- `default_bus_layout.tres`
  - 当前总线关系为 `Master → SFX`；
  - 不要重复创建 SFX Bus。

## 5. 战斗表现层级

`BattleView` 当前使用以下职责明确的层级：

- `GroundEffectLayer`：预警圈和脚下类效果；
- `UnitLayer`：角色及怪物视图；
- `ProjectileLayer`：箭矢和魔法弹；
- `ImpactEffectLayer`：命中特效、奥术爆炸、治疗圈和地刺；
- `FloatingTextLayer`：伤害、治疗和状态浮字，始终位于主要特效上方；
- `OverlayEffectLayer`：全屏闪光。

这些节点只保存临时表现，不写入 `GameState`。战斗结束或场景退出时必须统一清空。

## 6. 当前实际 action_id 与视觉配置

下表是当前项目真实使用的表现 action_id。请勿为了匹配旧提示另外建立同义 ID。

| 行动 | 实际 action_id | 释放/命中帧 | 主要表现 | 关键参数 |
|---|---|---:|---|---|
| 战士普通攻击 | `guard_basic_attack` | 3 | `hit_spark` | 动画速度 1.10，命中特效 0.92 倍 |
| 战士盾击 | `shield_bash` | 3 | `hit_spark` | 动画速度 1.15，命中特效 1.25 倍，视觉后退 8 px |
| 战士防御 | `defend` | 无 | 防御 Tween/状态反馈 | 跳过源攻击动画，不播放命中特效 |
| 游侠普通攻击 | `hunter_basic_attack` | 5 | `arrow_projectile` + `hit_spark` | 动画速度 1.75，飞行 0.30 秒 |
| 游侠强力射击 | `power_shot` | 5 | 复用箭矢 + 强化命中 | 动画速度 1.90，飞行 0.24 秒，箭矢 1.22 倍，命中 1.25 倍 |
| 法师普通攻击 | `mage_basic_attack` | 5 | `magic_bolt_projectile` + `hit_spark` | 动画速度 1.15，飞行 0.42 秒 |
| 法师奥术冲击 | `arcane_blast` | 5 | 每目标 `arcane_burst` | 特效命中帧 3，并行播放，源动画一次 |
| 治疗者普通攻击 | `doctor_basic_attack` | 5 | `magic_bolt_projectile` + `hit_spark` | 动画速度 1.20，飞行 0.40 秒 |
| 治疗术 | `healing_art` | 4 | `heal_circle` | 特效命中帧 4，目标 `effect` 锚点 |
| 使用药品 | `medicine` | 无 | 较小、较快的 `heal_circle` | 跳过源动画，命中帧 3，缩放 0.78，速度 1.35 |
| 小怪普通攻击 | `monster_basic_attack` | 5 | `monster_magic_bolt_projectile` | 飞行 0.40 秒，X 缩放为 -1 使弹头向左 |
| 树精普通攻击 | `ruins_guard_basic_attack` | 4 | `hit_spark` | 与地刺配置完全分离 |
| 树精地刺 | `ruins_guard_earth_spike` | 4 | `warning_circle` + `earth_spike` | 预警 0.65 秒，地刺命中帧 3，并行逐目标生成 |
| 火元素普通攻击 | `fire_boss_basic_attack` | 4 | `hit_spark` | 仅保留基础反馈，不含正式技能特效 |
| 敌方通用回退 | `enemy_basic_attack` | 4 | `hit_spark` | 未注册敌方行动的安全回退 |

上述 Profile 均在 `scripts/battle/effects/battle_effect_registry.gd` 中集中注册。装备词条只会改变 `BattleSystem` 产生的最终数值；Profile 仍仅根据 action_id 播放一次相应表现。

## 7. 角色与怪物锚点

锚点偏移在 `scripts/data/battle_visual_registry.gd` 中集中配置，单位为角色视图局部像素。布局会随战场分辨率缩放，不能改为固定屏幕坐标。

| 视觉键 | 视觉缩放 | ProjectileOrigin | BodyCenter | Ground | Effect | DamageNumber |
|---|---:|---:|---:|---:|---:|---:|
| `guard` | 1.20 | (10, -28) | (8, -20) | (0, 10) | (0, -20) | (0, 0) |
| `hunter` | 0.88 | (20, -32) | (8, -18) | (0, 8) | (0, -18) | (0, 0) |
| `mage` | 0.88 | (14, -42) | (8, -22) | (0, 8) | (0, -22) | (0, 0) |
| `doctor` | 0.86 | (10, -36) | (8, -18) | (0, 8) | (0, -18) | (0, 0) |
| `forest_slime` | 0.78 | (-16, 8) | (-16, 0) | (0, 48) | (-16, 0) | (0, 0) |
| `ruins_guard` | 1.62 | (-10, -20) | (0, -20) | (0, 0) | (0, -20) | (0, 0) |
| `fire_boss` | 1.58 | (-10, -18) | (0, -18) | (0, 0) | (0, -18) | (0, 0) |

治疗圈曾因使用 Ground 锚点而显得过低，当前治疗术和药品统一改用目标的 `effect` 锚点，使爆发中心更接近角色脚底正中及身体下半部。若今后更换角色立绘，应优先微调该角色的 `effect_anchor_offset`，不要在 `BattleView` 中添加角色专用坐标判断。

锚点缺失时的回退顺序：

- ProjectileOrigin：优先 BodyCenter，其次单位视图全局位置；
- Ground：单位视图位置加角色底部回退偏移；
- Effect/BodyCenter：单位视图位置；
- 目标视图缺失：使用事件已记录的世界坐标；仍无坐标时短延迟后直接推进结果表现。

## 8. 当前特效与投射物资源

### 8.1 美术资源

- 箭矢：`res://assets/art/effect/projectiles/arrow.png`
- 魔法弹：`res://assets/art/effect/projectiles/magic_bolt_sheet.png`
- 命中特效：`res://assets/art/effect/impact/hit_spark_sheet.png`
- 奥术爆炸：`res://assets/art/effect/impact/arcane_burst_sheet.png`
- 治疗圈：`res://assets/art/effect/heal/heal_circle_sheet.png`
- 预警圈：`res://assets/art/effect/warning/warning_circle.png`
- 地刺：`res://assets/art/effect/boss/earth_spike_sheet.png`

序列帧资源位于 `res://assets/art/effect/sprite_frames/`。当前默认显示缩放约为：魔法弹 0.75、命中特效 0.58、奥术爆炸 0.78、治疗圈 0.72、地刺 0.64。行动级 Profile 还可叠加缩放覆盖。

### 8.2 投射物

- `arrow_projectile`：直线飞行 0.30 秒，根据目标方向旋转；
- `magic_bolt_projectile`：直线飞行 0.42 秒，飞行序列帧循环；
- `monster_magic_bolt_projectile`：直线飞行 0.40 秒，小怪行动配置使用 `Vector2(-1, 1)` 反转素材朝向。

投射物抵达之前不会展示伤害。Tween 完成、被中断或战斗退出时都会安全释放节点。当前 ARC/BEZIER 类型尚未实现真实曲线，若被使用会回退为直线。

### 8.3 缺失资源处理

- 注册表查不到特效或投射物时只输出一次警告；
- 缺失投射物时短延迟后直接进入 impact；
- 缺失命中特效时仍展示数值、血条和 hit/death；
- 缺失音效时静默跳过或仅一次性警告；
- 所有回退均不得重新计算结果，也不得卡住输入锁或表现队列。

## 9. 我方角色表现总结

### 9.1 战士

- 普通攻击无投射物，在第 3 帧触发命中；
- 盾击使用独立 Profile，视觉冲击更大，目标 Sprite 短暂后移 8 px 后自动复位，不修改逻辑位置和点击区域；
- 防御不播放 attack，不播放 hit_spark，复用现有状态系统并增加轻量缩放/提亮 Tween；
- 死亡或战斗结束时防御 Tween 和临时视觉状态会被清理。

### 9.2 游侠

- 箭矢从角色上半身前方的独立 ProjectileOrigin 发射；
- 普通攻击在第 5 帧放箭，飞行 0.30 秒；
- 强力射击复用同一箭矢素材，但拥有独立速度和缩放覆盖；
- 箭矢根据源点到目标 BodyCenter 的向量旋转，因此攻击不同高度目标时方向正确。

### 9.3 法师

- 普通攻击在第 5 帧从法杖/手部附近发射魔法弹；
- 魔法弹在飞行期间循环，抵达或中断后立即停止并释放；
- 奥术冲击只播放一次法师 attack，所有有效目标并行播放一次奥术爆炸；
- 各目标的伤害、受击和死亡独立完成，一个目标缺失不会阻断其他目标。

### 9.4 治疗者

- 普通攻击拥有独立释放帧和 ProjectileOrigin，不与法师共享偏移；
- 治疗术在第 4 帧释放，治疗圈第 4 帧展示既有治疗结果；
- 治疗结果在特效中段展示，不等待完整特效播放结束；
- 药品不播放源角色 attack，使用 0.78 倍且 1.35 倍速度的治疗圈；
- 特效本身不扣药、不计算治疗，也不会触发第二次恢复。

## 10. 敌方表现总结

### 10.1 普通小怪

- 当前单位实例 ID 为 `forest_slime_01`、`forest_slime_02`；
- 两者共用视觉键 `forest_slime` 和静态 Profile `monster_basic_attack`；
- 每个实例仍拥有独立的 BattleUnitState、BattleUnitView、动画播放器、一次性标记、投射物句柄、生命条和死亡状态；
- 小怪位于战场右侧，魔法弹通过行动级 X 轴反转正确朝左；
- 来源在投射物飞行期间死亡时，已启动的表现可以安全结束，不会让另一个小怪的投射物被误删。

### 10.2 树精 Boss

- 当前单位/视觉键为 `ruins_guard`；
- 普通攻击使用 `ruins_guard_basic_attack`；
- 地刺使用 `ruins_guard_earth_spike`，与普通攻击配置分离；
- 每个目标脚下先生成一个 0.65 秒预警圈，再生成一个地刺；
- 地刺第 3 帧展示该目标既有伤害结果；
- Boss 源动画只播放一次，主要地刺音效只播放一次；
- 目标表现并行聚合，全部收束后只恢复一次 Boss idle 并只推进一次行动队列。

### 10.3 火元素 Boss

本阶段只保证原有 idle、attack、hit、death 和基础攻击回退不被破坏。陨石预警、陨石投射物、爆炸和火焰技能均未实现，属于后续阶段范围。

## 11. 行动生命周期与重复触发保护

单体行动由表现队列按以下生命周期推进：

```text
锁定输入 → 源动画 → release → 投射物/近战命中
→ impact 特效 → 数值与血条 → hit/death
→ 清理临时表现 → 源角色 idle → complete → 下一行动
```

当前保护机制包括：

- 每个表现事件和 Handle 只完成一次；
- release、impact 和 completion 由当前事件实例持有，不保存在角色类型的共享静态数据中；
- 投射物 Tween 只连接自身实例；
- 数值反馈只读取一次事件中的最终值；
- 已死亡单位不会返回 idle、不会重新获得行动、不会重复播放 death；
- 输入锁覆盖整个行动表现，不允许快速点击重复创建相同行动；
- 胜负流程开始后停止接收新的战斗行动表现。

群体行动使用聚合等待：每个目标拥有独立的目标表现 Handle，完成或安全回退时减少待完成项；当所有目标结束后，聚合 Handle 只触发一次整体完成。零目标行动会直接安全收束，不等待不存在的目标。

## 12. 音效系统与临时素材

### 12.1 已注册 sound_id

当前 18 个需求 sound_id 均已注册：

- `melee_swing`
- `light_impact`
- `heavy_impact`
- `arrow_release`
- `arrow_impact`
- `magic_cast`
- `magic_impact`
- `arcane_burst`
- `heal`
- `defend`
- `medicine`
- `monster_cast`
- `earth_spike`
- `unit_hit`
- `unit_death`
- `battle_victory`
- `battle_defeat`
- `ui_click`

兼容别名：`projectile_impact` 指向普通命中，`button_click` 指向 `ui_click`。

### 12.2 路径与授权

- 游戏使用文件：`res://assets/audio/sfx/battle/` 和 `res://assets/audio/sfx/ui/`；
- 原始资源包：`res://assets/audio/source/kenney/`；
- 入选原始文件副本：`res://assets/audio/source/kenney/selected/`；
- 候选清单：`docs/audio/sfx_candidates.md`；
- 第三方授权清单：`docs/audio/THIRD_PARTY_AUDIO_LICENSES.md`。

所有当前接入素材均来自 Kenney 官方资源包，许可证为 CC0，不要求署名；项目仍保留来源页面、下载日期、文件映射和哈希记录。Freesound 候选因下载需要登录而没有接入，也没有伪造下载文件。

当前 `arrow_release` 临时复用 Kenney 的 `knifeSlice2.ogg`，功能可用但不是理想的拉弓/放箭音色。后续如能人工登录 Freesound，可替换为逐项确认过 CC0 的真实弓箭释放音效，并同步更新两份授权文档。

### 12.3 群体音效防叠加

- 奥术冲击的 `arcane_burst` 在群体行动主 impact 处只播放一次；
- 树精地刺的 `earth_spike` 只播放一次主要音效；
- 音频播放器同时设置最大实例数和最短触发间隔，防止同一帧多个目标叠加同一大音效；
- 单位轻量受击声仍可按目标播放，但受音频池与限流控制；
- 音效加载失败不会参与行动完成等待。

## 13. 镜头、闪光和命中停顿

当前预设：

| 反馈 | 时长 | 强度 |
|---|---:|---:|
| light shake | 0.10 秒 | 3 px |
| medium shake | 0.15 秒 | 6 px |
| heavy shake | 0.22 秒 | 10 px |
| boss shake | 0.28 秒 | 14 px |

屏幕闪光预设：白色 0.10 秒、蓝色 0.12 秒、绿色 0.12 秒、红色 0.13 秒，透明度均保持在较低范围，并有约 70 ms 的抗重复闪烁间隔。

命中停顿只暂停战斗表现世界，使用始终处理的 Timer 恢复，单次时长强制限制在 0.12 秒以内。UI 不随镜头震动，也不会因命中停顿失去恢复机会。所有功能可通过 `BattlePresentationSettings` 的运行时开关关闭。

## 14. 数值、受击和死亡反馈顺序

当前统一顺序是：

```text
投射物抵达或近战命中
→ impact 特效/主要音效
→ 读取事件内既有伤害或治疗值
→ 浮动数字和血条 Tween
→ hit 或 death
→ 临时反馈完成
```

浮动数字会进行短促缩放、上浮和淡出，血条平滑变化约 0.22 秒。普通受击拥有短暂闪白和约 4 px 的纯视觉位移；盾击可由 Profile 覆盖为 8 px。所有位移都作用于显示节点并自动复位，不写入战斗单位逻辑位置。

死亡单位播放一次 death 后保持最后一帧，不再返回 idle。死亡反馈不会先于命中特效和数值展示。

## 15. 战斗结束与场景中断清理

胜利、失败、场景切换和 `BattleView` 退出时会处理：

- 清理所有箭矢和魔法弹；
- 清理 hit_spark、arcane_burst、heal_circle、warning_circle 和 earth_spike；
- 停止并释放所有相关 Tween 和 Timer；
- 停止战斗 SFX 和循环音效；
- 清理镜头偏移和屏幕闪光；
- 结束或取消尚未收束的命中停顿，并恢复处理模式；
- 清空群体目标聚合状态和一次性回调；
- 恢复输入锁状态；
- 防止旧回调进入下一场战斗。

不要把上述临时 Node、Tween 或 Handle 保存进 `GameState`。

## 16. 自动化测试与结果

以下测试在当前实现上已通过：

- `tools/smoke_stage8_battle.gd`
  - 原有战斗系统、行动顺序和基本胜负流程回归通过。
- `tools/smoke_stage11a_battle_effects.gd`
  - 注册表、特效、投射物、缺失资源回退和基础清理通过。
- `tools/smoke_stage11b_player_presentations.gd`
  - 我方四角色 action 映射、释放帧、锚点、群体技能、治疗和药品表现通过。
- `tools/smoke_stage11c_enemy_presentations.gd`
  - 双小怪独立性、向左投射物、树精普通攻击/地刺、缺失目标、100 次敌方行动、10 次战斗清理和多分辨率检查通过。
- `tools/smoke_stage11d_battle_feedback.gd`
  - 18 个音效加载/播放、12 路音频池、缺失音效一次性警告、行动音效映射、群体去重、镜头反馈开关、100 次混合反馈、三种分辨率和场景清理通过。

已检查分辨率：

- 1920×1080
- 1600×900
- 1280×720

自动测试中没有发现持续增长的临时节点、重复信号、永久输入锁、重复结算或 ObjectDB 泄漏。缺失特效/投射物测试会有预期的一次性警告；Godot 在详细输出下可能显示控制器 `misc2` 环境警告，与战斗表现无关。

这些测试主要验证逻辑和资源生命周期。人工验收仍需确认：

- 音效整体响度和风格是否协调；
- 箭矢临时释放音是否需要替换；
- Boss 震动和红色闪光在实际显示器上是否舒适；
- 新角色立绘或缩放变化后锚点是否仍贴合；
- 连续实机战斗时动画节奏是否符合最终手感。

## 17. 当前已知限制与技术债

1. ActionVisualProfile 目前由代码集中生成，尚未拆分为独立 `.tres` 资源。
2. ARC/BEZIER 投射物类型尚未实现曲线运动，会安全回退到 LINEAR。
3. `last_impact_handle` 仍基于当前串行表现队列设计；未来若允许同一行动并发多个独立投射物，应让发射接口直接返回各自 Handle。
4. 音量和反馈开关只在运行时保存，没有设置 UI，也没有写入存档。
5. `arrow_release` 是临时替代音，需要后续替换为更合适且授权明确的弓箭音效。
6. 当前音效为临时 CC0 素材，尚未做完整的主观混音、响度标准化和风格统一。
7. 火元素 Boss 的陨石及火焰技能表现没有实现。
8. 本阶段没有接入 BGM、环境音、角色语音、正式粒子或复杂镜头演出。
9. 当前工作区包含第10阶段和第11阶段的多项未提交改动；接手时不要执行 `git reset --hard`、清理未跟踪文件或覆盖现有资源。

## 18. 后续阶段建议

建议后续按以下顺序继续：

1. 先进行一次完整人工验收，记录需要微调的音量、锚点、缩放、震动和闪光参数。
2. 将 `arrow_release` 换成授权逐项确认过的真实弓箭 CC0 音效。
3. 增加设置界面，并将 SFX 音量、震动、闪光和命中停顿开关写入持久化设置。
4. 开始火元素 Boss 的正式表现：技能独立 action_id、陨石预警、投射物/落点、爆炸、群体聚合及安全清理。
5. 如行动配置继续增长，再评估将代码注册的 Profile 渐进迁移到 `.tres`，不要一次性重构稳定注册表。
6. 在正式音频资源确定后做统一响度、峰值和群体叠加检查。
7. 后续可选实现拖影、正式镜头设计、屏幕特效和更细致的 Boss 节奏，但仍保持与战斗计算完全解耦。

## 19. 新任务接手检查清单

继续开发前建议依次检查：

1. 阅读 `docs/GAME_DESIGN.md`、`docs/codex_handoff_overall.md`、本文档以及 `docs/audio/` 下两份授权文档；
2. 查看 `git status --short`，确认工作区已有改动，不要误删；
3. 运行第8阶段和第11阶段现有 smoke tests；
4. 确认 `default_bus_layout.tres` 中只有现有 SFX Bus；
5. 新行动必须使用 BattleSystem 已有真实 action_id；
6. 新表现必须注册到现有 Registry，并提供缺失资源回退；
7. 群体行动必须验证源动画一次、主要音效一次、每目标结果一次、整体完成一次；
8. 新临时音频必须记录来源页面、作者、许可证、下载日期和原始/游戏文件对应关系；
9. 完成后至少回归 1920×1080、1600×900、1280×720；
10. 不修改 BattleSystem、EnemyAI、伤害治疗计算、装备词条、技能冷却、输入锁和胜负结算，除非新的阶段需求明确授权。

## 20. 交接结论

第11阶段已经从通用表现基础设施推进到我方、普通敌人、树精 Boss、临时音效和镜头反馈的完整闭环。当前实现能够在不触碰战斗计算的前提下，稳定完成释放、飞行、命中、治疗、受击、死亡、群体聚合和场景清理。

后续开发应以当前 Registry、表现队列和清理机制为基线做增量扩展，优先补齐火元素 Boss、设置持久化和正式音频替换，避免重做已通过测试的第11阶段框架。
