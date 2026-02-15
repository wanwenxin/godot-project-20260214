class_name PixelGenerator
extends RefCounted

# 像素资源生成器（无美术资源版本）：
# - 使用 Image 逐像素绘制
# - 运行时生成 Texture2D
# - 提供玩家/敌人/子弹/UI 面板基础图块

static func generate_player_sprite(color_scheme: int) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body_color := Color(0.20, 0.70, 1.0) if color_scheme == 0 else Color(1.0, 0.55, 0.20)
	var dark_color := body_color.darkened(0.25)

	# head
	for x in range(5, 11):
		for y in range(2, 7):
			img.set_pixel(x, y, body_color)
	# body
	for x in range(4, 12):
		for y in range(7, 14):
			img.set_pixel(x, y, body_color)
	# arms
	for x in range(2, 4):
		for y in range(8, 12):
			img.set_pixel(x, y, dark_color)
	for x in range(12, 14):
		for y in range(8, 12):
			img.set_pixel(x, y, dark_color)

	return ImageTexture.create_from_image(img)


static func generate_enemy_sprite(enemy_type: int) -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	if enemy_type == 0:
		# 近战敌人：红色方块 + 角
		var color := Color(0.85, 0.20, 0.20)
		for x in range(2, 10):
			for y in range(2, 10):
				img.set_pixel(x, y, color)
		# simple horns
		img.set_pixel(3, 1, color)
		img.set_pixel(8, 1, color)
	elif enemy_type == 1:
		# 远程敌人：紫色菱形 + 白色眼睛
		var color2 := Color(0.70, 0.18, 0.85)
		for x in range(1, 11):
			for y in range(1, 11):
				if abs(x - 6) + abs(y - 6) <= 5:
					img.set_pixel(x, y, color2)
		# eye
		img.set_pixel(5, 5, Color.WHITE)
		img.set_pixel(6, 5, Color.WHITE)
	elif enemy_type == 2:
		# 坦克敌人：深绿色重甲方块。
		var color3 := Color(0.20, 0.65, 0.25)
		var edge := color3.darkened(0.28)
		for x in range(1, 11):
			for y in range(1, 11):
				img.set_pixel(x, y, color3 if x > 1 and x < 10 and y > 1 and y < 10 else edge)
	else:
		# Boss：深红核心 + 白色光点。
		var color4 := Color(0.70, 0.12, 0.18)
		for x in range(0, 12):
			for y in range(0, 12):
				if abs(x - 5.5) + abs(y - 5.5) <= 6:
					img.set_pixel(x, y, color4)
		img.set_pixel(5, 5, Color.WHITE)
		img.set_pixel(6, 5, Color.WHITE)
		img.set_pixel(5, 6, Color.WHITE)
		img.set_pixel(6, 6, Color.WHITE)

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
