# 《冒险村》项目总交接文档

> 更新日期：2026-07-15  
> 项目目录：`C:\游戏总文件夹\冒险村`  
> 当前分支：`main`  
> 当前HEAD：`7789d09`  
> 说明：本文依据当前代码、设计文档、测试脚本和Git文件历史整理。Git提交信息多数只有“111”等无语义文本，因此迭代名称以可验证的代码内容为准；无法精确还原的阶段不会臆测。

## 1. 项目定位与当前结论

《冒险村》是一个Godot 4单机原型，核心循环是：

```text
村庄安排生产、制造、治疗和建设
    -> 准备四人冒险队、口粮、药品和料理
    -> 在单区域节点地图移动、采集和战斗
    -> 每次远征日行动同步推进村庄后勤
    -> 返回或失败时结算物资、伤势和Boss结果
    -> 用冒险资源强化村庄、装备和队伍
    -> 再次远征
```

当前原型已经具备一条可运行的前后方循环：村庄、远征、回合战斗、Boss、成长项目、角色数据、装备锻造、农田、食物制造、医院伤势治疗、统一日报以及11A通用战斗特效框架。

当前仍不是完整游戏。存档、科研所、民居、资源收集所、生活角色岗位、第二区域、火元素Boss实战、正式音效和完整11B～11D表现均未完成。

设计事实来源位于：

- `docs/GAME_DESIGN.md`：完整目标设计。
- `docs/GAME_DESIGN_MVP.md`：早期最小循环设计。
- `docs/codex_handoff_11A.md`：11A详细技术交接。

设计文档文字仍写着建议放在项目根目录，但当前实际路径是 `docs/GAME_DESIGN.md`，后续线程应读取实际路径。

## 2. 迭代过程总览

### 2.1 2026-06-30：初始MVP框架

Git起点：`e2a4531 Initial commit`。

初始工程已经建立：

- Godot项目入口与 `GameState` 自动加载。
- 村庄、远征、战斗三个主页面和顶部资源栏。
- 基础资源、日期、冒险者和建筑运行状态。
- 村庄每日生产/消耗的早期版本。
- 线性节点式远征状态和携带补给。
- 最小回合战斗系统与战斗UI。
- `GAME_DESIGN_MVP.md` 中定义的早期六阶段目标。

该时期对应MVP文档中的阶段1～4的大部分基础能力：框架、村庄模拟、远征时间同步和基础战斗。具体阶段边界没有独立提交，不能从Git精确拆分。

### 2.2 2026-06-30：战斗与成长闭环增强

提交：`69d2f13`、`f215ccb`、`75a4cbe`。

从文件历史可确认的变化：

- 继续扩展 `BattleSystem` 和战斗界面。
- 调整战斗场景与表现。
- 加入 `ProjectSystem`。
- 扩展远征、村庄和主界面。
- 建立矿石/草药反哺、建设项目、队伍永久强化和Boss闭环的早期版本。

这一阶段大体对应MVP阶段5“成长闭环与Boss”。MVP阶段6“存档与体验整理”只存在于设计文档，当前代码没有正式保存/读取或自动存档系统。

### 2.3 2026-06-30：目录与功能结构迁移

提交：`644b385`。

工程从早期 `scenes/`、`scripts/ui/`、`scripts/systems/` 结构迁移到当前主体结构：

```text
autoload/
features/
scripts/data/
scripts/battle/
systems/
tools/
docs/
```

主场景和脚本转移到 `features/`，系统脚本转移到根级 `systems/`。项目当前入口是 `features/main/main.tscn`。

### 2.4 2026-07-03：阶段8，战斗表现和完整回合验收

提交：`75d291a` 中包含阶段8测试和相关代码。

实际落地：

- 四名固定角色和史莱姆/树精Boss战斗状态。
- 普攻、技能、防御、战斗药品。
- 速度排序、技能冷却、敌人AI和Boss周期性群攻。
- 结构化 `presentation_events`，将计算结果交给表现层。
- 角色/怪物待机、攻击、受击和死亡序列帧。
- 战斗输入锁、结果延迟确认、胜利失败回写远征。
- 战斗背景、单位站位和基础浮字。

