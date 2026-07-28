# 《冒险村》第12阶段 12C 交接：生活角色页面与岗位分配基础

## 完成范围

12C 继续使用 `GameState.character_roster` / `CharacterRoster` 作为全部角色的唯一真源，没有创建第二套生活角色数据。当前已完成：

- 村庄“生活角色”入口、仅限 `LIFE` 类型的角色列表与详情；
- 五项生活属性、生活特性、工作经验、当前岗位和效率预览；
- 现有七类建筑的固定首版岗位配置，其中民居暂时没有岗位；
- 从角色页和建筑页进行分配、替换、撤下和查看人员；
- 角色侧与建筑岗位侧的统一写接口、刷新信号和双向一致性修复；
- 存档版本 3，以及版本 0～2 和损坏岗位引用的安全迁移；
- 12C 专项 Smoke 和第 8～12C 阶段历史回归。

本阶段只建立“谁在哪个建筑工作”的数据与界面闭环，不会修改农田、制造、医院或其他建筑的正式生产结算。

## 建筑岗位配置

岗位模板定义在 `systems/building_system.gd` 的 `JOB_CONFIG_BY_BUILDING` 中。每个岗位槽位包含：

- `job_id`
- `job_type`
- `display_name`
- `slot_index`
- `character_id`

首版固定配置：

| 建筑 | building_id | job_id | job_type |
| --- | --- | --- | --- |
| 农田 | `farm` | `farmer` | `farming` |
| 食物制造所 | `food_workshop` | `food_crafter` | `crafting` |
| 武器制造所 | `weapon_forge` | `weapon_crafter` | `crafting` |
| 资源收集所 | `resource_collection` | `gatherer` | `gathering` |
| 科研所 | `research_lab` | `researcher` | `research` |
| 医院 | `hospital` | `medic` | `medical` |
| 民居 | `residence` | 无 | 预留 |

岗位运行态直接保存在现有 `GameState.buildings` 对应建筑字典的 `jobs` 数组中，存档只保存 `character_id`，不保存显示名称或角色对象副本。模板归一化逻辑会补齐旧存档缺失岗位，并为未来按建筑等级增加槽位保留 `slot_index`。

## GameState 统一接口

查询：

```gdscript
get_all_life_characters()
get_idle_life_characters()
get_building_jobs(building_id)
get_building_assigned_characters(building_id)
get_life_job_efficiency_preview(character_id, building_id, job_id)
get_life_trait_details(character_id)
```

写操作：

```gdscript
assign_life_character_to_job(character_id, building_id, job_id)
replace_life_character_in_job(building_id, job_id, new_character_id)
unassign_life_character(character_id)
unassign_building_job(building_id, job_id)
set_life_character_work_experience(character_id, work_experience)
```

12A 的 `set_life_character_assignment()` 保留为兼容入口，但现在会转发到正式分配/撤下逻辑，不能再产生只有角色侧记录、没有建筑岗位记录的正常运行态。

岗位变化会发出：

- `character_data_changed`
- `character_roster_changed`
- `life_job_assignments_changed`
- `building_state_changed`
- `state_changed`

UI 只调用以上接口，不直接修改角色岗位字段或建筑 `jobs` 数组。

## 分配规则

- 只有带 `LifeCharacterData` 的 `LIFE` 角色可以进入生活岗位；
- `UNAVAILABLE` 角色不可分配；
- 新分配只接受空岗位和完全空闲的角色；
- 已分配角色不能进入第二个岗位；
- 替换会把原角色恢复为 `IDLE`，并把新角色设为 `WORKING`；
- 撤下会清空所有该角色的建筑引用，并清空 `assigned_building_id` / `assigned_job_id`；
- 无效角色、建筑和岗位 ID 返回 `false` 或空结果，不抛出错误。

## 效率预览

默认生活属性范围是 0～100，因此本阶段使用平衡后的预览公式：

```text
岗位效率 = 100% + min(对应生活属性, 100) × 0.5% + 生活特性预留加成
```

对应关系为 `farming`、`crafting`、`gathering`、`research`、`medical`。生活特性定义提供 `efficiency_bonus_by_job` 扩展点，但当前默认特性加成为 0，不会进入正式生产结算。

## 存档版本与迁移

`SaveSystem.CURRENT_SAVE_VERSION` 已从 2 提升到 3。

- `CharacterRoster` 继续保存生活属性、生活特性、工作经验、岗位字段和工作状态；
- 现有 `buildings` 字典保存岗位模板运行态及槽位 `character_id`；
- 版本 0～2 缺少岗位数组时自动补默认岗位；
- 版本 2 中只有角色侧的合法岗位记录会迁移进空的默认槽位；
- 建筑槽位存在合法角色但角色侧缺失岗位时，以建筑槽位修复角色侧；
- 同一角色被多个岗位引用时，按建筑固定顺序只保留第一个有效引用；
- 缺失角色、战斗角色或 `UNAVAILABLE` 角色的岗位引用会被清空；
- 无法恢复的角色侧岗位记录会清空并恢复 `IDLE`；
- 资源、装备、战斗、远征、建筑等级和未知扩展字段保持原有加载策略。

## 界面入口

- 村庄左侧“生活角色”热点打开 `LifeCharacterPage`；
- 角色页左侧是生活角色列表，右侧是详情、当前岗位、效率和全部岗位选择；
- 点击任意建筑后，建筑详情中的“建筑岗位”区域显示人员、效率、空闲角色分配、替换、撤下和查看角色按钮；
- 角色详情中的“查看当前建筑”可回到对应建筑岗位面板。

## 验证

新增 `tools/smoke_stage12c_life_jobs.gd`，覆盖：

- 默认三名生活角色与类型过滤；
- 六个固定岗位和民居空岗位；
- 分配、撤下、替换、重复分配拦截；
- 战斗角色、不可用角色、无效 ID 拦截；
- 角色/建筑双向一致性与效率预览；
- 工作经验和岗位关系存档往返；
- 版本 0、版本 2 和损坏版本 3 数据迁移；
- 生活角色入口、详情和建筑岗位 UI。

第 8、9A～9D、10A～10E、11A～11D、12A～12C Smoke 均通过。11A、11C、11D 中的缺失特效、投射物和音效警告仍是测试主动验证的回退路径。

## 留给 12D

- 将岗位效率正式接入建筑生产结算，并明确基础产量、乘区和取整规则；
- 决定岗位数量随建筑等级增长的配置方式，以及已有分配在降级时的处理；
- 实现工作经验增长、生活角色升级与属性成长；
- 将生活特性正式接入效率，并建立资源化特性数据库；
- 增加更正式的头像、美术、岗位筛选和操作反馈；
- 为招募、随机角色、疲劳、心情、休息、排班、寻路和工作动画另行设计，不应复用建筑生产结算作为角色真源。
