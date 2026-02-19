extends RefCounted
class_name WeaponAffixDefs

# 武器词条库：对应武器专属效果（伤害、射速、穿透等）。
# 升级系统应用时附加到武器，effect_type 映射到武器属性。
# weapon_type: "melee" | "ranged" | "both"。用于 UI 筛选与展示。
const WEAPON_AFFIX_POOL := [
	{"id": "weapon_damage", "visible": true, "effect_type": "damage", "base_value": 3, "weapon_type": "both", "name_key": "upgrade.damage.title", "desc_key": "upgrade.damage.desc"},
	{"id": "weapon_fire_rate", "visible": true, "effect_type": "fire_rate", "base_value": 1, "weapon_type": "both", "name_key": "upgrade.fire_rate.title", "desc_key": "upgrade.fire_rate.desc"},
	{"id": "weapon_melee_range", "visible": true, "effect_type": "attack_range", "base_value": 15, "weapon_type": "melee", "name_key": "weapon_affix.melee_range.name", "desc_key": "weapon_affix.melee_range.desc"},
	{"id": "weapon_bullet_speed", "visible": true, "effect_type": "bullet_speed", "base_value": 60, "weapon_type": "ranged", "name_key": "upgrade.bullet_speed.title", "desc_key": "upgrade.bullet_speed.desc"},
	{"id": "weapon_multi_shot", "visible": true, "effect_type": "multi_shot", "base_value": 1, "weapon_type": "ranged", "name_key": "upgrade.multi_shot.title", "desc_key": "upgrade.multi_shot.desc"},
	{"id": "weapon_pierce", "visible": true, "effect_type": "pierce", "base_value": 1, "weapon_type": "ranged", "name_key": "upgrade.pierce.title", "desc_key": "upgrade.pierce.desc"},
]

# 武器元素词条池：effect_type 为 "element"，武器攻击时对敌人附着对应元素（元素量 1）。
# 与魔法元素命名一致：fire/ice/lightning/poison/physical。
const WEAPON_ELEMENT_AFFIX_POOL := [
	{"id": "weapon_element_fire", "visible": true, "effect_type": "element", "element": "fire", "weapon_type": "both", "name_key": "weapon_affix.element_fire.name", "desc_key": "weapon_affix.element_fire.desc"},
	{"id": "weapon_element_ice", "visible": true, "effect_type": "element", "element": "ice", "weapon_type": "both", "name_key": "weapon_affix.element_ice.name", "desc_key": "weapon_affix.element_ice.desc"},
	{"id": "weapon_element_lightning", "visible": true, "effect_type": "element", "element": "lightning", "weapon_type": "both", "name_key": "weapon_affix.element_lightning.name", "desc_key": "weapon_affix.element_lightning.desc"},
	{"id": "weapon_element_poison", "visible": true, "effect_type": "element", "element": "poison", "weapon_type": "both", "name_key": "weapon_affix.element_poison.name", "desc_key": "weapon_affix.element_poison.desc"},
	{"id": "weapon_element_physical", "visible": true, "effect_type": "element", "element": "physical", "weapon_type": "both", "name_key": "weapon_affix.element_physical.name", "desc_key": "weapon_affix.element_physical.desc"},
]


## 根据 id 获取词条定义（先查数值词条池，再查元素词条池）。
static func get_affix_def(affix_id: String) -> Dictionary:
	for a in WEAPON_AFFIX_POOL:
		if str(a.get("id", "")) == affix_id:
			return a.duplicate(true)
	for a in WEAPON_ELEMENT_AFFIX_POOL:
		if str(a.get("id", "")) == affix_id:
			return a.duplicate(true)
	return {}
