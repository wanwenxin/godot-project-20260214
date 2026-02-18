extends RefCounted
class_name MagicAffixDefs

# 魔法词条库：三类固定词条（范围、效果、元素），每魔法各 1 个。
# 范围：射程直线/鼠标圆心/角色圆心；效果：持续伤害/一次伤害/吸引排斥；元素：火冰物理雷毒。

const RANGE_AFFIX_POOL := [
	{"id": "magic_range_line", "category": "range", "name_key": "magic_affix.range_line.name", "desc_key": "magic_affix.range_line.desc", "value_key": "size", "value_default": 40.0, "range_type": "line"},
	{"id": "magic_range_mouse_circle", "category": "range", "name_key": "magic_affix.range_mouse_circle.name", "desc_key": "magic_affix.range_mouse_circle.desc", "value_key": "radius", "value_default": 80.0, "range_type": "mouse_circle"},
	{"id": "magic_range_char_circle", "category": "range", "name_key": "magic_affix.range_char_circle.name", "desc_key": "magic_affix.range_char_circle.desc", "value_key": "radius", "value_default": 100.0, "range_type": "char_circle"},
]

const EFFECT_AFFIX_POOL := [
	{"id": "magic_effect_dot", "category": "effect", "name_key": "magic_affix.effect_dot.name", "desc_key": "magic_affix.effect_dot.desc", "effect_type": "burn", "burn_duration": 4.0, "burn_damage_per_tick": 8, "burn_interval": 0.5},
	{"id": "magic_effect_instant", "category": "effect", "name_key": "magic_affix.effect_instant.name", "desc_key": "magic_affix.effect_instant.desc", "effect_type": "shockwave"},
	{"id": "magic_effect_pull_line", "category": "effect", "name_key": "magic_affix.effect_pull_line.name", "desc_key": "magic_affix.effect_pull_line.desc", "effect_type": "pull_line"},
	{"id": "magic_effect_push_line", "category": "effect", "name_key": "magic_affix.effect_push_line.name", "desc_key": "magic_affix.effect_push_line.desc", "effect_type": "push_line"},
	{"id": "magic_effect_pull_circle", "category": "effect", "name_key": "magic_affix.effect_pull_circle.name", "desc_key": "magic_affix.effect_pull_circle.desc", "effect_type": "pull_circle"},
	{"id": "magic_effect_push_circle", "category": "effect", "name_key": "magic_affix.effect_push_circle.name", "desc_key": "magic_affix.effect_push_circle.desc", "effect_type": "push_circle"},
]

const ELEMENT_AFFIX_POOL := [
	{"id": "magic_element_fire", "category": "element", "name_key": "magic_affix.element_fire.name", "desc_key": "magic_affix.element_fire.desc", "element": "fire"},
	{"id": "magic_element_ice", "category": "element", "name_key": "magic_affix.element_ice.name", "desc_key": "magic_affix.element_ice.desc", "element": "ice"},
	{"id": "magic_element_physical", "category": "element", "name_key": "magic_affix.element_physical.name", "desc_key": "magic_affix.element_physical.desc", "element": "physical"},
	{"id": "magic_element_lightning", "category": "element", "name_key": "magic_affix.element_lightning.name", "desc_key": "magic_affix.element_lightning.desc", "element": "lightning"},
	{"id": "magic_element_poison", "category": "element", "name_key": "magic_affix.element_poison.name", "desc_key": "magic_affix.element_poison.desc", "element": "poison"},
]

## 合并池，供 get_affix_def 查找
static func _get_all_pool() -> Array:
	var all: Array = []
	all.append_array(RANGE_AFFIX_POOL)
	all.append_array(EFFECT_AFFIX_POOL)
	all.append_array(ELEMENT_AFFIX_POOL)
	return all


## 根据 id 获取词条定义。
static func get_affix_def(affix_id: String) -> Dictionary:
	for a in _get_all_pool():
		if str(a.get("id", "")) == affix_id:
			return a.duplicate(true)
	return {}


## 按类别获取词条列表。
static func get_affixes_by_category(category: String) -> Array:
	var pool: Array = []
	match category:
		"range":
			pool = RANGE_AFFIX_POOL.duplicate()
		"effect":
			pool = EFFECT_AFFIX_POOL.duplicate()
		"element":
			pool = ELEMENT_AFFIX_POOL.duplicate()
	return pool
