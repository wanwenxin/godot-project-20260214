extends Resource

# 纹理路径统一配置：在 Inspector 或 .tres 中配置人物、敌人、武器等美术资源路径。
# 供 VisualAssetRegistry 读取，若未配置则使用内置 TEXTURE_PATHS 默认值。
@export_group("Player")
@export_file("*.png") var player_scheme_0: String = "res://assets/characters/player_scheme_0.png"
@export_file("*.png") var player_scheme_1: String = "res://assets/characters/player_scheme_1.png"
@export_file("*.png") var player_scheme_0_sheet: String = "res://assets/characters/player_scheme_0_sheet.png"
@export_file("*.png") var player_scheme_1_sheet: String = "res://assets/characters/player_scheme_1_sheet.png"

@export_group("Enemies")
@export_file("*.png") var enemy_melee: String = "res://assets/enemies/enemy_melee.png"
@export_file("*.png") var enemy_melee_sheet: String = "res://assets/enemies/enemy_melee_sheet.png"
@export_file("*.png") var enemy_ranged: String = "res://assets/enemies/enemy_ranged.png"
@export_file("*.png") var enemy_ranged_sheet: String = "res://assets/enemies/enemy_ranged_sheet.png"
@export_file("*.png") var enemy_tank: String = "res://assets/enemies/enemy_tank.png"
@export_file("*.png") var enemy_tank_sheet: String = "res://assets/enemies/enemy_tank_sheet.png"
@export_file("*.png") var enemy_boss: String = "res://assets/enemies/enemy_boss.png"
@export_file("*.png") var enemy_boss_sheet: String = "res://assets/enemies/enemy_boss_sheet.png"
@export_file("*.png") var enemy_aquatic: String = "res://assets/enemies/enemy_aquatic.png"
@export_file("*.png") var enemy_aquatic_sheet: String = "res://assets/enemies/enemy_aquatic_sheet.png"
@export_file("*.png") var enemy_dasher: String = "res://assets/enemies/enemy_dasher.png"
@export_file("*.png") var enemy_dasher_sheet: String = "res://assets/enemies/enemy_dasher_sheet.png"

@export_group("Weapon Icons")
@export_file("*.png") var weapon_blade_short: String = "res://assets/weapons/blade_short.png"
@export_file("*.png") var weapon_dagger: String = "res://assets/weapons/dagger.png"
@export_file("*.png") var weapon_spear: String = "res://assets/weapons/spear.png"
@export_file("*.png") var weapon_chainsaw: String = "res://assets/weapons/chainsaw.png"
@export_file("*.png") var melee_swing_blade_short: String = "res://assets/weapons/swing_blade_short.png"
@export_file("*.png") var weapon_hammer_heavy: String = "res://assets/weapons/hammer_heavy.png"
@export_file("*.png") var melee_swing_hammer_heavy: String = "res://assets/weapons/swing_hammer_heavy.png"
@export_file("*.png") var melee_swing_dagger: String = "res://assets/weapons/swing_dagger.png"
@export_file("*.png") var melee_swing_spear: String = "res://assets/weapons/swing_spear.png"
@export_file("*.png") var melee_swing_chainsaw: String = "res://assets/weapons/swing_chainsaw.png"
@export_file("*.png") var weapon_pistol_basic: String = "res://assets/weapons/pistol_basic.png"
@export_file("*.png") var weapon_shotgun_wide: String = "res://assets/weapons/shotgun_wide.png"
@export_file("*.png") var weapon_rifle_long: String = "res://assets/weapons/rifle_long.png"
@export_file("*.png") var weapon_wand_focus: String = "res://assets/weapons/wand_focus.png"
@export_file("*.png") var weapon_sniper: String = "res://assets/weapons/sniper.png"
@export_file("*.png") var weapon_orb_wand: String = "res://assets/weapons/orb_wand.png"

@export_group("Other")
@export_file("*.png") var bullet_player: String = "res://assets/bullets/player_bullet.png"
@export_file("*.png") var bullet_enemy: String = "res://assets/bullets/enemy_bullet.png"
@export_file("*.png") var bullet_firearm: String = "res://assets/bullets/bullet_firearm.png"
@export_file("*.png") var bullet_laser: String = "res://assets/bullets/bullet_laser.png"
@export_file("*.png") var bullet_orb: String = "res://assets/bullets/bullet_orb.png"
@export_file("*.png") var pickup_coin: String = "res://assets/pickups/coin.png"
@export_file("*.png") var pickup_heal: String = "res://assets/pickups/heal.png"
