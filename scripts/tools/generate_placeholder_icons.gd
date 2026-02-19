# 生成占位图标：运行 `godot --headless --script res://scripts/tools/generate_placeholder_icons.gd` 创建 assets 目录下的占位图。
extends MainLoop

func _initialize() -> int:
	var dirs := ["res://assets/ui/upgrade_icons", "res://assets/magic"]
	for d in dirs:
		var dir := DirAccess.open("res://")
		if dir.make_dir_recursive(d.replace("res://", "")) != OK:
			pass  # 可能已存在
	var icons := [
		["res://assets/ui/upgrade_icons/icon_hp.png", Color(0.9, 0.25, 0.25)],
		["res://assets/ui/upgrade_icons/icon_mana.png", Color(0.35, 0.55, 1.0)],
		["res://assets/ui/upgrade_icons/icon_armor.png", Color(0.6, 0.6, 0.65)],
		["res://assets/ui/upgrade_icons/icon_speed.png", Color(0.3, 0.85, 0.4)],
		["res://assets/ui/upgrade_icons/icon_melee.png", Color(0.85, 0.4, 0.2)],
		["res://assets/ui/upgrade_icons/icon_ranged.png", Color(0.5, 0.7, 0.9)],
		["res://assets/ui/upgrade_icons/icon_regen.png", Color(0.4, 0.9, 0.5)],
		["res://assets/ui/upgrade_icons/icon_lifesteal.png", Color(0.8, 0.2, 0.5)],
		["res://assets/ui/upgrade_icons/icon_mana_regen.png", Color(0.4, 0.6, 1.0)],
		["res://assets/magic/icon_fire.png", Color(1.0, 0.45, 0.15)],
		["res://assets/magic/icon_ice.png", Color(0.4, 0.75, 1.0)],
		["res://assets/magic/icon_poison.png", Color(0.5, 0.2, 0.7)],
		["res://assets/magic/icon_physical.png", Color(0.6, 0.6, 0.65)],
	]
	# 跳过已由 Pixellab 替换的图标（避免覆盖）
	var skip_paths := ["res://assets/magic/icon_fire.png", "res://assets/magic/icon_lightning.png"]
	var size := 64
	for pair in icons:
		var path: String = pair[0]
		if path in skip_paths:
			continue
		var col: Color = pair[1]
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(col)
		# 简单边框
		var border := col.darkened(0.3)
		for i in range(size):
			img.set_pixel(i, 0, border)
			img.set_pixel(i, size - 1, border)
			img.set_pixel(0, i, border)
			img.set_pixel(size - 1, i, border)
		img.save_png(path)
		print("Generated: ", path)
	return EXIT_SUCCESS
