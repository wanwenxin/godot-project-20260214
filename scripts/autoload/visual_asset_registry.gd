extends Node

# 统一视觉资源入口：
# - 优先加载真实美术资源
# - 资源缺失时自动回退到生成纹理/色块
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


func has_asset(asset_key: String) -> bool:
	var path := str(TEXTURE_PATHS.get(asset_key, ""))
	return path != "" and ResourceLoader.exists(path)


func get_texture(asset_key: String, fallback_generator: Callable = Callable()) -> Texture2D:
	if _texture_cache.has(asset_key):
		return _texture_cache[asset_key]
	var path := str(TEXTURE_PATHS.get(asset_key, ""))
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
	if COLOR_MAP.has(asset_key):
		return COLOR_MAP[asset_key]
	return fallback_color


func make_color_texture(asset_key: String, fallback_color: Color, size: Vector2i = Vector2i(24, 24)) -> Texture2D:
	return _make_fallback_texture(get_color(asset_key, fallback_color), size)


func _make_fallback_texture(color: Color, size: Vector2i) -> Texture2D:
	var img := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
