extends SceneTree

# 独立运行导出像素美术资源：godot -s res://scripts/tools/export_pixel_assets_standalone.gd

func _init() -> void:
	_export_all()
	quit()


func _export_all() -> void:
	var base := "res://assets"
	_ensure_dirs(base)
	_export_characters(base)
	_export_enemies(base)
	_export_weapons(base)
	_export_bullets(base)
	_export_pickups(base)
	print("Pixel assets exported to %s" % base)


func _ensure_dirs(base: String) -> void:
	var dirs := ["characters", "enemies", "weapons", "bullets", "pickups"]
	for d in dirs:
		var path := base.path_join(d)
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)


func _tex_to_png(tex: Texture2D, path: String) -> void:
	if tex is ImageTexture:
		var img: Image = (tex as ImageTexture).get_image()
		if img:
			img.save_png(path)
			print("  Saved: %s" % path)


func _export_characters(base: String) -> void:
	for i in range(2):
		var tex := PixelGenerator.generate_player_sprite(i)
		var name := "player_scheme_%d.png" % i
		_tex_to_png(tex, base.path_join("characters").path_join(name))


func _export_enemies(base: String) -> void:
	var names := ["enemy_melee", "enemy_ranged", "enemy_tank", "enemy_boss", "enemy_aquatic", "enemy_dasher"]
	var types := [0, 1, 2, 3, 4, 5]
	for i in range(types.size()):
		var tex := PixelGenerator.generate_enemy_sprite(types[i])
		_tex_to_png(tex, base.path_join("enemies").path_join(names[i] + ".png"))


func _export_weapons(base: String) -> void:
	var defs := WeaponDefs.WEAPON_DEFS
	for def in defs:
		var id: String = def.get("id", "")
		var color: Color = def.get("color", Color.WHITE)
		var tex := _generate_weapon_icon(id, color)
		_tex_to_png(tex, base.path_join("weapons").path_join(id + ".png"))


func _generate_weapon_icon(weapon_id: String, color: Color) -> Texture2D:
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := color.darkened(0.3)
	var cx := 48
	var cy := 48
	match weapon_id:
		"blade_short":
			for x in range(36, 60):
				for y in range(42, 54):
					img.set_pixel(x, y, color)
			for x in range(38, 58):
				for y in range(44, 52):
					img.set_pixel(x, y, dark)
		"hammer_heavy":
			for x in range(32, 64):
				for y in range(28, 44):
					img.set_pixel(x, y, color)
			for x in range(44, 52):
				for y in range(44, 72):
					img.set_pixel(x, y, dark)
		"pistol_basic":
			for x in range(28, 68):
				for y in range(40, 56):
					img.set_pixel(x, y, color)
			for x in range(32, 48):
				for y in range(44, 52):
					img.set_pixel(x, y, dark)
		"shotgun_wide":
			for x in range(24, 72):
				for y in range(42, 54):
					img.set_pixel(x, y, color)
			for x in range(40, 56):
				for y in range(44, 52):
					img.set_pixel(x, y, dark)
		"rifle_long":
			for x in range(16, 80):
				for y in range(44, 52):
					img.set_pixel(x, y, color)
			for x in range(36, 60):
				for y in range(46, 50):
					img.set_pixel(x, y, dark)
		"wand_focus":
			for x in range(44, 52):
				for y in range(24, 72):
					img.set_pixel(x, y, dark)
			for x in range(38, 58):
				for y in range(20, 40):
					img.set_pixel(x, y, color)
		_:
			for x in range(96):
				for y in range(96):
					if Vector2(x - cx, y - cy).length() < 32:
						img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _export_bullets(base: String) -> void:
	# 玩家/敌人通用子弹
	var tex_player := PixelGenerator.generate_bullet_sprite(false)
	var tex_enemy := PixelGenerator.generate_bullet_sprite(true)
	_tex_to_png(tex_player, base.path_join("bullets").path_join("player_bullet.png"))
	_tex_to_png(tex_enemy, base.path_join("bullets").path_join("enemy_bullet.png"))
	# 3 种子弹类型：firearm(pistol/shotgun/rifle)、laser、orb
	_tex_to_png(PixelGenerator.generate_bullet_sprite_by_type("firearm", Color(1.0, 1.0, 0.4)), base.path_join("bullets").path_join("bullet_firearm.png"))
	_tex_to_png(PixelGenerator.generate_bullet_sprite_by_type("laser", Color(0.88, 0.46, 0.95)), base.path_join("bullets").path_join("bullet_laser.png"))
	_tex_to_png(PixelGenerator.generate_bullet_sprite_by_type("orb", Color(0.88, 0.46, 0.95)), base.path_join("bullets").path_join("bullet_orb.png"))


func _export_pickups(base: String) -> void:
	var tex_coin := PixelGenerator.generate_pickup_sprite(false)
	var tex_heal := PixelGenerator.generate_pickup_sprite(true)
	_tex_to_png(tex_coin, base.path_join("pickups").path_join("coin.png"))
	_tex_to_png(tex_heal, base.path_join("pickups").path_join("heal.png"))
