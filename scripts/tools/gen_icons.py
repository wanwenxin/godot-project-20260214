#!/usr/bin/env python3
"""Generate placeholder icons for upgrade and magic UI."""
from PIL import Image
import os

BASE = os.path.join(os.path.dirname(__file__), "..", "..", "assets")
SIZE = 64

ICONS = [
    ("ui/upgrade_icons/icon_hp.png", (230, 64, 64)),
    ("ui/upgrade_icons/icon_mana.png", (89, 140, 255)),
    ("ui/upgrade_icons/icon_armor.png", (153, 153, 166)),
    ("ui/upgrade_icons/icon_speed.png", (77, 217, 102)),
    ("ui/upgrade_icons/icon_melee.png", (217, 102, 51)),
    ("ui/upgrade_icons/icon_ranged.png", (128, 179, 230)),
    ("ui/upgrade_icons/icon_regen.png", (102, 230, 128)),
    ("ui/upgrade_icons/icon_lifesteal.png", (204, 51, 128)),
    ("ui/upgrade_icons/icon_mana_regen.png", (102, 153, 255)),
    ("magic/icon_fire.png", (255, 115, 38)),
    ("magic/icon_ice.png", (102, 191, 255)),
    ("magic/icon_poison.png", (128, 51, 179)),
    ("magic/icon_physical.png", (153, 153, 166)),
]

# 已由 Pixellab 替换的图标，跳过生成
SKIP_PATHS = {"magic/icon_fire.png", "magic/icon_lightning.png"}

def darken(rgb, factor=0.7):
    return tuple(int(c * factor) for c in rgb)

for rel_path, rgb in ICONS:
    if rel_path in SKIP_PATHS:
        continue
    path = os.path.join(BASE, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.new("RGBA", (SIZE, SIZE), (*rgb, 255))
    border = darken(rgb)
    for i in range(SIZE):
        img.putpixel((i, 0), (*border, 255))
        img.putpixel((i, SIZE - 1), (*border, 255))
        img.putpixel((0, i), (*border, 255))
        img.putpixel((SIZE - 1, i), (*border, 255))
    img.save(path)
    print("Generated:", path)
