# 原型数据目录

## V2-5B 波次配置格式

`formation_defense_config.gd` 的 `WAVE_BATTLES` 保存原型波次。顶层字段为 `battle_id`、
`display_name`、`random_seed`、`initial_countdown`、`inter_wave_delay` 和 `waves`。每个 wave
包含唯一 `wave_id`、显示名及 `subwaves`；子波次的 `start_offset` 相对本波开始时间，内部
`spawn_groups` 支持：

- `enemy_profile_id`：现有 `charge` 或 `shield`；
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