验收脚本：`tools/smoke_stage8_battle.gd`。

### 2.5 2026-07-03：阶段9A，角色数据与角色界面

实际落地：

- `CharacterDefinition`、`CharacterRuntimeState`、`CombatStats`、`LifeStats`、`TraitDefinition`。
- 四名固定角色：阿盾、林羽、米娅、露娜。
- 四个职业定位和四个主动技能。
- 基础、永久、装备、伤势、临时属性的分层计算接口。
- 角色详情和属性展示。
- 特性数据已建立，但当前特性效果大多为 `reserved_noop`，不是完整特性玩法。

验收脚本：

- `tools/smoke_stage9a_character_data.gd`
- `tools/smoke_stage9a_character_ui.gd`

### 2.6 2026-07-03：阶段9B，装备系统

实际落地：

- 装备定义、装备实例、角色装备槽和仓库。
- 武器/防具职业限制。
- 装备提供攻击、防御、生命和速度等最终属性加成。
- 装备变化同步角色详情和战斗快照。

验收脚本：`tools/smoke_stage9b_equipment.gd`。

### 2.7 2026-07-03：阶段9C，武器制造所

实际落地：

- `ForgeSystem` 和单槽打造状态。
- 多个固定武器、防具配方。
- 启动时立即扣除资源。
- 按统一游戏日推进打造。
- 完成后创建装备实例并加入仓库。
- 武器制造所操作面板和状态显示。

验收脚本：`tools/smoke_stage9c_forge.gd`。

### 2.8 2026-07-03：阶段9D，装备技能词条

实际落地：

- 装备词条定义和触发结果。
- 技能原始伤害倍率、最终伤害、治疗、冷却、防御后回血、首次受击减伤等接口。
- 战斗日志记录词条触发。
- 词条不直接替代BattleSystem，只通过EquipmentSystem修正计算步骤。

验收脚本：`tools/smoke_stage9d_affixes.gd`。

### 2.9 2026-07-03：阶段10A，七座建筑与统一操作面板

实际落地：

- 七座建筑ID、数据、等级外观和村庄地图位置。
- 农田、食物制造所、武器制造所、医院、科研所、民居、资源收集所外显。
- 统一建筑点击、状态标签和操作面板框架。
- 武器制造所复用阶段9系统。
- 科研所、民居、资源收集所仍显示“暂未开放”。

验收脚本：`tools/smoke_stage10a_buildings.gd`。

### 2.10 2026-07-03：阶段10B，农田种植与持续生产

提交：`1f6671d`。

实际落地：

- `FarmSystem`、`CropData`、`FarmPlotState`。
- 农田等级控制解锁地块。
- 小麦和药草种植、生长、成熟、自动收获和循环种植。
- 农田产出接入统一游戏日。
- 旧固定每日产粮不再作为实际产出入口。
- 农田面板、建筑外显和远征后方报告同步。

验收脚本：`tools/smoke_stage10b_farm.gd`。

### 2.11 2026-07-03：阶段10C，食物制造、远征口粮和特殊料理

提交：`7789d09`，也是当前HEAD。

实际落地：

- `FoodWorkshopSystem`、食谱数据和单槽生产状态。
- 远征口粮从村庄粮食中加工，不再直接携带村庄粮食。
- 丰盛炖汤、猎手烤肉等特殊料理库存。
- 料理出发时消耗并应用临时远征属性。
- 远征每日消耗独立口粮。
- 远征返回、失败和新游戏清理料理状态。
- 食物制造在远征期间随统一日期继续推进。

验收脚本：`tools/smoke_stage10c_food_workshop.gd`。

### 2.12 HEAD之后未提交：阶段10D，医院制药、伤势与治疗

当前工作区实际已经实现，但尚未提交到Git：

