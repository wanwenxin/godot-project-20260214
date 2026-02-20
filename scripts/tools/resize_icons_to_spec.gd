# 将指定武器/道具/魔法图标 PNG 缩放到 96×96，覆盖原文件。
# 仅处理下方 ICON_FILES 列表中的文件，避免误改其他资源。
# 运行方式：在 Godot 编辑器中运行此脚本，或命令行：godot -s res://scripts/tools/resize_icons_to_spec.gd
# 若 Godot 未在 PATH 中，可使用 Python 版：python scripts/resize_icons_to_spec.py（需 pip install Pillow）
extends SceneTree

const TARGET_SIZE := 96

## 仅处理以下相对 res:// 的路径；与 ART_STYLE_GUIDE 及 PIXELLAB_REPLACED_ASSETS 一致
var ICON_FILES: Array[String] = [
	"res://assets/weapons/blade_short.png",
	"res://assets/weapons/dagger.png",
	"res://assets/weapons/spear.png",
	"res://assets/weapons/chainsaw.png",
	"res://assets/weapons/hammer_heavy.png",
	"res://assets/weapons/pistol_basic.png",
	"res://assets/weapons/shotgun_wide.png",
	"res://assets/weapons/rifle_long.png",
	"res://assets/weapons/wand_focus.png",
	"res://assets/weapons/sniper.png",
	"res://assets/weapons/orb_wand.png",
	"res://assets/ui/upgrade_icons/icon_hp.png",
	"res://assets/ui/upgrade_icons/icon_mana.png",
	"res://assets/ui/upgrade_icons/icon_armor.png",
	"res://assets/ui/upgrade_icons/icon_speed.png",
	"res://assets/ui/upgrade_icons/icon_melee.png",
	"res://assets/ui/upgrade_icons/icon_ranged.png",
	"res://assets/ui/upgrade_icons/icon_regen.png",
	"res://assets/ui/upgrade_icons/icon_lifesteal.png",
	"res://assets/ui/upgrade_icons/icon_mana_regen.png",
	"res://assets/magic/icon_fire.png",
	"res://assets/magic/icon_ice.png",
	"res://assets/magic/icon_lightning.png",
	"res://assets/magic/icon_poison.png",
	"res://assets/magic/icon_physical.png",
]

func _init() -> void:
	_resize_all()
	quit()


func _resize_all() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var ok_count := 0
	var skip_count := 0
	for res_path in ICON_FILES:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if not FileAccess.file_exists(abs_path):
			print("Skip (not found): ", res_path)
			skip_count += 1
			continue
		var img := Image.new()
		var err := img.load(abs_path)
		if err != OK:
			print("Skip (load error %d): %s" % [err, res_path])
			skip_count += 1
			continue
		var w := img.get_width()
		var h := img.get_height()
		if w == TARGET_SIZE and h == TARGET_SIZE:
			print("Skip (already %dx%d): %s" % [w, h, res_path])
			skip_count += 1
			continue
		img.resize(TARGET_SIZE, TARGET_SIZE)
		err = img.save_png(abs_path)
		if err != OK:
			print("Error saving: %s (code %d)" % [res_path, err])
			continue
		print("Resized to %dx%d: %s" % [TARGET_SIZE, TARGET_SIZE, res_path])
		ok_count += 1
	print("Done. Resized: %d, skipped: %d" % [ok_count, skip_count])
