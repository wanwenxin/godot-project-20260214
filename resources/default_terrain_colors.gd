extends RefCounted
class_name DefaultTerrainColors

## 默认地形配色：flat=平地，seaside=海边，mountain=山地。
## 供 game.gd 在无特殊地形时使用。

const FLOOR_COLORS := {
	"flat": {
		"floor_a": Color(0.78, 0.78, 0.80, 1.0),
		"floor_b": Color(0.72, 0.72, 0.74, 1.0)
	},
	"seaside": {
		"floor_a": Color(0.65, 0.78, 0.82, 1.0),
		"floor_b": Color(0.55, 0.70, 0.75, 1.0)
	},
	"mountain": {
		"floor_a": Color(0.55, 0.52, 0.48, 1.0),
		"floor_b": Color(0.48, 0.45, 0.42, 1.0)
	}
}


static func get_floor_colors(terrain_type: String) -> Array[Color]:
	var t := terrain_type.to_lower()
	if not FLOOR_COLORS.has(t):
		t = "flat"
	var cfg: Dictionary = FLOOR_COLORS[t]
	return [cfg["floor_a"], cfg["floor_b"]]
