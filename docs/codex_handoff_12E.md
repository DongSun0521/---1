# 《冒险村》Stage 12E 交接：生活角色招募与角色池扩充

## 1. 本阶段结果

Stage 12E 已完成以下闭环：

- 生活角色页增加招募入口，招募页固定维护3个候选槽位；
- 候选支持单独招募、锁定/取消锁定、付费刷新未锁定候选；
- 随机角色生成集中在 `LifeRecruitmentSystem`，正式角色仍只写入
  `CharacterRoster`；
- 生活角色容量按全部民居实例等级累计；
- 正式生活角色支持锁定、确认解雇和工作中安全撤岗；
- 生活角色页支持状态/擅长属性筛选，以及等级、品质、五项属性和创建
  顺序排序；
- 存档升级到v5，保存候选池、候选锁定、刷新序号、随机状态、正式角色
  锁定及创建顺序；
- 新增12E专项Smoke，并完成Stage 8～12E回归。

本阶段未加入疲劳、心情、自动排班、关系、工作动画、寻路或战斗角色
招募。

## 2. 新增文件

- `systems/life_recruitment_system.gd`
  - 招募、刷新、候选锁定、随机生成、费用、品质和容量的集中配置与规则；
  - 负责候选池加载校验、冲突清理和缺槽补齐。
- `systems/life_recruitment_system.gd.uid`
  - Godot脚本资源UID。
- `tools/smoke_stage12e_life_recruitment.gd`
  - 12E专项自动化验收。
- `tools/smoke_stage12e_life_recruitment.gd.uid`
  - Godot脚本资源UID。
- `docs/codex_handoff_12E.md`
  - 本交接文档。

## 3. 修改文件

- `autoload/game_state.gd`
  - 注册 `LifeRecruitmentSystem` 和 `life_recruitment_state`；
  - 提供候选生成/查询/刷新/锁定/招募、容量、正式角色锁定/解雇、
    筛选排序等统一接口；
  - 增加招募、解雇、候选、锁定和容量刷新信号；
  - 民居升级后立即发送容量刷新；
  - 招募事务完成前使用无信号写入，候选移除和扣费完成后再统一刷新，
    避免UI观察到候选与正式名册短暂重复。
- `features/village/village_view.gd`
  - 生活角色页增加容量、招募入口、筛选、排序、正式角色锁定、解雇确认；
  - 新增三槽候选招募页和刷新/锁定/招募反馈；
  - 候选卡展示品质、等级、五项属性、擅长岗位、特性说明和费用。
- `scripts/data/life_trait_database.gd`
  - 补充采集特性 `keen_collector` 和研究特性 `curious_researcher`；
  - 增加统一特性ID及完整配置查询接口，供生成器复用。
- `systems/character_roster.gd`
  - 增加永久ID创建序号查询、最小序号校正、正式角色锁定接口；
  - 增加12E创建顺序迁移与候选元数据清理。
- `systems/save_system.gd`
  - `CURRENT_SAVE_VERSION` 从4升级为5；
  - 保存并恢复 `life_recruitment_state`；
  - 加载后校验候选，再执行原有岗位等级同步和双向关系修复。
- `tools/smoke_stage12a_character_roster.gd`
- `tools/smoke_stage12b_combat_characters.gd`
- `tools/smoke_stage12c_life_jobs.gd`
- `tools/smoke_stage12d_life_production_growth.gd`
  - 历史Smoke的当前存档版本断言更新为5。

## 4. 候选数据保存位置

候选不会写入 `CharacterRoster`。运行态唯一保存于：

```gdscript
GameState.life_recruitment_state = {
    "candidates": [
        {
            "character": CharacterRecord.to_dictionary(),
            "is_locked": false,
            "recruitment_cost": 6,
        },
    ],
    "refresh_sequence": 0,
    "random_seed": 1205001,
    "random_state": ...,
}
```

存档键同名：`life_recruitment_state`。

候选中的 `character` 是完整的生活 `CharacterRecord` 字典，但在正式招募
成功前不会进入角色仓库。招募成功时：

1. 再次检查候选存在、容量和粮食；
2. 通过 `CharacterRoster` 写入正式角色；
3. 清理候选标记，正式角色默认不锁定；
4. 移除已招募候选并立即补齐该槽；
5. 扣除费用并统一发出刷新信号。

随机数的64位 `random_seed` / `random_state` 在JSON存档中使用字符串保存，
避免浮点解析造成精度损失。

## 5. 随机生成规则

统一入口：

```gdscript
GameState.generate_life_character_candidate(forced_quality := -1)
```

规则集中在 `LifeRecruitmentSystem`：

- `character_type = LIFE`；
- 使用 `GameState.generate_character_id("life")`，底层仍为
  `CharacterRoster.generate_unique_id`；
- 从20个配置姓名中随机选择；
- 初始等级1，经验0，状态 `IDLE`；
- 不生成战斗模块；
- 随机选择五项属性中的一项作为主要属性；
- 主要属性至少比本次生成的最高次要属性高10点；
- 普通固定1个特性，稀有为1个或2个，史诗/传奇固定2个；
- 第一个特性与主要属性岗位匹配，第二个特性从剩余岗位特性中去重抽取。

品质概率：

- `COMMON`：65%
- `RARE`：28%
- `EPIC`：7%
- `LEGENDARY`：0%（自然生成关闭，测试/未来配置仍支持强制生成）

属性范围：

| 品质 | 主要属性 | 其他属性 |
|---|---:|---:|
| COMMON | 35～55 | 15～40 |
| RARE | 45～65 | 20～45 |
| EPIC | 55～75 | 25～50 |
| LEGENDARY | 65～85 | 30～55 |

