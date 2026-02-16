class_name PixelGenerator
extends RefCounted

# 像素资源生成器（无美术资源版本）：
# - 使用 Image 逐像素绘制
# - 运行时生成 Texture2D
# - 提供玩家/敌人/子弹/UI 面板基础图块

static func generate_player_sprite(color_scheme: int) -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body_color := Color(0.20, 0.70, 1.0) if color_scheme == 0 else Color(1.0, 0.55, 0.20)
	var dark_color := body_color.darkened(0.25)

	# head
	for x in range(8, 16):
		for y in range(3, 10):
			img.set_pixel(x, y, body_color)
	# body
	for x in range(6, 18):
		for y in range(10, 21):
			img.set_pixel(x, y, body_color)
	# arms
	for x in range(3, 6):
		for y in range(11, 18):
			img.set_pixel(x, y, dark_color)
	for x in range(18, 21):
		for y in range(11, 18):
			img.set_pixel(x, y, dark_color)

	return ImageTexture.create_from_image(img)


static func generate_enemy_sprite(enemy_type: int) -> Texture2D:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	if enemy_type == 0:
		# 近战敌人：红色方块 + 角
		var color := Color(0.85, 0.20, 0.20)
		for x in range(3, 15):
			for y in range(3, 15):
				img.set_pixel(x, y, color)
		# simple horns
		img.set_pixel(4, 2, color)
		img.set_pixel(13, 2, color)
	elif enemy_type == 1:
		# 远程敌人：紫色菱形 + 白色眼睛
		var color2 := Color(0.70, 0.18, 0.85)
		for x in range(1, 17):
			for y in range(1, 17):
				if abs(x - 8) + abs(y - 8) <= 7:
					img.set_pixel(x, y, color2)
		# eye
		img.set_pixel(7, 7, Color.WHITE)
		img.set_pixel(8, 7, Color.WHITE)
	elif enemy_type == 2:
		# 坦克敌人：深绿色重甲方块。
		var color3 := Color(0.20, 0.65, 0.25)
		var edge := color3.darkened(0.28)
		for x in range(2, 16):
			for y in range(2, 16):
				img.set_pixel(x, y, color3 if x > 2 and x < 15 and y > 2 and y < 15 else edge)
	elif enemy_type == 4:
		# 水中敌人：青色鱼形。
		var color_aqua := Color(0.20, 0.75, 0.85)
		for x in range(4, 14):
			for y in range(5, 13):
				img.set_pixel(x, y, color_aqua)
		for y in range(6, 12):
			img.set_pixel(2, y, color_aqua)
		for y in range(7, 11):
			img.set_pixel(15, y, color_aqua)
	elif enemy_type == 5:
		# 冲刺敌人：橙色菱形流线型。
		var color_dash := Color(1.0, 0.45, 0.15)
		for x in range(1, 17):
			for y in range(1, 17):
				if abs(x - 8) + abs(y - 8) <= 6:
					img.set_pixel(x, y, color_dash)
		img.set_pixel(8, 8, color_dash.lightened(0.2))
	else:
		# Boss：深红核心 + 白色光点。
		var color4 := Color(0.70, 0.12, 0.18)
		for x in range(0, 18):
			for y in range(0, 18):
				if abs(x - 8.5) + abs(y - 8.5) <= 9:
					img.set_pixel(x, y, color4)
		img.set_pixel(8, 8, Color.WHITE)
		img.set_pixel(9, 8, Color.WHITE)
		img.set_pixel(8, 9, Color.WHITE)
		img.set_pixel(9, 9, Color.WHITE)

	return ImageTexture.create_from_image(img)


static func generate_bullet_sprite(is_enemy: bool = false) -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 我方子弹偏黄，敌方子弹偏红，战场识别更直观。
	var c := Color(1.0, 0.3, 0.3) if is_enemy else Color(1.0, 1.0, 0.4)
	for x in range(4):
		for y in range(4):
			if abs(x - 1.5) + abs(y - 1.5) <= 2:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func generate_bullet_sprite_by_type(type: String, color: Color, size: Vector2i = Vector2i.ZERO) -> Texture2D:
	# 按 bullet_type 生成不同形状与颜色的子弹贴图。
	var w := size.x
	var h := size.y
	match type:
		"pistol":
			w = 4
			h = 4
		"shotgun":
			w = 6
			h = 6
		"rifle":
			w = 8
			h = 2
		"laser":
			w = 12
			h = 2
		"firearm":
			w = 4
			h = 4
		"orb":
			w = 8
			h = 8
		_:
			w = 4 if w <= 0 else w
			h = 4 if h <= 0 else h
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if type == "orb":
		# 法球：圆形
		var r := (minf(w, h) - 1) * 0.5
		for x in range(w):
			for y in range(h):
				if Vector2(x - (w - 1) * 0.5, y - (h - 1) * 0.5).length() <= r:
					img.set_pixel(x, y, color)
	elif type == "pistol" or type == "firearm" or type == "":
		for x in range(w):
			for y in range(h):
				if abs(x - (w - 1) * 0.5) + abs(y - (h - 1) * 0.5) <= 2:
					img.set_pixel(x, y, color)
	elif type == "shotgun":
		var r := (minf(w, h) - 1) * 0.5
		for x in range(w):
			for y in range(h):
				if Vector2(x - (w - 1) * 0.5, y - (h - 1) * 0.5).length() <= r:
					img.set_pixel(x, y, color)
	elif type == "rifle" or type == "laser":
		# 细长条：沿宽度方向
		for x in range(w):
			for y in range(h):
				img.set_pixel(x, y, color)
	else:
		for x in range(w):
			for y in range(h):
				if abs(x - (w - 1) * 0.5) + abs(y - (h - 1) * 0.5) <= 2:
					img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func generate_panel_texture(size: Vector2i, color: Color) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


static func generate_pickup_sprite(is_heal: bool) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if is_heal:
		var c := Color(0.95, 0.20, 0.35)
		for x in range(2, 6):
			img.set_pixel(x, 1, c)
			img.set_pixel(x, 6, c)
		for y in range(2, 6):
			img.set_pixel(1, y, c)
			img.set_pixel(6, y, c)
		for x in range(2, 6):
			for y in range(2, 6):
				img.set_pixel(x, y, c)
	else:
		var c2 := Color(1.0, 0.85, 0.22)
		for x in range(1, 7):
			for y in range(1, 7):
				if abs(x - 3.5) + abs(y - 3.5) <= 4:
					img.set_pixel(x, y, c2)
	return ImageTexture.create_from_image(img)
