# 《冒险村》临时战斗音效候选

更新时间：2026-07-22

## 筛选结论

- 已核验 Kenney 官方的 Impact Sounds、RPG Audio、Digital Audio、UI Audio，四个资源包的官方页面及包内 `License.txt` 均标明 Creative Commons Zero（CC0 1.0）。
- 已核验两个 Freesound 弓箭候选的独立页面，页面均标明 CC0；但Freesound原始文件下载需要登录，因此本次没有接入，也没有使用预览音频代替。
- 本轮正式接入的18个临时音效全部来自Kenney官方CC0原包。游戏文件是源OGG的原样副本，只统一重命名并通过注册表调节播放音量，未二次有损转码。
- 所有Kenney资源均不强制署名，但项目仍在 `THIRD_PARTY_AUDIO_LICENSES.md` 中保留来源记录。

## 候选明细

表中的“接入”表示本轮已复制到游戏目录并注册；“备选”表示已下载在原始包中但未注册；“未来优先”表示许可证合格，但原始下载受登录限制。

| sound_id | 原始文件名 | 来源网站 / 页面 | 作者 | 许可证 | 署名 | 下载日期 | 时长 | 格式 | 推荐理由 | 建议 |
|---|---|---|---|---|---|---|---:|---|---|---|
| `melee_swing` | `knifeSlice.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.600秒 | OGG | 短促切风感，适合卡通近战挥击 | 接入 |
| `melee_swing` | `knifeSlice2.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.569秒 | OGG | 同风格变体，可用于后续随机化 | 备选 |
| `light_impact` | `impactGeneric_light_000.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.139秒 | OGG | 非材质化、短促，不会抢过普通攻击 | 接入 |
| `light_impact` | `impactGeneric_light_001.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.118秒 | OGG | 更短的普通命中变体 | 备选 |
| `heavy_impact` | `impactPunch_heavy_000.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.649秒 | OGG | 厚重但不恐怖，适合盾击和强力射击 | 接入 |
| `heavy_impact` | `impactMetal_heavy_000.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.168秒 | OGG | 金属感更强，可用于后续盾牌专用音 | 备选 |
| `arrow_release` | `Bow_release.wav` | Freesound / [263675](https://freesound.org/people/PorkMuncher/sounds/263675/) | PorkMuncher | CC0 1.0 | 不需要 | 未下载（需登录） | 1.053秒 | WAV 16-bit mono | 语义最准确，后续有账号时优先替换 | 未来优先 |
| `arrow_release` | `knifeSlice2.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.569秒 | OGG | 短促切风，可作为离弦临时占位且风格统一 | 接入（临时） |
| `arrow_impact` | `Arrow_Hit_1` | Freesound / [708223](https://freesound.org/people/Mythmazter/sounds/708223/) | Mythmazter | CC0 1.0 | 不需要 | 未下载（需登录） | 1.815秒 | WAV 24-bit stereo | 真实箭矢入靶，后续可裁切后替换 | 未来优先 |
| `arrow_impact` | `impactWood_light_000.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.266秒 | OGG | 轻木质瞬态，能和通用命中区分 | 接入 |
| `magic_cast` | `phaserUp1.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.496秒 | OGG | 上扬电子音，适合魔法弹释放 | 接入 |
| `magic_cast` | `phaserUp2.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.418秒 | OGG | 更紧凑的施法变体 | 备选 |
| `magic_impact` | `zap1.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.019秒 | OGG | 有明确能量释放尾音，区别于物理命中 | 接入 |
| `magic_impact` | `laser1.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.100秒 | OGG | 更尖锐的能量命中备选 | 备选 |
| `arcane_burst` | `spaceTrash1.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.451秒 | OGG | 具有更宽的电子爆裂质感，适合群体奥术爆炸 | 接入 |
| `arcane_burst` | `spaceTrash2.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.475秒 | OGG | 同系列群体技能变体 | 备选 |
| `heal` | `powerUp3.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.149秒 | OGG | 正向上升音型，与绿色治疗反馈协调 | 接入 |
| `heal` | `powerUp1.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.202秒 | OGG | 稍长的治疗/强化备选 | 备选 |
| `defend` | `metalLatch.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.261秒 | OGG | 清晰金属锁定感，适合盾牌进入防御 | 接入 |
| `defend` | `metalClick.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.446秒 | OGG | 更轻的装备确认音 | 备选 |
| `medicine` | `handleSmallLeather2.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.307秒 | OGG | 轻量物品处理声，不含吞咽或人声 | 接入 |
| `medicine` | `handleSmallLeather.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.338秒 | OGG | 同类物品使用变体 | 备选 |
| `monster_cast` | `lowRandom.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.549秒 | OGG | 低沉但仍卡通，和玩家法师施法区分 | 接入 |
| `monster_cast` | `laser2.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.091秒 | OGG | 更明显的远程能量攻击备选 | 备选 |
| `earth_spike` | `impactMining_000.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.937秒 | OGG | 石质开凿冲击，适合地刺破土 | 接入 |
| `earth_spike` | `impactMining_001.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.869秒 | OGG | 同系列地刺变体 | 备选 |
| `unit_hit` | `impactPunch_medium_000.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.431秒 | OGG | 中等软冲击，适用于角色和怪物受击 | 接入 |
| `unit_hit` | `impactSoft_medium_000.ogg` | Kenney / [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.118秒 | OGG | 更轻、更不抢主命中音 | 备选 |
| `unit_death` | `lowDown.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.784秒 | OGG | 下降式失败提示，不含人声或恐怖元素 | 接入 |
| `unit_death` | `dropLeather.ogg` | Kenney / [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.415秒 | OGG | 更自然的倒地质感备选 | 备选 |
| `battle_victory` | `threeTone1.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.827秒 | OGG | 三音正向提示，短而清晰 | 接入 |
| `battle_victory` | `highUp.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.549秒 | OGG | 更简短的胜利提示备选 | 备选 |
| `battle_defeat` | `lowThreeTone.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 1.019秒 | OGG | 低音三段式结束提示，不含惊吓元素 | 接入 |
| `battle_defeat` | `highDown.ogg` | Kenney / [Digital Audio](https://kenney.nl/assets/digital-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.522秒 | OGG | 更轻的失败提示备选 | 备选 |
| `ui_click` | `click2.ogg` | Kenney / [UI Audio](https://kenney.nl/assets/ui-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.056秒 | OGG | 极短、干净，适合连续战斗按钮操作 | 接入 |
| `ui_click` | `click1.ogg` | Kenney / [UI Audio](https://kenney.nl/assets/ui-audio) | Kenney | CC0 1.0 | 不需要 | 2026-07-22 | 0.094秒 | OGG | 稍明显的按钮点击变体 | 备选 |

## Freesound下载说明

Freesound候选的页面、作者、时长、格式和CC0许可已经逐项核验。2026-07-22尝试访问页面提供的原始下载地址时，未登录请求返回登录HTML而不是音频数据；这些无效响应已删除。项目没有使用Freesound预览文件，也没有伪造原始音频。

