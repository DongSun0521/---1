# 《冒险村》第12阶段 12D 交接：生活角色生产与成长闭环

## 完成范围

12D 继续以 `GameState.character_roster` / `CharacterRoster` 为角色唯一真源，并直接使用现有 `buildings[*].jobs` 作为岗位运行态。本阶段没有新增第二套角色、岗位或生产系统。

已完成：

- 岗位效率接入农田、食物制造所、武器制造所和医院的既有完成结算；
- 六类生活建筑按等级同步岗位数量，民居保留零岗位覆盖；
- 岗位扩容保留已有人员，岗位缩减自动撤下超额角色并修复双向关系；
- 有效生产周期为全部有效在岗角色结算工作经验；
- 生活角色独立连续升级、剩余经验保留和五项生活属性成长；
- 生活特性独立配置，并统一参与效率、经验与可选产量加成；
- 存档版本4、v0～v3迁移、岗位校正和必要的生产结算去重状态；
- 生活角色页和建筑岗位区补充等级经验、特性说明、人员效率和最终倍率；
- 12D专项 Smoke 与 Stage 8～12D 历史回归。

科研所和资源收集所目前没有既有实际生产项目，因此本阶段只提供完整岗位、效率、倍率和后续结算接口，不虚构每日科研点或采集资源。它们未来完成真实项目时应调用同一个工作经验结算入口。

## 生产倍率

单人岗位效率：

```text
岗位效率百分比
= 100
+ min(对应生活属性, 100) × 0.5
+ 适用于该岗位的特性效率加成
```

多人建筑人员效率：

```text
人员效率百分比 = 所有有效在岗角色岗位效率百分比的算术平均
```

无人上岗时人员效率固定为100%。

可选生产量特性同样按有效在岗角色取平均，最终倍率为：

```text
最终生产倍率
= 人员效率百分比 / 100
× (1 + 平均生产量特性加成 / 100)
```

整数产出统一使用四舍五入（0.5向上）：

```text
最终整数产出 = floor(原有基础产出 × 最终生产倍率 + 0.5)
```

原有材料消耗、生产周期、项目状态、治疗和配方逻辑未重写。

主要接口：

```gdscript
get_life_job_efficiency(character_id, building_id, job_id)
get_life_job_efficiency_preview(character_id, building_id, job_id) # 兼容别名
get_building_personnel_efficiency(building_id)
get_building_final_production_multiplier(building_id)
get_building_production_details(building_id)
calculate_building_production_output(building_id, base_amount)
```

## 岗位数量

配置位于 `systems/building_system.gd`：

```text
默认：Lv.1=1，Lv.2=2，Lv.3=3，Lv.4=4
```

使用默认曲线：

- 农田 `farm`
- 食物制造所 `food_workshop`
- 武器制造所 `weapon_forge`
- 资源收集所 `resource_collection`
- 科研所 `research_lab`
- 医院 `hospital`

单独覆盖：

- 民居 `residence`：Lv.1～4均为0

首槽继续使用12C的原岗位ID；新增槽使用稳定后缀，例如 `farmer_2`、`farmer_3`、`farmer_4`。升级补槽不影响原人员。缩减时保留靠前槽位，超额角色恢复 `IDLE`，清空角色侧建筑和岗位ID，并发送角色、岗位和建筑刷新信号。

同步接口：

```gdscript
get_building_job_slot_count_config(building_id)
sync_building_jobs_to_level(building_id, emit_signals = true)
sync_all_building_jobs_to_levels(emit_signals = true)
```

## 工作经验与生活成长

- 每个有效生产周期基础工作经验为10；
- 特性经验加成按角色当前岗位计算，结果同样四舍五入（0.5向上）；
- 空闲角色、无效岗位和未完成生产不获得经验；
- 同一建筑完成周期通过存档中的结算键避免重复发放；
- 农田同一天有多个地块成熟时视为一次建筑完成结算，每名有效角色只获得一次经验；
- 医院制药和治疗完成均属于有效工作；
- 经验写入 `CharacterRoster` 的生活角色公共经验字段，`life_data.work_experience` 保留为旧接口兼容镜像。

升级规则：

```text
升级需求 = 100 + (当前等级 - 1) × 50
每级主要生活属性 +2
属性上限 = 100
```

一次经验可连续升级并保留剩余经验。在岗时提升当前岗位对应属性；空闲或岗位无效时提升当前最高生活属性。最高属性并列时固定顺序为：

```text
farming → crafting → gathering → research → medical
```

生活成长不调用战斗经验接口，不改变生活特性和岗位。