- `HospitalSystem` 和 `HospitalProjectState`。
- 医院单工作槽：制作药品或治疗一名角色。
- 制药启动时扣草药，完成时只发放一次药品。
- 角色伤势状态 `healthy` / `injured`。
- 受伤最大生命按 `floor(伤势前生命 × 0.8)` 计算，料理临时生命加成随后加入。
- 正常返回按料理清除前生命比例判断伤势；失败返回全员受伤。
- 治疗中的角色阻止固定四人队出发。
- 治疗完成恢复健康并将当前生命设为最终最大生命。
- 旧医院自动产药实际结算已停用。

验收脚本：`tools/smoke_stage10d_hospital.gd`。

### 2.13 HEAD之后未提交：阶段10E，后勤整合与统一日报

当前工作区实际已经实现，但尚未提交到Git：

- `DailyReport` 结构化事件与资源净变化。
- `GameState.advance_day(reason)` 作为统一日期入口。
- 村庄休整和远征日行动共享后勤结算。
- 农田、食物制造、医院、建设和锻造完成事件汇总。
- 村庄后勤总览、远征准备检查和后方消息。
- 未来1天完成项目查询。
- 新游戏统一重置后勤状态。
- 顶部资源栏乱码修复：粮食、口粮、药品、矿石、草药、Boss核心。

当前 `advance_day()` 的实际处理顺序是：

```text
1. VillageSystem：农田推进/收获 + 村庄粮食消耗
2. FoodWorkshopSystem：食物制造
3. HospitalSystem：制药或治疗
4. ExpeditionSystem：远征口粮消耗
5. ProjectSystem：建设项目
6. ForgeSystem：装备打造
7. 日期 +1
8. 组装结构化DailyReport并发出刷新信号
```

注意：这与设计文档推荐顺序不完全相同，但当前测试以此顺序为稳定基线，不应无理由重排。

验收脚本：`tools/smoke_stage10e_logistics.gd`。

### 2.14 HEAD之后未提交：阶段11A，通用战斗特效框架

当前工作区实际已经实现，但资源切帧仍待修正：

- 通用特效、投射物和行动视觉数据。
- 特效注册表、静态纹理/SpriteFrames后端、Handle生命周期。
- 线性箭矢和魔法弹。
- 命中、奥术爆炸、治疗圈、预警圈和地刺表现。
- 地面、单位、投射物、命中、浮字和覆盖层。
- 单位投射物/中心/地面/特效/浮字锚点。
- 缺失资源安全回退。
- Spine、音效、镜头和闪光空接口。

专项交接见 `docs/codex_handoff_11A.md`。

验收工具：

- `tools/smoke_stage11a_battle_effects.gd`
- `tools/capture_stage11a_resolutions.gd`

## 3. 当前可玩内容

### 村庄

- 七座建筑有地图外显和统一操作面板。
- 农田可种小麦、药草并持续自动收获。
- 食物制造所可加工远征口粮和特殊料理。
- 医院可制作基础药品或治疗伤员。
- 武器制造所可按配方打造装备。
- 建设项目可升级农田/医院或永久强化队伍。
- 科研所、民居、资源收集所目前只提供说明和“暂未开放”状态。
- 后勤总览显示资源、地块、制造、医院、伤员、锻造及即将完成项目。

### 角色与装备

- 固定四人：守卫阿盾、游侠林羽、法师米娅、治疗者露娜。
- 每人一个主动技能，按冷却使用。
- 武器和防具通过装备实例管理。
- 装备基础属性和技能词条进入最终属性/战斗计算。
- 角色详情显示基础、永久、装备、伤势和临时属性构成。
- 特性数据存在，但当前没有完整可玩特性效果体系。

### 远征

- 当前只有一条森林/遗迹线性区域。
- 节点包含入口、史莱姆战斗、矿石采集、草药采集和树精Boss。
- 出发携带远征口粮、药品和可选料理。
- 移动/采集消耗一天及一份远征口粮。
- 远征日行动推进村庄后方生产。
- 正常返回返还剩余口粮和药品；失败按既有规则丢失/保留物资。
- Boss胜利发放核心和资源，并完成MVP统计。

### 战斗

