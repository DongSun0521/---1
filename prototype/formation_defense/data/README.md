# 原型数据目录

## V2-7A-P 角色大招配置

`CHARACTER_ULTIMATE_DEFINITIONS` 集中保存四名原型角色的大招数据；历史战斗缺省使用 `DEFAULT_CHARACTER_ULTIMATE_ENABLED=false`。只有 `v2_7a_player_ultimate_validation` 显式设置 `character_ultimate_enabled=true`，固定随机种子为 `2702`，并通过 `ULTIMATE_VALIDATION_DEPLOYMENT` 提供战士 `middle_c4`、游侠 `top_c2`、法师 `bottom_c2`、医生 `middle_c2` 的推荐部署。

通用能量值为上限 100、合法释放消耗 100，不设置额外冷却。角色只有在战斗 `RUNNING`、已经部署且仍存活时积攒能量；重开会恢复为 0，并清除事件计数与节流时间。每个大招定义包含 `ultimate_id`、`display_name`、`target_mode`、`cast_range`、`effect_radius`、`damage` 或 `healing`、可选 `stun_duration`、能量字段和程序化表现颜色。位置型大招还使用 `cast_area_shape=FORWARD_RECT`、`cast_rect_width_ratio=0.5` 与 `cast_rect_direction=TOWARD_ENEMY_SPAWN`；矩形始终在 1802×414 逻辑战场内计算和裁切，实际作用圆则在规范化屏幕空间判定与绘制：

- `guard`：位置目标，距离 320、半径 140、伤害 35、眩晕 1.5 秒。
- `hunter`：敌人目标，距离 900、吸附半径 70、伤害 140。
- `mage`：位置目标，距离 700、半径 180、伤害 70。
- `doctor`：位置目标，距离 600、半径 200、治疗 90，只作用于存活且受伤角色。

职业回能参数集中保存在对应大招定义中：`guard` 每秒 1.5，`DAMAGE_TAKEN` +3、节流 0.75 秒；`hunter` 每秒 1.8，`NORMAL_ATTACK_HIT` +1、`NORMAL_ATTACK_KILL` +5；`mage` 每秒 2.2，`NORMAL_ATTACK_HIT` +2；`doctor` 每秒 1.3，`AUTO_HEAL` +4。事件由现有角色普攻结果、敌人对角色正式伤害结果和医生有效自动治疗结果上报；大招结算直接复用伤害/治疗实体入口，但不经过这些普通行为事件，因此不会形成大招回能循环。

验证战继续使用 V2-7A-R 已有的角色接敌运行逻辑，但拥有独立接敌参数：搜索 300、攻击距离 160、线路容差 112、回头容差 12、敌人攻击伤害 10、间隔 1.0 秒。三波分别生成 3、6、9 只现有 `charge` 敌人，共 18 只；生成组只覆盖本战所需的 220/240/200 生命与 42 移速，不改变 `charge` profile 或任何历史 battle。大招伤害、治疗与眩晕分别调用现有敌人受伤、角色治疗和敌人控制入口，不建立第二套生命、死亡或攻击结算。

## V2-7A-R角色接敌配置

`v2_7a_character_contact_validation`使用固定种子2701和三波2/5/5普通敌人计划。
顶层`character_contact_combat_enabled=true`是唯一启用入口；缺省值为`false`，历史battle不需要
重复声明。`character_contact_combat`集中保存：

- `eligible_enemy_profile_ids`：允许接敌的现有profile，本战斗仅为`charge`；
- `acquisition_range`与`attack_range`：发现/跟随目标和停止攻击的逻辑距离；
- `lane_tolerance`与`backtrack_tolerance`：路线横向兼容和避免远距离回头的容差；
- `attack_damage`与`attack_interval`：只属于本验证战的角色伤害和冷却。

当前验证值为搜索300、攻击160、垂直兼容112、回头容差12、伤害20、间隔0.8秒。三波生成组
把普通敌人生命单独设为120以保留接敌观察窗口；普通`charge`定义及全部历史battle不变。
角色生命继续读取原型`CHARACTER_DEFINITIONS`中的150/90/80/100运行时快照，不访问正式
CharacterRoster，也不写入存档。

