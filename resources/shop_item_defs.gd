extends RefCounted
class_name ShopItemDefs

# 商店商品定义：
# - 武器：引用 weapon_defs
# - 道具：attribute（属性增强）、magic（魔法装备）
# - 价格随波次上涨：base_cost * (1 + wave * 0.15)
const WAVE_PRICE_SCALE := 0.15  # 每波涨价 15%

# 道具池：属性增强 + 魔法；固化配置，不随机生成。
# 道具品级固定（tier），魔法品级由购买次数升级。
# attribute 类使用 affix_ids 关联词条，效果由词条系统聚合；保留 attr、base_value 供 UI 展示兼容。
const ITEM_POOL := [
	{"type": "attribute", "id": "item_max_health", "affix_ids": ["item_max_health"], "attr": "max_health", "base_value": 20, "tier": 0, "base_cost": 4, "name_key": "item.max_health.name", "display_name_key": "item.display.max_health", "desc_key": "item.max_health.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_hp.png"},
	{"type": "attribute", "id": "item_max_mana", "affix_ids": ["item_max_mana"], "attr": "max_mana", "base_value": 15, "tier": 0, "base_cost": 3, "name_key": "item.max_mana.name", "display_name_key": "item.display.max_mana", "desc_key": "item.max_mana.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_mana.png"},
	{"type": "attribute", "id": "item_armor", "affix_ids": ["item_armor"], "attr": "armor", "base_value": 3, "tier": 0, "base_cost": 4, "name_key": "item.armor.name", "display_name_key": "item.display.armor", "desc_key": "item.armor.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_armor.png"},
	{"type": "attribute", "id": "item_speed", "affix_ids": ["item_speed"], "attr": "speed", "base_value": 15, "tier": 0, "base_cost": 3, "name_key": "item.speed.name", "display_name_key": "item.display.speed", "desc_key": "item.speed.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_speed.png"},
	{"type": "attribute", "id": "item_melee", "affix_ids": ["item_melee"], "attr": "melee_damage_bonus", "base_value": 3, "tier": 0, "base_cost": 4, "name_key": "item.melee.name", "display_name_key": "item.display.melee", "desc_key": "item.melee.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_melee.png"},
	{"type": "attribute", "id": "item_ranged", "affix_ids": ["item_ranged"], "attr": "ranged_damage_bonus", "base_value": 3, "tier": 0, "base_cost": 4, "name_key": "item.ranged.name", "display_name_key": "item.display.ranged", "desc_key": "item.ranged.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_ranged.png"},
	{"type": "attribute", "id": "item_regen", "affix_ids": ["item_regen"], "attr": "health_regen", "base_value": 0.8, "tier": 0, "base_cost": 5, "name_key": "item.regen.name", "display_name_key": "item.display.regen", "desc_key": "item.regen.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_regen.png"},
	{"type": "attribute", "id": "item_lifesteal", "affix_ids": ["item_lifesteal"], "attr": "lifesteal_chance", "base_value": 0.05, "tier": 0, "base_cost": 6, "name_key": "item.lifesteal.name", "display_name_key": "item.display.lifesteal", "desc_key": "item.lifesteal.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_lifesteal.png"},
	{"type": "attribute", "id": "item_mana_regen", "affix_ids": ["item_mana_regen"], "attr": "mana_regen", "base_value": 0.5, "tier": 0, "base_cost": 4, "name_key": "item.mana_regen.name", "display_name_key": "item.display.mana_regen", "desc_key": "item.mana_regen.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_mana_regen.png"},
	{"type": "magic", "id": "fire_bolt", "base_cost": 6, "name_key": "magic.fire_bolt.name", "desc_key": "magic.fire_bolt.desc", "icon_path": "res://assets/magic/icon_fire.png"},
	{"type": "magic", "id": "ice_shard", "base_cost": 7, "name_key": "magic.ice_shard.name", "desc_key": "magic.ice_shard.desc", "icon_path": "res://assets/magic/icon_ice.png"},
	{"type": "magic", "id": "shockwave", "base_cost": 10, "name_key": "magic.shockwave.name", "desc_key": "magic.shockwave.desc", "icon_path": "res://assets/magic/icon_lightning.png"},
	{"type": "magic", "id": "burn_zone", "base_cost": 12, "name_key": "magic.burn_zone.name", "desc_key": "magic.burn_zone.desc", "icon_path": "res://assets/magic/icon_fire.png"},
	{"type": "attribute", "id": "item_spell_speed", "affix_ids": ["item_spell_speed"], "attr": "spell_speed", "base_value": 0.15, "tier": 0, "base_cost": 5, "name_key": "item.spell_speed.name", "display_name_key": "item.display.spell_speed", "desc_key": "item.spell_speed.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_mana.png"},
]

## 计算商品价格：base_cost * tier_coefficient * wave_coefficient
## tier_coefficient：武器按品级 1+tier*0.2，道具/魔法为 1
## wave_coefficient：1 + wave * 0.15
static func get_price_with_tier(base_cost: int, tier: int, wave: int) -> int:
	var tier_coef: float = 1.0 + maxi(0, tier) * 0.2 if tier > 0 else 1.0
	var wave_coef: float = 1.0 + float(wave) * WAVE_PRICE_SCALE
	return maxi(1, int(float(base_cost) * tier_coef * wave_coef))


## 兼容旧接口：无 tier 时按 tier=0 计算（道具/魔法）
static func get_price(base_cost: int, wave: int) -> int:
	return get_price_with_tier(base_cost, 0, wave)