- 四人回合制，速度决定行动顺序。
- 支持普攻、技能、防御、药品。
- 两只史莱姆普通战和树精Boss战。
- Boss每第三次行动使用群体攻击，11A表现映射为预警+地刺。
- 伤害、治疗、词条、死亡和奖励由 `BattleSystem` 计算。
- `BattleView` 只消费结构化结果并播放动画/特效。
- 火元素Boss已有美术和角色序列帧，但没有接入当前远征遭遇和正式技能。

## 4. 当前核心架构

### 4.1 入口与页面

- `project.godot`：Godot项目配置，注册 `/root/GameState` 自动加载。
- `features/main/main.tscn`：主场景。
- `features/main/main_view.gd`：村庄/冒险/战斗页面切换及MVP状态。
- `features/ui/top_resource_bar.gd`：顶部日期和核心资源。
- `features/village/village_view.gd`：村庄、建筑操作、后勤、准备、角色和装备综合UI。
- `features/expedition/expedition_view.gd`：节点地图、移动、采集、返程和后方日报。
- `features/battle/battle_view.gd`：战斗输入与表现队列。

### 4.2 状态总入口

`autoload/game_state.gd` 是当前运行状态和系统编排中心，持有：

- 日期和资源。
- 建筑、农田、食物制造、医院、锻造、建设状态。
- 角色运行状态、装备仓库和装备关系。
- 远征、战斗、Boss、统计和结算报告。
- 系统实例和跨系统信号。

UI原则上通过GameState查询和发请求；系统层不应直接操作UI节点。GameState已经较大，后续扩展时应避免继续把领域逻辑直接写入该文件，但不要在未覆盖测试前进行大规模拆分。

### 4.3 系统职责

| 系统 | 当前职责 |
|---|---|
| `VillageSystem` | 农田每日调用、村庄粮食消耗、旧兼容日报字段 |
| `ExpeditionSystem` | 地图、补给、移动、采集、返回和失败物资结算 |
| `BattleSystem` | 回合、目标、伤害、治疗、AI、死亡、奖励和结构化表现事件 |
| `ProjectSystem` | 一次一个建设/永久强化项目 |
| `BuildingSystem` | 七座建筑数据、等级、工作状态和项目摘要 |
| `FarmSystem` | 作物、地块、生长、收获和农田外显状态 |
| `EquipmentSystem` | 装备定义、实例、穿戴、属性和词条修正 |
| `ForgeSystem` | 装备配方、资源扣除、打造进度和产出 |
| `FoodWorkshopSystem` | 食谱、制造单槽、口粮和料理产出 |
| `HospitalSystem` | 制药/治疗单槽、伤势、治疗和远征结束伤势判定 |

### 4.4 数据对象

重要数据脚本位于 `scripts/data/`：

- 角色：`character_definition.gd`、`character_runtime_state.gd`、`character_database.gd`
- 属性：`combat_stats.gd`、`life_stats.gd`、`trait_definition.gd`
- 装备：`equipment_definition.gd`、`equipment_instance.gd`、`equipment_affix_definition.gd`
- 农田：`crop_data.gd`、`farm_plot_state.gd`
- 食物：`food_recipe_data.gd`、`food_production_state.gd`、`expedition_meal_data.gd`
- 锻造：`craft_recipe_definition.gd`、`forge_craft_state.gd`
- 医院：`hospital_project_state.gd`
- 日报：`daily_report.gd`
- 战斗显示：`battle_visual_registry.gd`、`battle_unit_visual_data.gd`

11A特效数据位于 `scripts/battle/effects/`。

## 5. 当前权威规则

### 时间

- 统一最小单位是一天。
- 村庄休整、远征移动和远征采集可以推进一天。
- 打开页面、选择项目、开始制造/治疗、战斗回合不推进日期。
- 每个每日系统在一次 `advance_day()` 中只应调用一次。

### 资源

- 核心资源：粮食、药品、矿石、草药、Boss核心。
- 可堆叠后勤品：远征口粮、丰盛炖汤、猎手烤肉。
- 农田成熟是粮食和草药的正式生产入口。
- 远征行动消耗远征口粮，不直接消耗村庄粮食。
- 药品新增来自医院主动制药，不应由旧两天自动产药逻辑发放。

### 战斗与角色