## V2-6B-P混合威胁配置

`v2_6b_mixed_threat_validation`只组合现有`formation_guard`与`rush_raider`，固定种子2603，
使用3秒初始倒计时、3秒波间倒计时和2/1/7/13四段计划，总计16只护阵怪与7只突袭怪。
第一段以2只护阵怪建立A阵观察；第二段以1只突袭怪单独确认预警；第三段先生成6只护阵怪，
3秒后加入1只中路突袭怪；第四段以0.5秒间隔生成8只护阵怪，并从第2.5秒起以0.9秒间隔
错峰生成5只五路突袭怪。第三、四段的偏移来自真实事件时间线，使B阵配对/准备与
`PREPARING_RUSH`分别形成约1.3秒和5.0秒的可见重叠窗口。

混合方案复用护阵怪52靠拢速度、12逻辑像素完成阈值和3秒B阵准备，也复用突袭怪91生命、
42普通移速、0.48触发进度、1.25秒准备、3.25秒冲刺及4倍倍率；不包含profile覆盖、玩家加成、
直接伤害或内部状态写入。标准阵型仍为战士`middle_c1`、游侠`top_c1`、法师`bottom_c1`、
医生`middle_c2`。全部角色放在c3/c4前两排时会显著提前压制目标，但固定对照仍有3只突袭怪
漏入和5次A阵完成，因此属于强布阵收益，尚未同时消除两类威胁。

## V2-6B-R突袭怪配置

`rush_raider`沿用现有enemy profile结构，并以`formation_can_participate=false`明确排除在A/B阵
候选之外。突袭字段为`rush_enabled`、`rush_trigger_progress`、`rush_prepare_duration`、
`rush_duration`、`rush_speed_multiplier`和`rush_once`；旧profile省略这些字段时完全保持普通移动。

当前独立验证值为91生命、42普通移速、路线进度0.48触发、1.25秒准备、3.25秒冲刺、4.0倍
冲刺移速和单次消耗。准备期仍按普通速度移动，准备和冲刺均正常承受玩家伤害，漏怪伤害保持1；
配置不包含减伤、无敌、恢复或额外生命。`v2_6b_rush_raider_validation`使用固定种子2602和
1/2/5三波计划，只生成突袭怪，不包含护阵怪或混合目标优先级验证。标准参考阵型为战士
`middle_c1`、游侠`top_c1`、法师`bottom_c1`、医生`middle_c2`；角色全部前置时可能在突袭触发前
自然击杀目标，属于正常布阵收益而非验证失败。

## V2-6A护阵怪配置

`formation_guard`继续使用现有enemy profile结构。基础字段为`display_name`、`max_health`、
`move_speed`、`leak_damage`、攻击参数、`body_color`与`type_marker`；`formation_effects`按A/B
保存`player_damage_reduction`、`shield_visual_strength`和`effect_text`。伤害逻辑只读取当前
完整阵型同步下来的效果字段，不判断profile ID。未配置`player_damage_reduction`的旧敌人默认
为0；通用减伤与旧远程减伤取最大值而不叠加，并沿用`roundi(raw * (1-reduction))`取整。

`retain_a_effect_while_forming_b=false`表示护阵怪在B阵靠拢期间不保留A阵减伤；
`forming_b_warning_visual=true`只在真实FORMING_B期间启用轻量蓝灰预警，不改变组阵行为。旧profile省略
该字段时保持原行为。`v2_6a_formation_guard_validation`使用固定种子2601、3秒初始倒计时、
3秒波间倒计时和2/4/16三波计划。第三波4只护阵怪从中路先行，12只普通冲锋怪在第5秒后
以1.2秒间隔跟进。`formation_damage_prevented_by_profile`记录排除过量伤害后的真实减免量。
玩家策略对照只能通过战场左键公开入口选择集火目标；成员死亡前不得调用内部中断、降级、
直接伤害或状态写入。所谓“击杀后破阵”是正常攻击造成成员死亡后的结果，不是第二条玩家指令。