主要接口：

```gdscript
settle_life_job_work_experience(building_id, settlement_key)
add_life_character_experience(character_id, amount, emit_signals = true)
get_life_experience_to_next_level(level)
get_life_character_upgrade_requirement(character_id)
```

新增信号：

- `life_character_experience_changed`
- `life_character_leveled_up`
- `life_work_settled`

## 生活特性配置

配置由以下文件统一管理：

- `scripts/data/life_trait_definition.gd`
- `scripts/data/life_trait_database.gd`

每项配置包含：

- `trait_id`
- `display_name`
- `description`
- `applicable_job_types`
- `efficiency_bonus_percent`
- `work_experience_bonus_percent`
- `production_bonus_percent`

当前示例：

| trait_id | 显示名称 | 适用岗位 | 效率 | 经验 | 产量 |
| --- | --- | --- | ---: | ---: | ---: |
| `seasoned_farmer` | 农耕能手 | `farming` | +10% | +20% | +5% |
| `steady_hands` | 巧手工匠 | `crafting` | +10% | +10% | 0 |
| `herbal_instinct` | 仁心医者 | `medical` | +10% | +20% | 0 |

角色只保存特性ID。预览、正式生产和经验结算都通过 `LifeTraitDatabase` 读取同一配置。

## 存档版本与迁移

`SaveSystem.CURRENT_SAVE_VERSION` 为4。

v4新增或明确保存：

- 生活角色等级、当前经验和下一级需求；
- 成长后的五项生活属性；
- `life_trait_ids`；
- 按建筑等级生成后的 `buildings[*].jobs` 运行态；
- `life_work_settlement_keys`，用于生产周期经验去重。

加载顺序：

1. 加载或创建 `CharacterRoster`；
2. 执行12B战斗成长默认迁移；
3. 执行12C生活特性默认迁移；
4. 执行12D生活等级、经验镜像、属性上限和缺失默认特性迁移；
5. 恢复资源、装备、建筑、项目、农田、制造、医院、远征和战斗状态；
6. 按建筑等级重新生成岗位数量；
7. 修复重复、失效、超额和单边岗位引用；
8. 重建旧战斗运行态适配并发送全量刷新信号。

版本0～3的资源、装备绑定、建筑等级、战斗状态和历史生产进度继续按原策略保留。

## 主要修改文件

- `autoload/game_state.gd`
- `systems/building_system.gd`
- `systems/character_roster.gd`
- `systems/save_system.gd`
- `systems/farm_system.gd`
- `systems/food_workshop_system.gd`
- `systems/forge_system.gd`
- `systems/hospital_system.gd`
- `systems/project_system.gd`
- `scripts/data/life_stats.gd`
- `scripts/data/life_trait_definition.gd`
- `scripts/data/life_trait_database.gd`
- `features/village/village_view.gd`
- `tools/smoke_stage12d_life_production_growth.gd`

12A～12C Smoke中的存档版本和正式特性效率断言同步更新到v4语义。

## 验证

12D专项 Smoke 覆盖：

- 无人岗位基础产出；
- 单人、多人算术平均效率；
- 属性100效率封顶；
- 特性效率、经验和可选产量加成；
- 六类建筑岗位等级扩容、民居零岗位覆盖；
- 岗位缩减、靠前保留和超额角色撤下；
- 有效生产经验、无效生产不发经验、同周期去重；
- 连续升级、剩余经验、岗位属性成长、空闲并列规则和100上限；
- 农田、食物制造、武器制造、医院制药与治疗完成；
- v4存档往返、v3缺失字段迁移和岗位数量校正；
- 生活角色与建筑岗位UI补充。

已通过：

- Stage 8
- Stage 9A～9D
- Stage 10A～10E
- Stage 11A～11D
- Stage 12A～12D

11A、11C、11D中的缺失特效、投射物和音效警告仍是测试主动验证的既有回退路径。

## 留给12E

- 科研所和资源收集所尚无真实项目/产出，未来应在实际完成事件接入现有倍率与经验接口；
- 当前结算键按现有“一栋建筑每天最多完成一次”生产模型设计；若12E允许同建筑同日并行或连续完成多个项目，应为生产项目增加持久化唯一周期ID；
- 生活角色头像、美术、岗位筛选和更明确的升级反馈仍可完善；
- 当前特性与成长数值是首版平衡值，尚无外部资源文件、等级上限或重置方案；
- 招募、随机角色、疲劳、心情、休息、自动排班、关系、寻路和工作动画仍未实现。
