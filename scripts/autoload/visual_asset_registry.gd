extends Node

# 视觉资源工具：纯色贴图、面板框纹理生成、纹理路径缓存。
# 纹理路径、地形色块等已解耦至各实现类/场景独立配置。

var _texture_cache: Dictionary = {}  # path -> Texture2D，避免重复 load
var _color_texture_cache: Dictionary = {}  # "r,g,b,a:w:h" -> Texture2D，占位图复用

## 按路径缓存加载纹理，避免同一 icon 重复 load 阻塞主线程。
func get_texture_cached(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex != null:
		_texture_cache[path] = tex
	return tex


## 生成指定颜色与尺寸的纯色贴图，用于图标/占位符回退。同色同尺寸复用缓存。
func make_color_texture(color: Color, size: Vector2i = Vector2i(24, 24)) -> Texture2D:
	var key := "%d,%d,%d,%d:%dx%d" % [int(color.r * 255), int(color.g * 255), int(color.b * 255), int(color.a * 255), size.x, size.y]
	if _color_texture_cache.has(key):
		return _color_texture_cache[key]
	var img := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_color_texture_cache[key] = tex
	return tex


## 生成可拉伸的面板框纹理（九宫格用），配合 StyleBoxTexture 的 expand_margin 使用。
## 绘制圆角矩形边框与填充，返回 ImageTexture。
func make_panel_frame_texture(
	size: Vector2i = Vector2i(48, 48),
	bg_color: Color = Color(0.08, 0.09, 0.12, 0.85),
	border_color: Color = Color(0.25, 0.26, 0.30, 1.0),
	border_width: int = 2,
	_corner_radius: int = 6
) -> Texture2D:
	var w := maxi(32, size.x)
	var h := maxi(32, size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bw := mini(border_width, int(mini(w, h) / 2.0))
	# 先填充背景色
	img.fill(bg_color)
	# 绘制矩形边框（九宫格拉伸时边角保持，中间拉伸）
	for y in range(h):
		for x in range(w):
			if x < bw or x >= w - bw or y < bw or y >= h - bw:
				img.set_pixel(x, y, border_color)
	return ImageTexture.create_from_image(img)
