# 词条图鉴

本文档列出项目中所有词条，按类型分类，供开发与配置参考。词条附着于武器、魔法、道具，用于限定范围与批量应用效果。

---

## 一、道具词条（ItemAffix）

仅作用于道具，通过商店购买获得。效果聚合后应用到玩家属性。

| 词条 ID | 展示名称（zh-CN） | 效果类型 | 基础数值 | 效果说明 |
|---------|-------------------|----------|----------|----------|
| item_max_health | 生命药水 | max_health | 20 | 生命上限 +20 |
| item_max_mana | 魔力药水 | max_mana | 15 | 魔力上限 +15 |
| item_armor | 护甲片 | armor | 3 | 护甲 +3，减伤点数 |
| item_speed | 疾风靴 | speed | 15 | 移速 +15 |
| item_melee | 近战符文 | melee_damage_bonus | 3 | 近战伤害加成 +3 |
| item_ranged | 远程符文 | ranged_damage_bonus | 3 | 远程伤害加成 +3 |
| item_regen | 恢复护符 | health_regen | 0.8 | 生命恢复 +0.8/秒 |
| item_lifesteal | 吸血护符 | lifesteal_chance | 0.05 | 吸血概率 +5%（命中时按概率恢复 1 点血） |
| item_mana_regen | 回魔护符 | mana_regen | 0.5 | 魔力恢复 +0.5/秒（叠加于基准 1.0） |
| item_spell_speed | 施法护符 | spell_speed | 0.15 | 施法速度 +0.15（缩短魔法冷却） |

**数据来源**：`resources/item_affix_defs.gd`（ITEM_AFFIX_POOL）

---

## 二、武器词条（WeaponAffix）

仅作用于武器，通过升级选择获得。效果应用到每把装备武器。

| 词条 ID | 展示名称（zh-CN） | 效果类型 | 基础数值 | 效果说明 |
|---------|-------------------|----------|----------|----------|
| weapon_damage | 火力 | damage | 3 | 武器伤害 +3 |
| weapon_fire_rate | 急速 | fire_rate | 1 | 射速提升（冷却缩短） |
| weapon_bullet_speed | 弹速 | bullet_speed | 60 | 子弹飞行速度 +60 |
| weapon_multi_shot | 扩散 | multi_shot | 1 | 弹丸数 +1 |
| weapon_pierce | 穿透 | pierce | 1 | 穿透次数 +1（子弹可穿透多个敌人） |

**数据来源**：`resources/weapon_affix_defs.gd`（WEAPON_AFFIX_POOL）

**获取方式**：升级面板选择对应升级项后，加入 `run_weapon_upgrades`，同步武器时应用到每把武器。

---

## 三、魔法词条（MagicAffix）

仅作用于魔法。当前词条库已定义，效果应用逻辑待接入。

| 词条 ID | 效果类型 | 基础数值 | 效果说明 |
|---------|----------|----------|----------|
| magic_power_bonus | power_bonus | 5 | 魔法威力 +5 |
| magic_cooldown_reduce | cooldown_reduce | 0.1 | 魔法冷却缩减 10% |
| magic_burn_extend | burn_duration | 1.0 | 燃烧持续时间 +1 秒 |

**数据来源**：`resources/magic_affix_defs.gd`（MAGIC_AFFIX_POOL）

**说明**：魔法品级与施法速度目前由道具词条 `item_spell_speed` 间接影响（玩家 spell_speed 属性缩短魔法冷却）。

---

## 四、词条与物体对应关系

| 物体类型 | 词条来源 | 附着时机 |
|----------|----------|----------|
| 道具 | 商店购买的 attribute 类道具 | 购买时加入 run_items，词条从 shop_item_defs 的 affix_ids 推导 |
| 武器 | 升级选择（fire_rate、bullet_speed、multi_shot、pierce） | 选择时加入 run_weapon_upgrades，同步武器时应用 |
| 魔法 | 定义中 affix_ids（可选）、运行时追加 | 待接入 |

---

## 五、扩展说明

- **新增道具词条**：在 `item_affix_defs.gd` 增加定义，在 `shop_item_defs.gd` 的 item 中增加 `affix_ids`
- **新增武器词条**：在 `weapon_affix_defs.gd` 增加定义，在 `game.gd::WEAPON_UPGRADE_IDS` 与武器 `apply_upgrade` 中接入
- **新增魔法词条**：在 `magic_affix_defs.gd` 增加定义，在魔法实例或 AffixManager 中接入效果应用

详见 [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) 第 5.1b 节。
