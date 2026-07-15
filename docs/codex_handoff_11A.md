# Codex 交接记录：第11阶段 11A

本文档依据当前工作区实际代码整理，记录截至2026-07-15的11A实现状态。它不是设计目标复述；其中“已知问题”描述的是当前代码仍然存在的真实限制。

## 1. 本线程完成的功能

本线程在现有 `BattleView` 串行表现队列上接入了通用战斗特效框架，没有修改 `BattleSystem` 的伤害、治疗、目标、死亡、奖励或胜负计算。

已完成：

- 建立 `BattleEffectData`、`BattleProjectileData`、`BattleActionVisualProfile` 三种 Resource 数据结构。
- 建立特效注册表，统一提供 `effect_id`、`projectile_id`、视觉行动ID到配置的查询。
- 支持静态纹理和 `SpriteFrames` 两种播放后端；Spine类型仅识别并安全跳过。
- 支持特效Handle、完成信号、自动销毁、主动停止和战斗退出时统一清理。
- 支持线性投射物、朝飞行方向旋转、抵达回调和抵达后的命中特效。
- 支持命中、奥术爆炸、治疗圈、地面预警、树精地刺等通用表现流程。
- 为警告圈实现淡入及缩放脉冲。
- 为带烘焙棋盘背景的RGB资源增加显示层Shader键控；没有修改原始图片。
- 在战斗场景运行时创建地面、单位、投射物、命中、浮字和覆盖层。
- 在 `BattleUnitView` 增加投射物、身体中心、地面、通用特效和伤害数字锚点。
- 将血条表现改为Tween更新，伤害和治疗数值仍读取现有结构化行动结果。
- 增加表现执行中的一次性锁，保持既有输入锁覆盖投射物、特效、受击和死亡表现。
- 增加退出树后的协程保护，避免旧表现继续访问已经释放的单位节点。
- 生成五个当前版本的 `SpriteFrames` 资源及对应生成工具。
- 增加11A专项冒烟测试、100次混合表现压力测试和三分辨率截图工具。

## 2. 修改和新增的核心文件

### 修改

- `features/battle/battle_view.gd`
  - 创建特效层和运行时播放器。
  - 从既有 `presentation_events` 解析视觉行动ID。
  - 串联释放帧、预警、投射物、命中特效、浮字、血条和死亡等待。
  - 使用 `presentation_in_progress` 防止重复表现流程。
- `scripts/battle/battle_unit_view.gd`
  - 新增五种锚点。
  - 新增 `get_effect_anchor_global_position()`。
  - 新增 `animate_hp_to()`。
  - 浮字改为从 `DamageNumberAnchor` 起始。

### 新增运行时代码

- `scripts/battle/effects/battle_effect_data.gd`
- `scripts/battle/effects/battle_projectile_data.gd`
- `scripts/battle/effects/battle_action_visual_profile.gd`
- `scripts/battle/effects/battle_effect_context.gd`
- `scripts/battle/effects/battle_effect_handle.gd`
- `scripts/battle/effects/battle_effect_backend.gd`
- `scripts/battle/effects/battle_effect_registry.gd`
- `scripts/battle/effects/battle_effect_player.gd`
- `scripts/battle/effects/battle_projectile_player.gd`
- `scripts/battle/effects/battle_audio_player.gd`
- `scripts/battle/effects/battle_camera_effects.gd`

### 新增生成资源与工具

- `assets/art/effect/sprite_frames/magic_bolt_frames.tres`
- `assets/art/effect/sprite_frames/hit_spark_frames.tres`
- `assets/art/effect/sprite_frames/arcane_burst_frames.tres`
- `assets/art/effect/sprite_frames/heal_circle_frames.tres`
- `assets/art/effect/sprite_frames/earth_spike_frames.tres`
- `tools/generate_battle_effect_frames.gd`
- `tools/smoke_stage11a_battle_effects.gd`
- `tools/capture_stage11a_resolutions.gd`

注意：当前 `assets/art/effect/` 整个目录在Git状态中仍为未跟踪，其中既包含用户提供的七张原始图片，也包含本线程生成的SpriteFrames。不要把原始图片误认为由生成工具创建。

## 3. 当前架构和关键接口

当前权威流程是：

