extends RefCounted
class_name WeaponTypeAffixDefs

# 武器类型词条：刀剑、枪矛、枪械、法杖。
# 无直接属性，仅用于套装计数。套装效果：effect_type + bonus_per_count，2-6 件线性增长。
# 多把同名武器只计 1 次。
const WEAPON_TYPE_AFFIX_POOL := [
	{"id": "type_blade", "name_key": "weapon_type.blade.name", "effect_type": "melee_damage_bonus", "bonus_per_count": 2},
	{"id": "type_spear", "name_key": "weapon_type.spear.name", "effect_type": "melee_damage_bonus", "bonus_per_count": 2},
	{"id": "type_firearm", "name_key": "weapon_type.firearm.name", "effect_type": "ranged_damage_bonus", "bonus_per_count": 2},
	{"id": "type_staff", "name_key": "weapon_type.staff.name", "effect_type": "ranged_damage_bonus", "bonus_per_count": 2},
]


## 根据 id 获取词条定义。
static func get_affix_def(affix_id: String) -> Dictionary:
	for a in WEAPON_TYPE_AFFIX_POOL:
		if str(a.get("id", "")) == affix_id:
			return a.duplicate(true)
	return {}
