extends RefCounted
class_name UpgradeDefs

# 升级项统一配置：
# - 对应新属性（max_health, max_mana, armor 等）
# - 奖励点数公式：base_value + level * scale
# - 每项配置 icon_path，低解耦
const UPGRADE_POOL := [
	{"id": "max_health", "title_key": "upgrade.max_health.title", "desc_key": "upgrade.max_health.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_hp.png", "base_value": 15, "level_scale": 2.0},
	{"id": "max_mana", "title_key": "upgrade.max_mana.title", "desc_key": "upgrade.max_mana.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_mana.png", "base_value": 8, "level_scale": 1.5},
	{"id": "armor", "title_key": "upgrade.armor.title", "desc_key": "upgrade.armor.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_armor.png", "base_value": 2, "level_scale": 0.5},
	{"id": "speed", "title_key": "upgrade.speed.title", "desc_key": "upgrade.speed.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_speed.png", "base_value": 12, "level_scale": 2.0},
	{"id": "melee_damage", "title_key": "upgrade.melee_damage.title", "desc_key": "upgrade.melee_damage.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_melee.png", "base_value": 2, "level_scale": 0.5},
	{"id": "ranged_damage", "title_key": "upgrade.ranged_damage.title", "desc_key": "upgrade.ranged_damage.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_ranged.png", "base_value": 2, "level_scale": 0.5},
	{"id": "health_regen", "title_key": "upgrade.health_regen.title", "desc_key": "upgrade.health_regen.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_regen.png", "base_value": 0.5, "level_scale": 0.15},
	{"id": "lifesteal_chance", "title_key": "upgrade.lifesteal.title", "desc_key": "upgrade.lifesteal.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_lifesteal.png", "base_value": 0.03, "level_scale": 0.01},
	{"id": "mana_regen", "title_key": "upgrade.mana_regen.title", "desc_key": "upgrade.mana_regen.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_mana_regen.png", "base_value": 0.3, "level_scale": 0.08},
	{"id": "attack_speed", "title_key": "upgrade.attack_speed.title", "desc_key": "upgrade.attack_speed.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_ranged.png", "base_value": 0.1, "level_scale": 0.02},
	{"id": "damage", "title_key": "upgrade.damage.title", "desc_key": "upgrade.damage.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_melee.png", "base_value": 2, "level_scale": 0.5},
	{"id": "fire_rate", "title_key": "upgrade.fire_rate.title", "desc_key": "upgrade.fire_rate.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_ranged.png", "base_value": 1, "level_scale": 0},
	{"id": "bullet_speed", "title_key": "upgrade.bullet_speed.title", "desc_key": "upgrade.bullet_speed.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_ranged.png", "base_value": 60, "level_scale": 5.0},
	{"id": "multi_shot", "title_key": "upgrade.multi_shot.title", "desc_key": "upgrade.multi_shot.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_ranged.png", "base_value": 1, "level_scale": 0},
	{"id": "pierce", "title_key": "upgrade.pierce.title", "desc_key": "upgrade.pierce.desc", "icon_path": "res://assets/ui/upgrade_icons/icon_ranged.png", "base_value": 1, "level_scale": 0},
]


## 根据等级计算奖励数值；对浮点类（regen、lifesteal）返回 float，整型返回 int。
static func get_reward_value(upgrade: Dictionary, level: int) -> Variant:
	var base_val = upgrade.get("base_value", 0)
	var scale_val = float(upgrade.get("level_scale", 0.0))
	var raw: float = float(base_val) + float(level) * scale_val
	var id := str(upgrade.get("id", ""))
	# 浮点类属性
	if id in ["health_regen", "lifesteal_chance", "mana_regen", "attack_speed"]:
		return raw
	return int(round(raw))
