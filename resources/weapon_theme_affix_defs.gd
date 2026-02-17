extends RefCounted
class_name WeaponThemeAffixDefs

# 武器主题词条：古典、现代、科幻、玄幻、魔幻。
# 无直接属性，仅用于套装计数。套装效果：effect_type + bonus_per_count，2-6 件线性增长。
# 多把同名武器只计 1 次。
const WEAPON_THEME_AFFIX_POOL := [
	{"id": "theme_classical", "name_key": "weapon_theme.classical.name", "effect_type": "armor", "bonus_per_count": 1},
	{"id": "theme_modern", "name_key": "weapon_theme.modern.name", "effect_type": "attack_speed", "bonus_per_count": 0.05},
	{"id": "theme_scifi", "name_key": "weapon_theme.scifi.name", "effect_type": "ranged_damage_bonus", "bonus_per_count": 2},
	{"id": "theme_xuanhuan", "name_key": "weapon_theme.xuanhuan.name", "effect_type": "max_health", "bonus_per_count": 2},
	{"id": "theme_fantasy", "name_key": "weapon_theme.fantasy.name", "effect_type": "health_regen", "bonus_per_count": 0.1},
]


## 根据 id 获取词条定义。
static func get_affix_def(affix_id: String) -> Dictionary:
	for a in WEAPON_THEME_AFFIX_POOL:
		if str(a.get("id", "")) == affix_id:
			return a.duplicate(true)
	return {}
