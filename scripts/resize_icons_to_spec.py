#!/usr/bin/env python3
"""
将指定武器/道具/魔法图标 PNG 缩放到 96x96，覆盖原文件。
仅处理下方 ICON_FILES 列表中的文件，避免误改其他资源。
依赖：pip install Pillow
运行：在项目根目录执行 python scripts/resize_icons_to_spec.py
"""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("请先安装 Pillow: pip install Pillow")
    raise

TARGET_SIZE = 96
PROJECT_ROOT = Path(__file__).resolve().parent.parent

ICON_FILES = [
    "assets/weapons/blade_short.png",
    "assets/weapons/dagger.png",
    "assets/weapons/spear.png",
    "assets/weapons/chainsaw.png",
    "assets/weapons/hammer_heavy.png",
    "assets/weapons/pistol_basic.png",
    "assets/weapons/shotgun_wide.png",
    "assets/weapons/rifle_long.png",
    "assets/weapons/wand_focus.png",
    "assets/weapons/sniper.png",
    "assets/weapons/orb_wand.png",
    "assets/ui/upgrade_icons/icon_hp.png",
    "assets/ui/upgrade_icons/icon_mana.png",
    "assets/ui/upgrade_icons/icon_armor.png",
    "assets/ui/upgrade_icons/icon_speed.png",
    "assets/ui/upgrade_icons/icon_melee.png",
    "assets/ui/upgrade_icons/icon_ranged.png",
    "assets/ui/upgrade_icons/icon_regen.png",
    "assets/ui/upgrade_icons/icon_lifesteal.png",
    "assets/ui/upgrade_icons/icon_mana_regen.png",
    "assets/magic/icon_fire.png",
    "assets/magic/icon_ice.png",
    "assets/magic/icon_lightning.png",
    "assets/magic/icon_poison.png",
    "assets/magic/icon_physical.png",
]


def main() -> None:
    ok_count = 0
    skip_count = 0
    for rel in ICON_FILES:
        path = PROJECT_ROOT / rel
        if not path.is_file():
            print("Skip (not found):", rel)
            skip_count += 1
            continue
        img = Image.open(path).convert("RGBA")
        w, h = img.size
        if w == TARGET_SIZE and h == TARGET_SIZE:
            print("Skip (already %dx%d):" % (w, h), rel)
            skip_count += 1
            continue
        out = img.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
        out.save(path, "PNG")
        print("Resized to %dx%d:" % (TARGET_SIZE, TARGET_SIZE), rel)
        ok_count += 1
    print("Done. Resized: %d, skipped: %d" % (ok_count, skip_count))


if __name__ == "__main__":
    main()
