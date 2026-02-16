#!/usr/bin/env python3
"""导出像素美术资源到 assets/ 目录。运行: python scripts/tools/export_pixel_assets.py"""

from pathlib import Path
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
ASSETS = PROJECT_ROOT / "assets"


def ensure_dirs():
    for sub in ["characters", "enemies", "weapons", "bullets", "pickups"]:
        (ASSETS / sub).mkdir(parents=True, exist_ok=True)


def save_png(img: Image.Image, path: Path):
    img.save(path)
    print(f"  Saved: {path.relative_to(PROJECT_ROOT)}")


def player_sprite(scheme: int) -> Image.Image:
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    body = (51, 178, 255, 255) if scheme == 0 else (255, 140, 51, 255)
    dark = (38, 133, 191, 255) if scheme == 0 else (191, 105, 38, 255)
    # head
    for x in range(8, 16):
        for y in range(3, 10):
            img.putpixel((x, y), body)
    # body
    for x in range(6, 18):
        for y in range(10, 21):
            img.putpixel((x, y), body)
    # arms
    for x in range(3, 6):
        for y in range(11, 18):
            img.putpixel((x, y), dark)
    for x in range(18, 21):
        for y in range(11, 18):
            img.putpixel((x, y), dark)
    return img


def enemy_sprite(etype: int) -> Image.Image:
    img = Image.new("RGBA", (18, 18), (0, 0, 0, 0))
    if etype == 0:  # melee
        c = (217, 51, 51, 255)
        for x in range(3, 15):
            for y in range(3, 15):
                img.putpixel((x, y), c)
        img.putpixel((4, 2), c)
        img.putpixel((13, 2), c)
    elif etype == 1:  # ranged
        c = (179, 46, 217, 255)
        for x in range(1, 17):
            for y in range(1, 17):
                if abs(x - 8) + abs(y - 8) <= 7:
                    img.putpixel((x, y), c)
        img.putpixel((7, 7), (255, 255, 255, 255))
        img.putpixel((8, 7), (255, 255, 255, 255))
    elif etype == 2:  # tank
        c = (51, 166, 64, 255)
        edge = (37, 120, 46, 255)
        for x in range(2, 16):
            for y in range(2, 16):
                img.putpixel((x, y), c if 2 < x < 15 and 2 < y < 15 else edge)
    elif etype == 4:  # aquatic
        c = (51, 191, 217, 255)
        for x in range(4, 14):
            for y in range(5, 13):
                img.putpixel((x, y), c)
        for y in range(6, 12):
            img.putpixel((2, y), c)
        for y in range(7, 11):
            img.putpixel((15, y), c)
    elif etype == 5:  # dasher
        c = (255, 115, 38, 255)
        for x in range(1, 17):
            for y in range(1, 17):
                if abs(x - 8) + abs(y - 8) <= 6:
                    img.putpixel((x, y), c)
        img.putpixel((8, 8), (255, 140, 70, 255))
    else:  # boss
        c = (179, 31, 46, 255)
        for x in range(18):
            for y in range(18):
                if abs(x - 8.5) + abs(y - 8.5) <= 9:
                    img.putpixel((x, y), c)
        for px, py in [(8, 8), (9, 8), (8, 9), (9, 9)]:
            img.putpixel((px, py), (255, 255, 255, 255))
    return img


def bullet_sprite(is_enemy: bool) -> Image.Image:
    img = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    c = (255, 77, 77, 255) if is_enemy else (255, 255, 102, 255)
    for x in range(4):
        for y in range(4):
            if abs(x - 1.5) + abs(y - 1.5) <= 2:
                img.putpixel((x, y), c)
    return img


