extends CharacterTraitsBase
class_name HeavyGunnerTraits

# HeavyGunner 角色特质：
# - 伤害加成系数 1.1
# - 重锤（hammer_heavy）额外 +5 伤害

func get_damage_multiplier() -> float:
	return 1.1


func get_weapon_damage_bonus(weapon_id: String) -> float:
	if weapon_id == "hammer_heavy":
		return 5.0
	return 0.0
