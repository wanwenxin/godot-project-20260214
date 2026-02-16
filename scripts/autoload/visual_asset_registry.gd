extends Node

# 视觉资源工具：仅保留 make_color_texture 作为纯色贴图生成工具。
# 纹理路径、地形色块等已解耦至各实现类/场景独立配置。


## 生成指定颜色与尺寸的纯色贴图，用于图标/占位符回退。
func make_color_texture(color: Color, size: Vector2i = Vector2i(24, 24)) -> Texture2D:
	var img := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
