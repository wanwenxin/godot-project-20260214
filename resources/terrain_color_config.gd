extends Resource

# 地形色块统一配置：在 Inspector 或 .tres 中配置，供 game.gd 直接引用。
# 供 game.gd 直接引用，各地形颜色可在此配置。
@export var floor_a: Color = Color(0.78, 0.78, 0.80, 1.0) # 地板颜色A
@export var floor_b: Color = Color(0.72, 0.72, 0.74, 1.0) # 地板颜色B
@export var boundary: Color = Color(0.33, 0.33, 0.35, 1.0) # 边界颜色
@export var obstacle: Color = Color(0.16, 0.16, 0.20, 1.0) # 障碍物颜色
@export var grass: Color = Color(0.20, 0.45, 0.18, 0.45) # 草地颜色
@export var shallow_water: Color = Color(0.24, 0.55, 0.80, 0.48) # 浅水颜色
@export var deep_water: Color = Color(0.08, 0.20, 0.42, 0.56) # 深水颜色
