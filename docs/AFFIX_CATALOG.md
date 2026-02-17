# 词条图鉴

本文档列出项目中所有词条，按类型分类，供开发与配置参考。词条附着于武器、魔法、道具，用于限定范围与批量应用效果。

---

## 一、道具词条（ItemAffix）

仅作用于道具，通过商店购买获得。效果聚合后应用到玩家属性。

| 词条 ID | 展示名称（zh-CN） | 效果类型 | 基础数值 | 效果说明 |
|---------|-------------------|----------|----------|----------|
| item_max_health | 生命上限提升 | max_health | 20 | 生命上限 +20 |
| item_max_mana | 魔力上限提升 | max_mana | 15 | 魔力上限 +15 |
| item_armor | 护甲提升 | armor | 3 | 护甲 +3，减伤点数 |
| item_speed | 移速提升 | speed | 15 | 移速 +15 |
| item_melee | 近战伤害加成 | melee_damage_bonus | 3 | 近战伤害加成 +3 |
| item_ranged | 远程伤害加成 | ranged_damage_bonus | 3 | 远程伤害加成 +3 |
| item_regen | 生命恢复 | health_regen | 0.8 | 生命恢复 +0.8/秒 |
| item_lifesteal | 吸血 | lifesteal_chance | 0.05 | 吸血概率 +5%（命中时按概率恢复 1 点血） |
| item_mana_regen | 魔力恢复 | mana_regen | 0.5 | 魔力恢复 +0.5/秒（叠加于基准 1.0） |
| item_spell_speed | 施法速度提升 | spell_speed | 0.15 | 施法速度 +0.15（缩短魔法冷却） |

**数据来源**：`resources/item_affix_defs.gd`（ITEM_AFFIX_POOL）

**数值可调节**：词条定义中的 `base_value` 为默认值；绑定时（如 `shop_item_defs` 的 item 中 `base_value`）可指定具体值覆盖，再乘品级倍率。

---

## 二、武器词条（WeaponAffix）

仅作用于武器，通过升级选择获得。效果应用到每把装备武器。

| 词条 ID | 展示名称（zh-CN） | 武器类型 | 效果类型 | 基础数值 | 效果说明 |
|---------|-------------------|----------|----------|----------|----------|
| weapon_damage | 火力 | both | damage | 3 | 武器伤害 +3 |
| weapon_fire_rate | 急速 | both | fire_rate | 1 | 射速提升（冷却缩短） |
| weapon_melee_range | 攻击范围 | melee | attack_range | 15 | 近战攻击距离 +15 |
| weapon_bullet_speed | 弹速 | ranged | bullet_speed | 60 | 子弹飞行速度 +60 |
| weapon_multi_shot | 扩散 | ranged | multi_shot | 1 | 弹丸数 +1 |
| weapon_pierce | 穿透 | ranged | pierce | 1 | 穿透次数 +1（子弹可穿透多个敌人） |

**武器类型**：`melee` 仅近战、`ranged` 仅远程、`both` 近战与远程通用，供 UI 筛选与商店随机词条。

**数据来源**：`resources/weapon_affix_defs.gd`（WEAPON_AFFIX_POOL）

**获取方式**：升级面板选择对应升级项后，加入 `run_weapon_upgrades`；商店武器随机附加 0~2 个词条（`random_affix_ids`），购买时写入 `run_weapons`。

---

## 二b、武器类型词条（WeaponTypeAffix）

固定绑定于武器定义，无直接属性，仅用于套装计数。2-6 件同类生效，线性增长；多把同名武器只计 1 次。

| 词条 ID | 展示名称（zh-CN） | 套装效果类型 | 每件加成 |
|---------|-------------------|--------------|----------|
| type_blade | 刀剑 | melee_damage_bonus | 2 |
| type_spear | 枪矛 | melee_damage_bonus | 2 |
| type_firearm | 枪械 | ranged_damage_bonus | 2 |
| type_staff | 法杖 | ranged_damage_bonus | 2 |

**数据来源**：`resources/weapon_type_affix_defs.gd`（WEAPON_TYPE_AFFIX_POOL）

---

## 二c、武器主题词条（WeaponThemeAffix）

固定绑定于武器定义，无直接属性，仅用于套装计数。2-6 件同类生效，线性增长；多把同名武器只计 1 次。

| 词条 ID | 展示名称（zh-CN） | 套装效果类型 | 每件加成 |
|---------|-------------------|--------------|----------|
| theme_classical | 古典 | armor | 1 |
| theme_modern | 现代 | attack_speed | 0.05 |
| theme_scifi | 科幻 | ranged_damage_bonus | 2 |
| theme_xuanhuan | 玄幻 | max_health | 2 |
| theme_fantasy | 魔幻 | health_regen | 0.1 |

**数据来源**：`resources/weapon_theme_affix_defs.gd`（WEAPON_THEME_AFFIX_POOL）

---

## 三、魔法词条（MagicAffix）

仅作用于魔法。当前词条库已定义，效果应用逻辑待接入。

| 词条 ID | 展示名称（zh-CN） | 效果类型 | 基础数值 | 效果说明 |
|---------|-------------------|----------|----------|----------|
| magic_power_bonus | 魔法威力提升 | power_bonus | 5 | 魔法威力 +5 |
| magic_cooldown_reduce | 魔法冷却缩减 | cooldown_reduce | 0.1 | 魔法冷却缩减 10% |
| magic_burn_extend | 燃烧持续延长 | burn_duration | 1.0 | 燃烧持续时间 +1 秒 |

**数据来源**：`resources/magic_affix_defs.gd`（MAGIC_AFFIX_POOL）

**说明**：魔法品级与施法速度目前由道具词条 `item_spell_speed` 间接影响（玩家 spell_speed 属性缩短魔法冷却）。

---

## 四、词条与物体对应关系

| 物体类型 | 词条来源 | 附着时机 |
|----------|----------|----------|
| 道具 | 商店购买的 attribute 类道具 | 购买时加入 run_items，词条从 shop_item_defs 的 affix_ids 推导 |
| 武器 | 升级选择、商店随机词条、类型/主题固定词条 | run_weapon_upgrades 全局应用；random_affix_ids 每把武器独立；type_affix/theme_affix 套装加成 |
| 魔法 | 定义中 affix_ids（可选）、运行时追加 | 待接入 |

---

## 五、扩展说明

- **新增道具词条**：在 `item_affix_defs.gd` 增加定义，在 `shop_item_defs.gd` 的 item 中增加 `affix_ids`
- **新增武器词条**：在 `weapon_affix_defs.gd` 增加定义，在 `game.gd::WEAPON_UPGRADE_IDS` 与武器 `apply_upgrade` 中接入
- **新增魔法词条**：在 `magic_affix_defs.gd` 增加定义，在魔法实例或 AffixManager 中接入效果应用

详见 [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) 第 5.1b 节。
