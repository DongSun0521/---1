# Combat V2：阵型塔防原型

## MVP 验证目标

Combat V2 MVP 用于验证“多路敌人向村庄推进，角色组成防线并自动作战”的核心循环
是否清晰、可操作且值得继续扩展。验证过程应优先关注战场信息可读性、阵型决策和
基础胜负反馈，不接入正式养成经济。

## V2-0 阶段范围

V2-0 只建立可独立运行、可整体删除的原型环境与占位界面。本阶段没有敌人、移动、
寻路、部署、攻击、阻挡、组阵、集火、技能、大招、村庄支援、波次、奖励或正式
玩法数据。

目录约定：

- `scenes/`：原型专用场景；
- `scripts/`：原型专用运行脚本；
- `data/`：后续原型数值和数据资源；
- `tests/`：只验证原型入口与隔离边界的自动化检查。

## 当前入口

入口场景：

```text
res://prototype/formation_defense/scenes/formation_defense_prototype.tscn
```

在 Godot 编辑器中打开该场景后选择“运行当前场景”（F6），即可单独启动。也可在
项目根目录运行：

```powershell
tools\godot.bat --path . `
  res://prototype/formation_defense/scenes/formation_defense_prototype.tscn
```

## 与正式系统的隔离原则

- 不替换默认主场景，不注册 Autoload，不增加正式入口；
- 原型运行时不读取或写入 `GameState`；
- 不接入 `CharacterRoster`、`SaveSystem` 或正式存档；
- 不读取正式角色、装备、建筑、战斗场景和正式数值配置；
- 原型运行资源的依赖必须保持在本目录内或使用 Godot 内建资源；
- 后续原型数值统一放入本目录的 `data/`；
- 删除整个 `formation_defense/` 目录后，正式项目应保持原有行为。

## 下一阶段

V2-1 将实现“三路、敌人移动、村庄耐久和基础胜负循环”。这些内容不属于 V2-0，
当前尚未实现。