## V2-5C节奏方案

`v2_5c_pacing`使用与V2-5B相同的battle/wave/subwave/spawn_group结构。六波计划数为
`4、5、6、7、9、13`，初始倒计时3秒、统一波间倒计时4秒。顶层
`enemy_profile_overrides`只为本battle覆盖现有同类敌人的`max_health`和`move_speed`；
`formation_approach_speed`、`formation_completion_tolerance`和`formation_duration_multiplier`
只控制该方案的真实靠拢过程。旧battle省略这些字段时继续使用原有默认值。

节奏运行态由WaveDirector的`pacing`快照提供，包括每波记录、5秒压力采样、全场峰值、最长
非倒计时空场和最终耐久；这些数据仅用于原型调试与专项验收，不是正式关卡平衡数据。
其中`completed_a`和`completed_b`是本波首次完成的历史事件增量，不是当前活动阵型数量；
全局累计同样只增不减，A阵转入B阵、中断、降级或消灭都不会撤销已经发生的完成事件。

## V2-5B 波次配置格式

`formation_defense_config.gd` 的 `WAVE_BATTLES` 保存原型波次。顶层字段为 `battle_id`、
`display_name`、`random_seed`、`initial_countdown`、`inter_wave_delay` 和 `waves`。每个 wave
包含唯一 `wave_id`、显示名及 `subwaves`；子波次的 `start_offset` 相对本波开始时间，内部
`spawn_groups` 支持：

- `enemy_profile_id`：现有 `charge`、`shield`、`formation_guard` 或 `rush_raider`；
- `max_health`：可选的本生成组生命值覆盖；省略时使用敌人配置的默认生命值；
- `count`、`spawn_interval`：数量与同组出生间隔；
- `allowed_spawn_points`、`allowed_lanes`：现有刷怪口和路线ID；两者为空时使用全部已知刷怪口；
- `selection_mode`：`random` 使用固定种子随机，`round_robin` 按稳定顺序轮换。

简化示例：

```gdscript
{
    "wave_id": &"wave_1",
    "subwaves": [{
        "start_offset": 0.0,
        "spawn_groups": [{
            "enemy_profile_id": &"charge",
            "max_health": 100,
            "count": 2,
            "spawn_interval": 0.7,
            "allowed_spawn_points": [&"spawn_center"],
            "allowed_lanes": [&"formation_center"],
            "selection_mode": &"round_robin",
        }],
    }],
}
```

调度器会拒绝重复 wave ID、空波次、非正数量或生命值、负延迟/间隔、未知敌人/刷怪口/路线及无法匹配
任何出生候选的配置。V2-5B 配置仅用于结构验证，不是正式波次或平衡数据。

## V2-4 指挥相关约定

V2-4 不增加伤害、易伤、资源或正式波次数值。`command_demo` 仅继承 V2-3 已验收的
`formation_demo` 生成计划，避免两份出生节奏漂移。`FORMATION_SLOT_MOVE_SPEED` 只用于
FORMING_A/B 靠拢；完整阵型槽位维护使用语义独立且同为 80.0 的
`COMPLETE_FORMATION_SLOT_MAINTENANCE_SPEED`，因此调整阻止组阵窗口不会改变完整阵型行进。

Combat V2 原型数值和数据资源统一放在此目录。

V2-3 使用 `formation_defense_config.gd` 集中保存村庄耐久、敌人移动/生命/攻击
数值、旧三路、5条80像素等距兼容组阵轨、1条隔离测试轨、6个刷怪口、显式
`formation_route_index`、A/B邻轨跨度、路线组兼容关系、五类组阵区域、12个部署点、
4名固定角色数值、冲锋/盾甲两种怪物、推荐部署、A/B阵二维椭圆范围、固定槽位、
最短时间、会合超时、移速/远程减伤/保护/控制抵抗效果，以及V2-1/V2-2兼容方案和
带确定性`delay_after`的V2-3组阵演示方案。

这些内容仅用于 Combat V2 原型和确定性 Smoke，不是正式平衡数据，也不引用正式
角色、装备、建筑、探索或战斗配置。
