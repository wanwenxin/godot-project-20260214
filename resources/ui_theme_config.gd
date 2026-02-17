extends Resource
class_name UiThemeConfig

# UI 主题色配置：模态背景、面板背景、边框等，供 HUD、暂停、设置、结算等界面引用。
const THEME_PATH := "res://resources/ui_theme.tres"

@export var modal_backdrop: Color = Color(0.08, 0.09, 0.11, 1.0)
@export var modal_panel_bg: Color = Color(0.16, 0.17, 0.20, 1.0)
@export var modal_panel_border: Color = Color(0.82, 0.84, 0.90, 1.0)


static func load_theme() -> UiThemeConfig:
	if ResourceLoader.exists(THEME_PATH):
		var t := load(THEME_PATH) as UiThemeConfig
		if t != null:
			return t
	return UiThemeConfig.new()


## 返回模态面板用的 StyleBoxTexture（程序生成纹理），供暂停、设置、结算等界面复用。
func get_modal_panel_stylebox() -> StyleBox:
	var tex := VisualAssetRegistry.make_panel_frame_texture(
		Vector2i(64, 64),
		modal_panel_bg,
		modal_panel_border,
		2,
		8
	)
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.expand_margin_left = 8
	style.expand_margin_right = 8
	style.expand_margin_top = 8
	style.expand_margin_bottom = 8
	return style
