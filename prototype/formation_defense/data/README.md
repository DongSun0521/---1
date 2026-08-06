# 原型数据目录

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

- `enemy_profile_id`：现有 `charge`、`shield` 或 `formation_guard`；
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
