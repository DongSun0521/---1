# 《冒险村》第12阶段 12A 交接文档

更新日期：2026-07-23  
范围：角色数据底座、角色仓库、版本化存档与最小调试入口

## 1. 本阶段结论

12A 在第9阶段角色与装备结构上增量扩展，没有重做战斗角色或战斗数值系统。

当前数据关系：

```text
CharacterRecord（公共字段）
    |- CombatCharacterData（仅战斗角色）
    `- LifeCharacterData（仅生活角色）

CharacterRoster
    -> 以 character_id 管理全部角色
    -> 为旧系统提供 character_runtime_states 战斗适配字典
    -> 为 BattleSystem 生成原有结构的四人单位快照
```

`CharacterDatabase` 继续保存固定职业、技能、特性和四名初始战斗角色模板；`CharacterRoster` 保存实际拥有的角色及其运行数据。

## 2. 默认角色

固定战斗角色继续使用原 ID，避免破坏装备、医院、战斗表现和既有测试：

- `guard`：阿盾，战士；
- `hunter`：林羽，游侠；
- `mage`：米娅，法师；
- `doctor`：露娜，治疗者。

12A 调试生活角色：

- `life_ahe`：阿禾，农业较高；
- `life_atie`：阿铁，制造较高；
- `life_xiaoyao`：小药，医疗较高。

三名生活角色只保存数据，不参与建筑产出、战斗、装备或医院治疗。

## 3. 核心文件

- `scripts/data/character_enums.gd`：角色类型、品质、战斗职业、工作状态枚举。
- `scripts/data/character_record.gd`：公共角色字段和可选模块组合。
- `scripts/data/combat_character_data.gd`：战斗属性、技能、装备槽、队伍、伤势及最终属性组合。
- `scripts/data/life_character_data.gd`：五项生活属性、生活特性、岗位和工作状态。
- `systems/character_roster.gd`：角色增删、ID、分类查询、默认数据、序列化和旧运行态迁移。
- `systems/save_system.gd`：`save_version = 1` 的字典/JSON存档入口。
- `autoload/game_state.gd`：对外提供角色仓库、存档和旧战斗系统适配接口。
- `tools/smoke_stage12a_character_roster.gd`：12A专项验收。

## 4. GameState 主要接口

角色查询：

```gdscript
get_character_ids()                  # 当前战斗队伍ID，保持旧语义
get_roster_character_ids()           # 全部角色ID
get_all_combat_characters()
get_all_life_characters()
get_roster_character(character_id)
get_character_roster_data()
has_roster_character(character_id)
```

角色管理：

```gdscript
generate_character_id(prefix)
add_roster_character(character_data)
remove_roster_character(character_id)
set_character_progression(character_id, level, experience, next_experience)
set_life_character_assignment(character_id, building_id, job_id, work_state)
```

存档：

```gdscript
create_save_data(base_data = {})
load_save_data(data)
save_game(path = "user://adventure_village_save.json", base_data = {})
load_game(path = "user://adventure_village_save.json")
get_save_error()
```

调试：

```gdscript
get_character_roster_debug_summary()
print_character_roster_debug()
```

## 5. 存档与迁移

- 当前 `save_version` 为1。
- 新存档保存角色公共字段、战斗/生活模块、装备槽、岗位状态和生成序号。
- 同时保存当前资源、建筑、装备实例、项目、农田、制造、医院、远征和战斗状态。
- 加载时只覆盖存档实际包含的字段，缺失字段保留当前安全默认值。
- 版本0或无 `character_roster` 的旧字典自动建立4名战斗角色和3名生活角色。
- 若旧字典包含 `character_runtime_states`，会迁移当前生命、伤势和装备槽。
- `create_save_data(base_data)` 会保留未知旧字段，便于未来迁移器继续传递扩展数据。
- 本阶段没有自动存档、存档槽或正式存档UI。

## 6. 兼容边界

- `character_runtime_states` 仍存在，但其值现在是仓库中 `CombatCharacterData` 的同一对象引用，供装备和医院旧接口使用。
- `adventurers` 仍是进入战斗前生成的兼容快照，不是新的角色权威来源。
- 战斗伤害、治疗、技能冷却、装备词条和表现 action_id 均未修改。
- 生活角色尚未接入建筑结算；12B/12C 应通过角色仓库接口读取岗位数据。
- 正式队伍编成尚未实现；当前四名角色的 `is_in_party / party_slot` 固定保持既有顺序。

## 7. 验证

专项测试覆盖：

- 默认4名战斗角色和3名生活角色；
- ID唯一、生成、添加、删除和锁定保护；
- 五项生活属性与岗位状态；
- 等级、经验、装备和岗位的JSON文件往返；
- 旧存档缺少角色仓库时的迁移；
- 旧资源、建筑和装备绑定保持；
- 四名角色继续进入现有战斗。

第8、9A～9D、10A～10E、11A～11D测试也已完整回归通过。

## 8. 后续建议

- 12B角色列表/详情应只读取仓库快照，不直接持有内部数组。
- 队伍编成应修改 `is_in_party / party_slot`，并增加四人上限和槽位冲突校验。
- 生活岗位系统接入建筑时，应由岗位系统消费 `LifeCharacterData`，不要把产出逻辑写进角色记录。
- 招募系统应使用 `generate_character_id()`，不要根据显示名称或数组下标生成ID。
- 正式存档阶段仍需补存档槽、原子写入、备份和失败恢复。