- BattleSystem是战斗结果唯一权威来源。
- 受伤只降低伤势前最大生命20%，不影响其他属性且不叠加。
- 料理最大生命临时加成在伤势修正之后加入。
- 正常返回按料理清除前的生命比例判伤；失败返回全员受伤。
- 受伤角色可出发；正在医院治疗的角色阻止固定四人队出发。
- 药品只恢复当前战斗生命，不能解除永久伤势。

### 项目与生产

- 食物制造、医院、锻造各自为单槽。
- 启动时立即扣除材料，启动本身不推进时间。
- 每日完成结果只能结算一次。
- 后方完成品进入村庄仓库，不自动加入当前远征背包。

## 6. 测试与验证现状

当前可用冒烟测试：

```text
smoke_stage8_battle.gd
smoke_stage9a_character_data.gd
smoke_stage9a_character_ui.gd
smoke_stage9b_equipment.gd
smoke_stage9c_forge.gd
smoke_stage9d_affixes.gd
smoke_stage10a_buildings.gd
smoke_stage10b_farm.gd
smoke_stage10c_food_workshop.gd
smoke_stage10d_hospital.gd
smoke_stage10e_logistics.gd
smoke_stage11a_battle_effects.gd
```

标准运行方式：

```powershell
tools\godot.bat --headless --path . --script tools\smoke_stage10e_logistics.gd
```

将文件名替换为其他测试即可。本轮最近一次完整回归中，Stage8、Stage9A～9D、Stage10A～10E和11A均通过。

补充检查：

```powershell
tools\godot.bat --headless --editor --path . --quit
git diff --check
```

11A分辨率截图必须使用正常Windows渲染：

```powershell
tools\godot.bat --rendering-method gl_compatibility --path . --script tools\capture_stage11a_resolutions.gd
```

测试注意事项：

- 项目测试普遍使用Godot `assert()`；部分断言失败时进程仍可能返回0，必须同时检查输出中的 `SCRIPT ERROR`、`Assertion failed` 和 `ERROR`。
- `smoke_stage8_battle.gd` 或截图工具退出时可能出现既存 `ObjectDB instances leaked at exit` 提示，尚未完成根因清理。
- 没有覆盖整个项目的单一测试入口；当前需要逐脚本运行。

## 7. 当前Git与工作区状态

当前HEAD只包含到10C。以下内容存在于未提交工作区：

- 10D医院、伤势和治疗。
- 10E统一日报和后勤整合。
- 顶部资源中文乱码修复。
- 11A战斗特效框架。
- 两份Codex交接文档。

当前修改文件还与早期10D/10E改动交织，不能简单按11A文件列表提交全部内容。大量新增文件仍为未跟踪，包括 `assets/art/effect/` 原始图片。

继续工作前必须执行：

```powershell
git status --short
```

禁止未经确认使用：

```text
git reset --hard
git checkout -- <file>
git clean -fd
```

这些命令会破坏尚未提交的10D～11A实现或用户提供的特效素材。

## 8. 已知问题和技术债

### 8.1 未实现的大系统

- 没有正式存档/读档/自动存档。
- 科研所、民居、资源收集所未开放。
- 没有生活角色、岗位、人口或科技树。
- 没有第二区域、多队伍、自动派遣和正式章节推进。
- 火元素Boss只有美术准备，没有遭遇与陨石技能。
- 没有正式音效、镜头震动、闪光和命中停顿。

### 8.2 旧兼容字段和过期文本

`GameState` 仍保留早期 `INITIAL_ADVENTURERS`、`INITIAL_BUILDINGS`、`daily_food_production`、`medicine_progress` 等兼容数据，其中部分中文已乱码。当前正式角色会由CharacterDatabase重建，正式农田/医院产出也由新系统处理，但这些旧字段和文本容易误导维护者。

`ProjectSystem` 中仍有过期描述和兼容效果，例如医院扩建文本写着“每天制作1药品”，但10D之后旧自动产药已停止；农田扩建描述也仍引用旧每日固定产量。应在不改变实际数值规则的前提下做一次专项清理。