品质目前只影响初始属性、特性数量概率、招募费用和UI显示，不影响等级上限
或12D成长曲线。

## 6. 招募及刷新费用

复用现有通用资源 `food`（粮食）：

| 品质 | 招募费用 |
|---|---:|
| COMMON | 6 |
| RARE | 10 |
| EPIC | 16 |
| LEGENDARY | 24 |

- 首次创建3名候选免费；
- 刷新全部未锁定候选消耗2粮食；
- 锁定候选刷新时原槽保留；
- 资源不足时，不改变候选池、正式角色或资源；
- 招募成功后立即补齐新候选。

费用查询：

```gdscript
GameState.get_life_recruitment_costs()
```

## 7. 角色容量

公式：

```text
生活角色容量 = 3 + 2 × 所有民居实例的等级总和
```

当前默认只有一个Lv.1民居，因此新游戏容量为5。实现会遍历现有
`buildings` 运行态中所有民居实例，不依赖“永远只有一个民居”的假设。

- 达到容量只限制新增招募；
- 旧档角色数超过容量时不会删除任何角色；
- 民居升级后容量立即重算并发出信号。

## 8. 解雇规则

统一入口：

```gdscript
GameState.dismiss_life_character(character_id, auto_unassign := true)
```

- 只允许生活角色；
- 默认三名测试角色没有特殊分支，遵循同一规则；
- 正式锁定角色不能解雇；
- UI必须经过确认；
- 工作中角色确认后先调用现有撤岗链路，再从 `CharacterRoster` 移除；
- `buildings[*].jobs`、角色侧建筑ID、岗位ID和工作状态同步清理；
- 本阶段不返还资源。

## 9. 筛选与排序

统一查询：

```gdscript
GameState.get_filtered_sorted_life_characters(filter_id, sort_id)
```

筛选：

- 全部、空闲、工作中；
- 擅长农业、制造、采集、研究或医疗。

“擅长”使用五项生活属性最高值判定；并列时沿用12D固定顺序：
农业、制造、采集、研究、医疗。

排序：

- 创建顺序升序；
- 等级、品质、农业、制造、采集、研究、医疗降序；
- 数值相同时以创建顺序稳定排序。

筛选和排序只处理快照，不修改 `CharacterRoster.character_order`。

## 10. v5存档与迁移

`SaveSystem.CURRENT_SAVE_VERSION = 5`。

v5新增保存：

- 完整候选角色字典；
- 候选锁定状态；
- 刷新序号；
- 随机种子及随机状态；
- 招募后正式生活角色的完整记录；
- 正式角色创建序号和锁定状态。

加载顺序：

1. 读取或初始化 `CharacterRoster`；
2. 执行v2战斗成长、v3生活岗位/特性、v4生活成长迁移；
3. 执行v5创建序号去重与候选标记清理；
4. 恢复资源、建筑、装备、生产、战斗等历史状态；
5. 校验候选必须为完整生活角色，清理重复ID和与正式角色冲突的ID；
6. 将缺失、损坏或冲突槽位重新生成到3个；
7. 按建筑等级同步岗位并修复角色/岗位双向引用。

v0～v4没有候选池时会免费生成3名候选，不改变旧档资源、建筑等级、
装备、战斗、生活角色等级/经验/属性/特性或生产进度。

## 11. 主要信号

- `life_recruitment_candidates_changed`
- `life_character_recruited(character_id)`
- `life_character_dismissed(character_id)`
- `life_character_lock_changed(character_id, is_locked)`
- `life_character_capacity_changed(current_count, capacity)`

原有 `character_roster_changed`、`character_data_changed`、
`life_job_assignments_changed` 和 `state_changed` 继续参与UI刷新。

## 12. 测试结果

12E专项 `tools/smoke_stage12e_life_recruitment.gd` 覆盖：

- 首次3候选、正式/候选唯一ID、生活类型和无战斗模块；
- 品质概率边界、四档属性范围、明确主要属性和特性数量；
- 招募成功、粮食扣除、招募后补槽、资源不足原子失败；
- 候选锁定、刷新保留和刷新费用；
- 容量满限制、民居升级扩容；
- 招募后立即分配现有岗位；
- 正式角色锁定、工作中解雇和岗位引用清理；
- 默认测试角色统一解雇规则；
- 状态/属性筛选和全部排序项；
- v5候选/锁定/刷新序号/RNG/正式成长往返；
- 重复、损坏和与正式名册冲突候选的加载修复；
- v0～v4迁移；
- 招募页与生活角色页控件。

最终回归结果：

- Stage 8：通过
- Stage 9A～9D：通过
- Stage 10A～10E：通过
- Stage 11A～11D：通过
- Stage 12A～12D：通过
- Stage 12E专项：通过

11A/11C的缺失特效回退警告和11D退出时的既存资源泄漏提示仍会出现，
但对应Smoke退出码为0。使用同一个PowerShell循环连续拉起多个Godot
进程时曾触发Godot 4.6.3原生崩溃；改为每个Smoke独立启动后全套通过，
未发现12E脚本错误。

## 13. 留给12F的问题

- 疲劳、心情、休息和工作可用性仍未实现；
- 自动排班、批量排班和岗位推荐仍未实现；
- 角色关系、生活事件和工作动画/寻路仍未实现；
- 品质、费用、姓名池和特性池需要后续玩法数据继续平衡；
- 候选暂时没有独立肖像池或角色外观生成；
- 当前民居容量逻辑已支持多个运行态实例累计，但现有建筑系统仍只有一个
  配置化民居实例，未来真正开放多实例建筑时应补充实例ID管理和UI；
- 自然传奇概率暂为0，未来若开放需同步调整概率展示与经济平衡；
- 招募历史、保底、批量招募、角色合成和品质晋升仍明确不在本阶段范围。