```text
BattleSystem先完成行动计算并写入presentation_events
    -> BattleView.start_action()保持输入锁
    -> BattleView.play_presentation_events()
    -> resolve_visual_action_id()读取事件和source单位
    -> BattleEffectRegistry查询视觉配置
    -> 播放一次source攻击动画并等待release_frame
    -> BattleEffectPlayer或BattleProjectilePlayer播放纯视觉节点
    -> play_target_feedback()展示事件中既有伤害/治疗/死亡结果
    -> 等待必要特效和受击/死亡窗口
    -> 继续既有行动队列或胜负结算
```

### 数据结构

`BattleEffectData` 当前字段：

- `effect_id`、`playback_type`
- `texture`、`sprite_frames`、`animation_name`
- `spawn_anchor`、`offset`、`display_scale`、`rotation_degrees`
- `loop`、`auto_destroy`、`fallback_duration`、`follow_anchor`
- `default_z_group`、`remove_baked_checkerboard`
- `spine_resource_path`、`spine_animation_name`
- `start_sound_id`、`impact_sound_id`、`camera_shake_id`、`screen_flash_id`

`BattleProjectileData` 当前字段：

- `projectile_id`、`effect_id`
- `travel_type`、`travel_duration`、`arc_height`
- `rotate_to_direction`
- `source_anchor`、`target_anchor`
- `source_offset`、`target_offset`
- `impact_effect_id`

`BattleActionVisualProfile` 当前字段：

- `action_id`
- `cast_effect_id`、`warning_effect_id`、`projectile_id`、`impact_effect_id`
- `release_frame`、`warning_duration`、`impact_timing`
- `impact_delay`、`effect_impact_frame`
- `spawn_per_target`、`play_source_animation_once`
- `cast_sound_id`、`impact_sound_id`、`camera_shake_id`、`screen_flash_id`、`hit_stop_duration`

### 注册表接口

```gdscript
func get_effect(effect_id: StringName) -> BattleEffectData
func get_projectile(projectile_id: StringName) -> BattleProjectileData
func get_action_visual(action_id: StringName) -> BattleActionVisualProfile
```

找不到ID时通过 `warned_missing` 保证同一个缺失项只警告一次，并返回 `null`。播放器会返回已经完成的空Handle，因此表现队列不会卡住。

### 播放器接口

```gdscript
BattleEffectPlayer.play_effect(effect_id, context) -> BattleEffectHandle
BattleEffectPlayer.stop_effect(handle)
BattleEffectPlayer.clear_all_effects()
BattleEffectPlayer.get_active_effect_count() -> int

BattleProjectilePlayer.launch_projectile(projectile_id, source_view, target_view) -> bool
```

`BattleEffectContext` 提供 `source_view`、`target_view`、世界位置、方向、层覆盖和测试用时长覆盖。`BattleEffectHandle.completed` 是表现完成等待点。

### 战斗层级

`BattleView.build_visual_layout()` 运行时创建：

