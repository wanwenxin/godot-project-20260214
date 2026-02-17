extends Resource
class_name CharacterTraitsBase

# 角色特质基类（抽象）：
# - 定义默认属性与数值计算虚方法
# - 子类可重写以实现属性加成、元素附魔、武器专属加成等
# - 供 Player 持有，武器/子弹通过 Player 调用参与伤害计算

## 伤害加成系数，默认 1.0，子类可返回 1.2 等
func get_damage_multiplier() -> float:
	return 1.0


## 元素附魔类型，默认空字符串，子类可返回 "fire" 等
func get_elemental_enchantment() -> String:
	return ""


## 指定武器的额外伤害加成，默认 0；子类可重写并利用 _weapon_id 做武器专属加成
func get_weapon_damage_bonus(_weapon_id: String) -> float:
	return 0.0


## 移速加成系数，默认 1.0
func get_speed_multiplier() -> float:
	return 1.0


## 最大生命加成系数，默认 1.0
func get_max_health_multiplier() -> float:
	return 1.0


## 获取最终伤害（供武器/子弹调用）
## base_damage: 武器基础伤害
## weapon_id: 武器 id，用于武器专属加成
## _context: 扩展上下文，可传 attack_type、is_melee 等，子类重写时可使用
func get_final_damage(base_damage: int, weapon_id: String, _context: Dictionary = {}) -> int:
	var mult := get_damage_multiplier()
	var bonus := get_weapon_damage_bonus(weapon_id)
	return maxi(1, int(float(base_damage) * mult + bonus))
