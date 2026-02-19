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

## 面板内容区统一内边距，与 margin_tight 语义一致，供所有面板引用。
@export var panel_padding: int = 16

## 字体类型常量，按用途区分，供各 UI 统一引用。
@export var font_size_title: int = 26          ## 面板主标题（如 Paused、Choose Upgrade）
@export var font_size_subtitle: int = 22       ## Tab 标签、区段标题（如 Weapons、Magics）
@export var font_size_list: int = 20          ## 内容列表、得分区、武器卡片名称
@export var font_size_list_secondary: int = 18 ## 套装档位、词条子项
@export var font_size_body: int = 17           ## 详情正文、词条描述
@export var font_size_hint: int = 14           ## 操作说明、按键提示、小标签
@export var font_size_hud: int = 14            ## 血条、金币、波次等顶部信息
@export var font_size_hud_small: int = 11      ## 魔法槽名称、数值等小字

## 字体与间距常量（兼容旧引用），供 Tab、内容区、列表等引用。
@export var tab_font_size: int = 22
@export var content_font_size: int = 20
@export var separation_default: int = 12
@export var separation_tight: int = 8
@export var separation_grid: int = 6           ## 网格/紧凑布局间距（如背包槽位）
@export var separation_grid_tight: int = 4    ## 更紧凑的网格间距
@export var separation_grid_h: int = 10       ## 网格水平间距（武器卡片等）
@export var separation_grid_v: int = 2       ## 网格垂直间距（武器卡片等）

## 背包双面板背景色：ContentPanel 略深、DetailPanel 略浅，便于视觉区分。
@export var content_panel_bg: Color = Color(0.14, 0.15, 0.18, 1.0)
@export var detail_panel_bg: Color = Color(0.18, 0.19, 0.22, 1.0)

## StyleBox 边距，供 get_modal_panel_stylebox 等复用。
@export var stylebox_expand_margin: int = 8
@export var style_expand_margin_hud: int = 6   ## HUD 小面板 expand_margin
@export var style_content_margin_hud: int = 8 ## HUD 小面板 content_margin

## 字体缩放系数，供多语言/无障碍适配；各 UI 在 add_theme_font_size_override 时乘以该值。
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
	style.expand_margin_left = stylebox_expand_margin
	style.expand_margin_right = stylebox_expand_margin
	style.expand_margin_top = stylebox_expand_margin
	style.expand_margin_bottom = stylebox_expand_margin
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
	style.expand_margin_left = stylebox_expand_margin
	style.expand_margin_right = stylebox_expand_margin
	style.expand_margin_top = stylebox_expand_margin
	style.expand_margin_bottom = stylebox_expand_margin
	return style


## [自定义] 返回无可见边框的面板 StyleBox（边框色与背景色一致），供背包等去除白边使用。
func get_panel_stylebox_borderless(bg_color: Color) -> StyleBox:
	var tex := VisualAssetRegistry.make_panel_frame_texture(
		Vector2i(64, 64),
		bg_color,
		bg_color,
		2,
		8
	)
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.expand_margin_left = stylebox_expand_margin
	style.expand_margin_right = stylebox_expand_margin
	style.expand_margin_top = stylebox_expand_margin
	style.expand_margin_bottom = stylebox_expand_margin
	return style
