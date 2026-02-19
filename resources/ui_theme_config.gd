extends Resource
class_name UiThemeConfig

# UI 主题色配置：模态背景、面板背景、边框等，供 HUD、暂停、设置、结算等界面引用。
const THEME_PATH := "res://resources/ui_theme.tres"

@export var modal_backdrop: Color = Color(0.08, 0.09, 0.11, 1.0)
@export var modal_panel_bg: Color = Color(0.16, 0.17, 0.20, 1.0)
@export var modal_panel_border: Color = Color(0.82, 0.84, 0.90, 1.0)

## 边距常量（像素），供各面板 MarginContainer 引用，便于统一调整。
@export var margin_default: int = 32
@export var margin_small: int = 24
@export var margin_tight: int = 16

## 字体与间距常量，供 Tab、内容区、列表等引用，便于 720p 下统一调参。
@export var tab_font_size: int = 20
@export var content_font_size: int = 18
@export var separation_default: int = 12
@export var separation_tight: int = 8

## 背包双面板背景色：ContentPanel 略深、DetailPanel 略浅，便于视觉区分。
@export var content_panel_bg: Color = Color(0.14, 0.15, 0.18, 1.0)
@export var detail_panel_bg: Color = Color(0.18, 0.19, 0.22, 1.0)

## 字体缩放系数，供多语言/无障碍适配；各 UI 在 add_theme_font_size_override 时乘以该值。
## 例如：effective_size = int(BASE_FONT_SIZE * UiThemeConfig.load_theme().font_scale)
@export var font_scale: float = 1.0


## [自定义] 动态加载 UI 主题。路径硬编码 THEME_PATH，ResourceLoader.exists 校验后 load()，
## 失败时返回新建的 UiThemeConfig（使用默认颜色）。
static func load_theme() -> UiThemeConfig:
	if ResourceLoader.exists(THEME_PATH):
		var t := load(THEME_PATH) as UiThemeConfig
		if t != null:
			return t
	return UiThemeConfig.new()


## [自定义] 返回模态面板用的 StyleBoxTexture（程序生成纹理），供暂停、设置、结算等界面复用。
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


## [自定义] 返回经 font_scale 缩放后的字号，供各 UI 在 add_theme_font_size_override 时使用。
func get_scaled_font_size(base_size: int) -> int:
	return int(base_size * font_scale)


## [自定义] 返回指定背景色的面板 StyleBoxTexture，供背包 ContentPanel/DetailPanel 等区分使用。
func get_panel_stylebox_for_bg(bg_color: Color) -> StyleBox:
	var tex := VisualAssetRegistry.make_panel_frame_texture(
		Vector2i(64, 64),
		bg_color,
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