```text
Battlefield
|- GroundEffectLayer
|- UnitLayer
|- ProjectileLayer
|- ImpactEffectLayer
|- FloatingTextLayer
`- OverlayEffectLayer
```

单位节点实际放在 `UnitLayer`。当前伤害数字仍由每个 `BattleUnitView.float_layer` 管理，尚未迁移到全局 `FloatingTextLayer`。

### 单位锚点

`BattleUnitView` 当前创建：

- `ProjectileOrigin`
- `BodyCenterAnchor`
- `GroundAnchor`
- `EffectAnchor`
- `DamageNumberAnchor`

通过 `get_effect_anchor_global_position(anchor_id)` 查询。默认投射物起点按敌我方向选择单位宽度的22%或78%，尚未为每个角色做独立偏移配置。

### 当前行动映射

| 视觉行动ID | 当前表现 |
|---|---|
| `guard_basic_attack` | `hit_spark`，释放帧3 |
| `hunter_basic_attack` | `arrow_projectile`，释放帧4 |
| `mage_basic_attack` | `magic_bolt_projectile`，释放帧4 |
| `doctor_basic_attack` | `hit_spark`，释放帧4 |
| `shield_bash` | `hit_spark`，释放帧3 |
| `power_shot` | `arrow_projectile`，释放帧4 |
| `arcane_blast` | 每个目标一个 `arcane_burst`，延迟0.25秒 |
| `healing_art` | `heal_circle`，延迟0.25秒 |
| `medicine` | `heal_circle`，延迟0.18秒 |
| `ruins_guard_earth_spike` | 预警0.65秒，地刺延迟0.30秒命中 |
| `enemy_basic_attack` | `hit_spark`，释放帧4 |

投射物当前参数：箭矢0.30秒并旋转朝向；魔法弹0.42秒且不旋转；二者抵达后均播放 `hit_spark`。

## 4. 已完成的测试

### 11A专项测试

运行命令：

```powershell
tools\godot.bat --headless --path . --script tools\smoke_stage11a_battle_effects.gd
```

当前结果为 `stage11a battle effects smoke ok`。覆盖：

- 七个原始资源可加载。
- 五个SpriteFrames资源可加载、帧数/FPS/循环配置符合当前生成配置。
- 七个effect、两个projectile和主要行动映射已注册。
- 五种单位锚点存在。
- 1920×1080、1600×900、1280×720下地面锚点坐标一致。
- 箭矢正向和反向飞行。
- 魔法弹线性飞行。
- 缺失资源只记录一次并返回完成Handle。
- 100次混合命中、箭矢、魔法弹、治疗、爆炸、预警、地刺播放后活动节点数回落为0。

测试会故意请求 `missing_effect_for_test`，因此控制台出现一次缺失特效警告属于预期结果。

### 实际渲染截图

运行命令：

```powershell
tools\godot.bat --rendering-method gl_compatibility --path . --script tools\capture_stage11a_resolutions.gd
```

已成功生成1920×1080、1600×900、1280×720三张截图，输出到Godot的 `user://`，当前机器对应：

```text
C:/Users/Dong/AppData/Roaming/Godot/app_userdata/冒险村/
```

注意：Godot `--headless` 使用Dummy渲染器，不能读取Viewport纹理；截图工具必须使用正常Windows渲染运行。

### 回归测试

本线程执行并通过：

- `tools/smoke_stage8_battle.gd`
- `tools/smoke_stage9a_character_data.gd`
- `tools/smoke_stage9a_character_ui.gd`
- `tools/smoke_stage9b_equipment.gd`
- `tools/smoke_stage9c_forge.gd`
- `tools/smoke_stage9d_affixes.gd`
- `tools/smoke_stage10a_buildings.gd`
- `tools/smoke_stage10b_farm.gd`
- `tools/smoke_stage10c_food_workshop.gd`
- `tools/smoke_stage10d_hospital.gd`
- `tools/smoke_stage10e_logistics.gd`
- Godot无界面编辑器加载和项目短启动检查
- `git diff --check`

## 5. 已知问题和技术债

### 最高优先级：当前切帧不准确

用户已经实际观察并确认“特效切得不太对”。当前 `tools/generate_battle_effect_frames.gd` 的配置只是第一版推断：

| 资源 | 当前假设 |
|---|---|
| `magic_bolt_sheet.png` | 横向8帧，每帧192×1024 |
| `hit_spark_sheet.png` | 横向7帧，每帧310×724，末尾2像素未使用 |
| `arcane_burst_sheet.png` | 横向8帧，每帧192×1024 |
| `heal_circle_sheet.png` | 横向8帧，每帧192×1024 |
| `earth_spike_sheet.png` | 横向8帧，每帧192×1024 |

下一线程不应把这些参数当作最终正确值。用户正在准备修改切图；拿到新图或正确网格后，必须先更新 `SPECS`，重新运行生成工具，再调整注册表中的 `display_scale`、持续时间、命中延迟和锚点。

### 原始素材背景问题

- `magic_bolt`、`arcane_burst`、`heal_circle`、`earth_spike` 图像有Alpha。
- 当前 `arrow.png`、`warning_circle.png`、`hit_spark_sheet.png` 是RGB图，棋盘格已经烘焙进像素。
- `BattleEffectPlayer.create_checkerboard_material()` 用饱和度键控去除灰白棋盘格。这是启发式方案，可能误删低饱和高光、白色核心或金属边缘。
- 最佳修复是换成真正透明背景的PNG，然后关闭对应EffectData的 `remove_baked_checkerboard`，而不是继续调Shader阈值。

### 数据驱动尚未完全落地

