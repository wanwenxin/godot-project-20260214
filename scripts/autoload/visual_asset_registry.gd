extends Node

# 统一视觉资源入口：
# - 地形色块：优先从 terrain_colors.tres 读取
# - 纹理：优先从 texture_paths.tres 读取，可在 Inspector 配置人物/敌人/武器等美术资源
const TERRAIN_COLOR_CONFIG_PATH := "res://resources/terrain_colors.tres"
const TEXTURE_PATH_CONFIG_PATH := "res://resources/texture_paths.tres"
const TEXTURE_PATHS := {
	"player.scheme_0": "res://assets/characters/player_scheme_0.png",
	"player.scheme_1": "res://assets/characters/player_scheme_1.png",
	"enemy.melee": "res://assets/enemies/enemy_melee.png",
	"enemy.ranged": "res://assets/enemies/enemy_ranged.png",
	"enemy.tank": "res://assets/enemies/enemy_tank.png",
	"enemy.boss": "res://assets/enemies/enemy_boss.png",
	"bullet.player": "res://assets/bullets/player_bullet.png",
	"bullet.enemy": "res://assets/bullets/enemy_bullet.png",
	"pickup.coin": "res://assets/pickups/coin.png",
	"pickup.heal": "res://assets/pickups/heal.png",
	"weapon.icon.blade_short": "res://assets/weapons/blade_short.png",
	"weapon.icon.hammer_heavy": "res://assets/weapons/hammer_heavy.png",
	"weapon.icon.pistol_basic": "res://assets/weapons/pistol_basic.png",
	"weapon.icon.shotgun_wide": "res://assets/weapons/shotgun_wide.png",
	"weapon.icon.rifle_long": "res://assets/weapons/rifle_long.png",
	"weapon.icon.wand_focus": "res://assets/weapons/wand_focus.png"
}

const COLOR_MAP := {
	"terrain.floor_a": Color(0.78, 0.78, 0.80, 1.0),
	"terrain.floor_b": Color(0.72, 0.72, 0.74, 1.0),
	"terrain.boundary": Color(0.33, 0.33, 0.35, 1.0),
	"terrain.obstacle": Color(0.16, 0.16, 0.20, 1.0),
	"terrain.grass": Color(0.20, 0.45, 0.18, 0.45),
	"terrain.shallow_water": Color(0.24, 0.55, 0.80, 0.48),
	"terrain.deep_water": Color(0.08, 0.20, 0.42, 0.56),
	"ui.modal_backdrop": Color(0.08, 0.09, 0.11, 1.0),
	"ui.modal_panel_bg": Color(0.16, 0.17, 0.20, 1.0),
	"ui.modal_panel_border": Color(0.82, 0.84, 0.90, 1.0)
}

var _texture_cache: Dictionary = {}
# 地形色块统一配置，从 TERRAIN_COLOR_CONFIG_PATH 加载，可在 Inspector 覆盖。
var _terrain_config: Resource = null
# 纹理路径统一配置，从 TEXTURE_PATH_CONFIG_PATH 加载，人物/敌人/武器等美术可配置。
var _texture_path_config: Resource = null
const _TERRAIN_KEY_TO_PROPERTY := {
	"terrain.floor_a": "floor_a",
	"terrain.floor_b": "floor_b",
	"terrain.boundary": "boundary",
	"terrain.obstacle": "obstacle",
	"terrain.grass": "grass",
	"terrain.shallow_water": "shallow_water",
	"terrain.deep_water": "deep_water"
}
const _TEXTURE_KEY_TO_PROPERTY := {
	"player.scheme_0": "player_scheme_0",
	"player.scheme_1": "player_scheme_1",
	"enemy.melee": "enemy_melee",
	"enemy.ranged": "enemy_ranged",
	"enemy.tank": "enemy_tank",
	"enemy.boss": "enemy_boss",
	"weapon.icon.blade_short": "weapon_blade_short",
	"weapon.icon.hammer_heavy": "weapon_hammer_heavy",
	"weapon.icon.pistol_basic": "weapon_pistol_basic",
	"weapon.icon.shotgun_wide": "weapon_shotgun_wide",
	"weapon.icon.rifle_long": "weapon_rifle_long",
	"weapon.icon.wand_focus": "weapon_wand_focus",
	"bullet.player": "bullet_player",
	"bullet.enemy": "bullet_enemy",
	"pickup.coin": "pickup_coin",
	"pickup.heal": "pickup_heal"
}


func _ready() -> void:
	if ResourceLoader.exists(TERRAIN_COLOR_CONFIG_PATH):
		_terrain_config = load(TERRAIN_COLOR_CONFIG_PATH) as Resource
	if ResourceLoader.exists(TEXTURE_PATH_CONFIG_PATH):
		_texture_path_config = load(TEXTURE_PATH_CONFIG_PATH) as Resource


func has_asset(asset_key: String) -> bool:
	var path := _get_texture_path(asset_key)
	return path != "" and ResourceLoader.exists(path)


func _get_texture_path(asset_key: String) -> String:
	# 优先从 texture_paths.tres 读取，否则回退到 TEXTURE_PATHS。
	if _texture_path_config:
		var prop: String = ""
		if _TEXTURE_KEY_TO_PROPERTY.has(asset_key):
			prop = _TEXTURE_KEY_TO_PROPERTY[asset_key]
		elif asset_key.begins_with("weapon.icon."):
			prop = "weapon_" + asset_key.trim_prefix("weapon.icon.")
		if prop != "":
			var val = _texture_path_config.get(prop)
			var p := str(val) if val else ""
			if p != "":
				return p
	return str(TEXTURE_PATHS.get(asset_key, ""))


func get_texture(asset_key: String, fallback_generator: Callable = Callable()) -> Texture2D:
	if _texture_cache.has(asset_key):
		return _texture_cache[asset_key]
	var path := _get_texture_path(asset_key)
	if path != "" and ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			_texture_cache[asset_key] = loaded
			return loaded
	if fallback_generator.is_valid():
		var fallback = fallback_generator.call()
		if fallback is Texture2D:
			return fallback
	return _make_fallback_texture(Color(0.9, 0.2, 0.2, 1.0), Vector2i(24, 24))


func get_color(asset_key: String, fallback_color: Color) -> Color:
	# 地形色块优先从统一配置入口（terrain_colors.tres）读取。
	if _terrain_config and _TERRAIN_KEY_TO_PROPERTY.has(asset_key):
		return _terrain_config.get(_TERRAIN_KEY_TO_PROPERTY[asset_key])
	if COLOR_MAP.has(asset_key):
		return COLOR_MAP[asset_key]
	return fallback_color


func make_color_texture(asset_key: String, fallback_color: Color, size: Vector2i = Vector2i(24, 24)) -> Texture2D:
	return _make_fallback_texture(get_color(asset_key, fallback_color), size)


func _make_fallback_texture(color: Color, size: Vector2i) -> Texture2D:
	var img := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