def pickup_sprite(is_heal: bool) -> Image.Image:
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    if is_heal:
        c = (242, 51, 89, 255)
        for x in range(2, 6):
            img.putpixel((x, 1), c)
            img.putpixel((x, 6), c)
        for y in range(2, 6):
            img.putpixel((1, y), c)
            img.putpixel((6, y), c)
        for x in range(2, 6):
            for y in range(2, 6):
                img.putpixel((x, y), c)
    else:
        c = (255, 217, 56, 255)
        for x in range(1, 7):
            for y in range(1, 7):
                if abs(x - 3.5) + abs(y - 3.5) <= 4:
                    img.putpixel((x, y), c)
    return img


def weapon_icon(weapon_id: str, color: tuple) -> Image.Image:
    img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    r, g, b = int(color[0] * 255), int(color[1] * 255), int(color[2] * 255)
    c = (r, g, b, 255)
    dark = (int(r * 0.7), int(g * 0.7), int(b * 0.7), 255)
    cx, cy = 48, 48

    if weapon_id == "blade_short":
        for x in range(36, 60):
            for y in range(42, 54):
                img.putpixel((x, y), c)
        for x in range(38, 58):
            for y in range(44, 52):
                img.putpixel((x, y), dark)
    elif weapon_id == "hammer_heavy":
        for x in range(32, 64):
            for y in range(28, 44):
                img.putpixel((x, y), c)
        for x in range(44, 52):
            for y in range(44, 72):
                img.putpixel((x, y), dark)
    elif weapon_id == "pistol_basic":
        for x in range(28, 68):
            for y in range(40, 56):
                img.putpixel((x, y), c)
        for x in range(32, 48):
            for y in range(44, 52):
                img.putpixel((x, y), dark)
    elif weapon_id == "shotgun_wide":
        for x in range(24, 72):
            for y in range(42, 54):
                img.putpixel((x, y), c)
        for x in range(40, 56):
            for y in range(44, 52):
                img.putpixel((x, y), dark)
    elif weapon_id == "rifle_long":
        for x in range(16, 80):
            for y in range(44, 52):
                img.putpixel((x, y), c)
        for x in range(36, 60):
            for y in range(46, 50):
                img.putpixel((x, y), dark)
    elif weapon_id == "wand_focus":
        for x in range(44, 52):
            for y in range(24, 72):
                img.putpixel((x, y), dark)
        for x in range(38, 58):
            for y in range(20, 40):
                img.putpixel((x, y), c)
    else:
        for x in range(96):
            for y in range(96):
                if (x - cx) ** 2 + (y - cy) ** 2 < 32 ** 2:
                    img.putpixel((x, y), c)
    return img


WEAPON_DEFS = [
    ("blade_short", (0.95, 0.30, 0.30)),
    ("hammer_heavy", (0.90, 0.58, 0.24)),
    ("pistol_basic", (0.25, 0.80, 0.95)),
    ("shotgun_wide", (0.50, 0.88, 0.30)),
    ("rifle_long", (0.65, 0.66, 0.95)),
    ("wand_focus", (0.88, 0.46, 0.95)),
]


def main():
    ensure_dirs()
    for i in range(2):
        save_png(player_sprite(i), ASSETS / "characters" / f"player_scheme_{i}.png")
    names = ["enemy_melee", "enemy_ranged", "enemy_tank", "enemy_boss", "enemy_aquatic", "enemy_dasher"]
    for i, name in enumerate(names):
        save_png(enemy_sprite(i), ASSETS / "enemies" / f"{name}.png")
    for wid, color in WEAPON_DEFS:
        save_png(weapon_icon(wid, color), ASSETS / "weapons" / f"{wid}.png")
    save_png(bullet_sprite(False), ASSETS / "bullets" / "player_bullet.png")
    save_png(bullet_sprite(True), ASSETS / "bullets" / "enemy_bullet.png")
    save_png(pickup_sprite(False), ASSETS / "pickups" / "coin.png")
    save_png(pickup_sprite(True), ASSETS / "pickups" / "heal.png")
    print(f"Pixel assets exported to {ASSETS}")


if __name__ == "__main__":
    main()