- 三种数据类型是Resource，但当前默认配置全部在 `BattleEffectRegistry.initialize_defaults()` 中以代码构造，没有独立 `.tres` 数据文件。
- `impact_timing`、`effect_impact_frame`、`spawn_per_target`、`play_source_animation_once` 当前主要是描述字段；运行时实际依赖 `impact_delay` 和 `BattleView` 固定流程，并没有真正监听AnimatedSprite的指定帧事件。
- `cast_effect_id` 尚未播放。
- `follow_anchor` 尚未实现持续跟随。
- `BattleProjectileData.ARC` 和 `BEZIER` 当前明确回退为直线。
- `last_impact_handle` 是单一字段，依赖当前表现队列串行执行；未来若允许多个投射物并行，应改为每次发射返回独立结果对象。

### 层级和锚点仍需完善

- `FloatingTextLayer` 和 `OverlayEffectLayer` 已创建，但当前未承担正式内容。
- 伤害数字仍是单位局部子节点，尚未验证角色死亡节点隐藏时的全局浮字需求。
- 锚点只按单位矩形生成，没有接入 `BattleVisualRegistry` 的角色级锚点偏移。
- 地刺、治疗圈和预警圈的最终缩放、脚底位置仍需在正确切图后重新验收。

### 测试限制和现存警告

- 专项测试验证了框架、生命周期和坐标，但没有逐项自动断言“源动画恰好播放一次”；这一点目前由 `BattleView` 在目标循环外播放source动画的代码结构保证。
- 项目测试广泛使用Godot `assert()`；某些断言失败时Godot脚本进程可能仍返回退出码0，不能只看进程退出码，必须同时检查输出中是否有 `SCRIPT ERROR` 或 `Assertion failed`。
- `smoke_stage8_battle.gd` 和正常渲染截图工具退出时仍可能输出既存的 `ObjectDB instances leaked at exit` 提示；11A专项测试已能干净退出。该提示尚未完成根因清理。
- 截图文件位于 `user://`，不在项目仓库中，也不是自动化基准图。

## 6. 下一阶段建议

建议下一线程先完成“11A资源修正”，再进入11B：

1. 向用户确认每张新序列图的总尺寸、行列数、有效帧数和透明背景。
2. 更新 `tools/generate_battle_effect_frames.gd`，重新生成全部SpriteFrames。
3. 逐帧检查Atlas区域，确认没有跨帧、空帧、主体截断或中心漂移。
4. 重新调整 `BattleEffectRegistry` 中的缩放、FPS、fallback_duration、释放帧和impact_delay。
5. 为角色级 `ProjectileOrigin` 和地面锚点增加配置，不再只使用通用比例。
6. 完成游侠、法师、治疗者和药品的实际战斗逐项录屏或截图验收。
7. 将 `effect_impact_frame` 接到真实动画帧回调，而不是继续用秒数近似。
8. 视11B需求决定是否把注册表代码配置迁移为 `.tres` 数据资源。
9. 11D再正式实现音效、镜头震动、闪光和命中停顿；当前类是空实现。

## 7. 下一线程必须了解的注意事项

- 不要修改 `BattleSystem` 来配合特效。伤害、治疗、死亡和奖励已经在表现开始前完成计算；特效只能决定何时展示 `presentation_events` 中已有结果。
- 不要让投射物碰撞决定命中，也不要在命中特效回调中再次执行技能。
- 群体技能source动画必须只播放一次；目标特效可以并行，但行动队列只能完成一次。
- `BattleView.resolve_visual_action_id()` 当前通过事件的 `action_type`、`source_id` 和当前source单位的 `skill_id` 推导视觉ID。现有事件没有统一携带最终视觉action_id；若扩展事件字段，必须保持旧事件兼容。
- 页面或场景退出时必须调用 `effect_player.clear_all_effects()`；不要把特效Node存入 `GameState`。
- 新切图完成后必须重新生成 `.tres`，仅替换PNG不一定会修正Atlas区域。
- 原始资源路径必须保持 `res://assets/art/effect/`，不要改成 `effects`。
- 当前工作区不是干净提交：10D、10E、资源文字修复和11A改动同时存在，且大量文件未跟踪。不要使用 `git reset --hard`、`git checkout --` 或批量清理未跟踪文件。
- `assets/art/effect/` 中的原图属于用户输入，修改或替换前先确认文件状态；生成工具只应写 `assets/art/effect/sprite_frames/`。
- 继续工作前先运行 `git status --short`，并先跑11A专项测试和Stage8战斗回归，确认基线没有被新切图破坏。