`BuildingSystem` 的部分说明仍写着“10B/10C/10D阶段开放”或“功能准备中”，与当前功能状态不一致。实际面板已有覆盖显示，但数据层文本需要更新。

### 8.3 GameState体积

`autoload/game_state.gd` 同时承担状态存储、系统编排、信号转发、日报组装、准备检查和大量查询接口，已经成为高耦合中心。短期应保持测试稳定；中期可以按领域拆分编排器，但必须先补统一测试入口和序列化边界。

### 8.4 UI集中度

`features/village/village_view.gd` 同时包含村庄地图、建筑面板、农田、食物、医院、锻造、角色、装备、后勤和远征准备UI，文件体积很大。后续功能扩展前建议拆成子控件，但不能复制状态或创建第二权威来源。

### 8.5 11A素材与切帧

用户已经确认当前特效切帧不准确。`tools/generate_battle_effect_frames.gd` 中的网格只是初版推断，必须等待用户修正图片或提供正确网格后重新生成。

箭矢、预警圈和命中火花当前包含烘焙棋盘背景，显示层用饱和度Shader临时去除，可能损失低饱和高光。详细问题见 `docs/codex_handoff_11A.md`。

### 8.6 配置与实现不完全一致

- 11A的多个Resource字段目前只是预留，真正命中时机主要使用秒数延迟。
- 特性数据存在但效果未实现。
- `FloatingTextLayer` 已建但浮字仍在单位局部层。
- ARC/BEZIER投射物回退为直线。
- 部分建筑等级字段存在，但正式等级玩法和等级效果未完整实现。

## 9. 推荐后续顺序

### 第一优先：修正11A特效资源

1. 获取用户修正后的序列图或正确切帧参数。
2. 更新 `tools/generate_battle_effect_frames.gd`。
3. 重新生成五个SpriteFrames。
4. 调整特效缩放、持续时间、释放帧、命中延迟和单位锚点。
5. 重跑11A、Stage8和三分辨率截图验收。

### 第二优先：阶段11B角色正式表现

- 守卫近战和盾击命中调优。
- 游侠普通箭矢和强力射击差异化。
- 法师魔法弹与奥术冲击实际命中帧。
- 治疗术和战斗药品恢复时机。
- 将角色级发射点/脚底偏移配置化。

### 第三优先：阶段11C怪物与Boss表现

- 普通怪物投射物。
- 树精地刺最终资源和群体时序。
- 火元素Boss遭遇、陨石预警、坠落和爆炸。

### 第四优先：阶段11D润色

- 音效、镜头、闪光、命中停顿。
- 战斗速度兼容、特效开关、性能和连续战斗验收。

### 后续基础治理

- 清理旧自动产出兼容字段和过期UI说明。
- 建立统一测试运行器，确保断言失败返回非0。
- 定位退出期ObjectDB提示。
- 为当前10D～11A改动整理有意义的提交。
- 在进入更大内容阶段前实现最小存档系统。

## 10. 新线程开始工作的检查清单

1. 完整阅读 `docs/GAME_DESIGN.md`、本文和对应阶段专项交接。
2. 执行 `git status --short`，确认用户未新增或替换素材。
3. 不把设计文档规划误认为已实现功能。
4. 不重做BattleSystem、统一日期、农田、食物、医院、装备和远征稳定逻辑。
5. 所有日期推进继续通过 `GameState.advance_day(reason)`。
6. 所有战斗伤害/治疗继续由BattleSystem结算，表现层只读取结果。
7. UI不得成为新的状态权威来源。
8. 修改特效原图后必须重新生成SpriteFrames。
9. 测试输出要检查错误文本，不能只看退出码。
10. 完成修改后至少运行对应阶段测试、Stage8战斗回归、Stage10E后勤回归和 `git diff --check`。

## 11. 快速启动

在项目根目录运行：

```powershell
tools\godot.bat --editor --path .
```

或直接运行项目：

```powershell
tools\godot.bat --path .
```

Godot主场景和自动加载已经在 `project.godot` 配置。当前游戏可以从新游戏状态进入村庄，准备远征，完成后勤与战斗循环。
