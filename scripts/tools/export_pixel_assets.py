#!/usr/bin/env python3
"""导出像素美术资源到 assets/ 目录。运行: python scripts/tools/export_pixel_assets.py"""

from pathlib import Path
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
ASSETS = PROJECT_ROOT / "assets"


def ensure_dirs():
    for sub in ["characters", "enemies", "weapons", "bullets", "pickups", "terrain"]:
        (ASSETS / sub).mkdir(parents=True, exist_ok=True)


def save_png(img: Image.Image, path: Path):
    img.save(path)
    print(f"  Saved: {path.relative_to(PROJECT_ROOT)}")


def player_sprite_sheet(scheme: int) -> Image.Image:
    """8 方向精灵图：8 列 x 3 行（站立、行走帧1、行走帧2），每格 24x24。方向顺序：E, SE, S, SW, W, NW, N, NE"""
    fw, fh = 24, 24
    w, h = fw * 8, fh * 3
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body = (51, 178, 255, 255) if scheme == 0 else (255, 140, 51, 255)
    dark = (38, 133, 191, 255) if scheme == 0 else (191, 105, 38, 255)

    def draw_frame(ox: int, oy: int, dy_head: int = 0, dy_body: int = 0, arm_left: int = 0, arm_right: int = 0) -> None:
        # head
        for x in range(8, 16):
            for y in range(3, 10):
                img.putpixel((ox + x, oy + y + dy_head), body)
        # body
        for x in range(6, 18):
            for y in range(10, 21):
                img.putpixel((ox + x, oy + y + dy_body), body)
        # arms (left 3-6, right 18-21)
        for x in range(3, 6):
            for y in range(11, 18):
                img.putpixel((ox + x + arm_left, oy + y), dark)
        for x in range(18, 21):
            for y in range(11, 18):
                img.putpixel((ox + x + arm_right, oy + y), dark)

    for dir_idx in range(8):
        ox = dir_idx * fw
        # 行 0：站立
        draw_frame(ox, 0)
        # 行 1：行走帧1（身体略下移、左臂前摆）
        draw_frame(ox, fh, dy_head=0, dy_body=1, arm_left=1, arm_right=-1)
        # 行 2：行走帧2（身体略上移、右臂前摆）
        draw_frame(ox, fh * 2, dy_head=-1, dy_body=0, arm_left=-1, arm_right=1)
    return img


def enemy_sprite_sheet(etype: int) -> Image.Image:
    """8 方向敌人精灵图：8 列 x 3 行（站立、行走帧1、行走帧2），每格 18x18"""
    fw, fh = 18, 18
    w, h = fw * 8, fh * 3
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    stand = enemy_sprite(etype)
    for dir_idx in range(8):
        ox = dir_idx * fw
        # 行 0：站立
        for x in range(18):
            for y in range(18):
                img.putpixel((ox + x, y), stand.getpixel((x, y)))
        # 行 1：行走帧1（整体下移 1 像素，模拟脚着地）
        for x in range(18):
            for y in range(17):
                img.putpixel((ox + x, fh + 1 + y), stand.getpixel((x, y)))
        # 行 2：行走帧2（整体上移 1 像素，模拟抬脚）
        for x in range(18):
            for y in range(1, 18):
                img.putpixel((ox + x, fh * 2 + y - 1), stand.getpixel((x, y)))
    return img


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


def enemy_bullet_sprite() -> Image.Image:
    """敌人专用子弹：10x10 像素，个头更大，偏红色。"""
    size = 10
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = (255, 77, 77, 255)
    cx = (size - 1) * 0.5
    cy = (size - 1) * 0.5
    r = 4.5
    for x in range(size):
        for y in range(size):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                img.putpixel((x, y), c)
    return img


def bullet_by_type(btype: str, color: tuple) -> Image.Image:
    """3 种子弹类型：firearm(4x4)、laser(12x2)、orb(8x8)"""
    r, g, b = int(color[0] * 255), int(color[1] * 255), int(color[2] * 255)
    c = (r, g, b, 255)
    if btype == "firearm":
        img = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
        for x in range(4):
            for y in range(4):
                if abs(x - 1.5) + abs(y - 1.5) <= 2:
                    img.putpixel((x, y), c)
    elif btype == "laser":
        img = Image.new("RGBA", (12, 2), (0, 0, 0, 0))
        for x in range(12):
            for y in range(2):
                img.putpixel((x, y), c)
    elif btype == "orb":
        img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for x in range(8):
            for y in range(8):
                if (x - 3.5) ** 2 + (y - 3.5) ** 2 <= 12:
                    img.putpixel((x, y), c)
    else:
        img = bullet_sprite(False)
    return img


def terrain_tile(tile_id: str) -> Image.Image:
    """32x32 地形 tile"""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    if tile_id == "floor_a":
        c = (199, 199, 204, 255)  # 0.78, 0.78, 0.80
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    elif tile_id == "floor_b":
        c = (184, 184, 189, 255)  # 0.72, 0.72, 0.74
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    elif tile_id == "floor_seaside_a":
        c = (166, 199, 209, 255)  # 0.65, 0.78, 0.82
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    elif tile_id == "floor_seaside_b":
        c = (140, 179, 191, 255)  # 0.55, 0.70, 0.75
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    elif tile_id == "floor_mountain_a":
        c = (140, 133, 122, 255)  # 0.55, 0.52, 0.48
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    elif tile_id == "floor_mountain_b":
        c = (122, 115, 107, 255)  # 0.48, 0.45, 0.42
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    elif tile_id == "grass":
        c = (51, 115, 46, 115)  # 0.2, 0.45, 0.18, 0.45
        for x in range(32):
            for y in range(32):
                img.putpixel((x, y), c)
    elif tile_id == "shallow_water":
        c = (61, 140, 204, 122)  # 0.24, 0.55, 0.80, 0.48
        for x in range(32):
            for y in range(32):
                img.putpixel((x, y), c)
    elif tile_id == "deep_water":
        c = (20, 51, 107, 143)  # 0.08, 0.20, 0.42, 0.56
        for x in range(32):
            for y in range(32):
                img.putpixel((x, y), c)
    elif tile_id == "obstacle":
        c = (41, 41, 51, 255)  # 0.16, 0.16, 0.20
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    elif tile_id == "boundary":
        c = (84, 84, 89, 255)  # 0.33, 0.33, 0.35
        img.paste(Image.new("RGBA", (32, 32), c), (0, 0))
    return img


def terrain_atlas() -> Image.Image:
    """3 rows x 7 cols: row0=flat, row1=seaside, row2=mountain floor variants; cols 2-6 共用 grass/water/obstacle/boundary"""
    # 第 0 行：flat_a, flat_b, grass, shallow_water, deep_water, obstacle, boundary
    row0 = ["floor_a", "floor_b", "grass", "shallow_water", "deep_water", "obstacle", "boundary"]
    # 第 1 行：seaside_a, seaside_b，其余复用 row0
    row1 = ["floor_seaside_a", "floor_seaside_b", "grass", "shallow_water", "deep_water", "obstacle", "boundary"]
    # 第 2 行：mountain_a, mountain_b，其余复用 row0
    row2 = ["floor_mountain_a", "floor_mountain_b", "grass", "shallow_water", "deep_water", "obstacle", "boundary"]
    w, h = 32 * 7, 32 * 3
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, tid in enumerate(row0):
        img.paste(terrain_tile(tid), (i * 32, 0))
    for i, tid in enumerate(row1):
        img.paste(terrain_tile(tid), (i * 32, 32))
    for i, tid in enumerate(row2):
        img.paste(terrain_tile(tid), (i * 32, 64))
    return img


def swing_visual(weapon_id: str, color: tuple) -> Image.Image:
    """近战挥击视觉 24x8"""
    img = Image.new("RGBA", (24, 8), (0, 0, 0, 0))
    r, g, b = int(color[0] * 255), int(color[1] * 255), int(color[2] * 255)
    c = (r, g, b, 255)
    dark = (int(r * 0.7), int(g * 0.7), int(b * 0.7), 255)
    if weapon_id == "blade_short":
        for x in range(4, 20):
            for y in range(2, 6):
                img.putpixel((x, y), c)
        for x in range(6, 18):
            for y in range(3, 5):
                img.putpixel((x, y), dark)
    elif weapon_id == "dagger":
        # 刺刀：细长尖刺，比 blade_short 更窄
        for x in range(6, 18):
            for y in range(2, 6):
                img.putpixel((x, y), c)
        for x in range(8, 16):
            for y in range(3, 5):
                img.putpixel((x, y), dark)
    elif weapon_id == "spear":
        # 长矛：细长枪尖，延伸更远
        for x in range(2, 22):
            for y in range(3, 5):
                img.putpixel((x, y), c)
        for x in range(4, 20):
            for y in range(3, 5):
                img.putpixel((x, y), dark)
    elif weapon_id == "chainsaw":
        # 链锯：锯齿状刀刃
        for x in range(4, 20):
            for y in range(2, 6):
                img.putpixel((x, y), c)
        for x in range(6, 18):
            if (x - 6) % 3 < 2:
                img.putpixel((x, 3), dark)
                img.putpixel((x, 4), dark)
    else:  # hammer_heavy
        for x in range(2, 22):
            for y in range(1, 7):
                img.putpixel((x, y), c)
        for x in range(4, 20):
            for y in range(2, 6):
                img.putpixel((x, y), dark)
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
    elif weapon_id == "dagger":
        for x in range(40, 56):
            for y in range(42, 54):
                img.putpixel((x, y), c)
        for x in range(42, 54):
            for y in range(44, 52):
                img.putpixel((x, y), dark)
    elif weapon_id == "spear":
        for x in range(28, 68):
            for y in range(44, 52):
                img.putpixel((x, y), c)
        for x in range(36, 60):
            for y in range(46, 50):
                img.putpixel((x, y), dark)
    elif weapon_id == "chainsaw":
        for x in range(32, 64):
            for y in range(36, 60):
                img.putpixel((x, y), c)
        for x in range(38, 58):
            for y in range(42, 54):
                img.putpixel((x, y), dark)
    elif weapon_id == "sniper":
        for x in range(12, 84):
            for y in range(44, 52):
                img.putpixel((x, y), c)
        for x in range(36, 60):
            for y in range(46, 50):
                img.putpixel((x, y), dark)
    elif weapon_id == "orb_wand":
        for x in range(40, 56):
            for y in range(24, 72):
                img.putpixel((x, y), dark)
        for x in range(42, 54):
            for y in range(32, 48):
                img.putpixel((x, y), c)
    else:
        for x in range(96):
            for y in range(96):
                if (x - cx) ** 2 + (y - cy) ** 2 < 32 ** 2:
                    img.putpixel((x, y), c)
    return img


WEAPON_DEFS = [
    ("blade_short", (0.95, 0.30, 0.30)),
    ("dagger", (0.60, 0.65, 0.75)),
    ("spear", (0.55, 0.60, 0.70)),
    ("chainsaw", (0.35, 0.38, 0.40)),
    ("hammer_heavy", (0.90, 0.58, 0.24)),
    ("pistol_basic", (0.25, 0.80, 0.95)),
    ("shotgun_wide", (0.50, 0.88, 0.30)),
    ("rifle_long", (0.65, 0.66, 0.95)),
    ("wand_focus", (0.88, 0.46, 0.95)),
    ("sniper", (0.45, 0.50, 0.55)),
    ("orb_wand", (0.95, 0.70, 0.35)),
]


def main():
    ensure_dirs()
    for i in range(2):
        save_png(player_sprite(i), ASSETS / "characters" / f"player_scheme_{i}.png")
        save_png(player_sprite_sheet(i), ASSETS / "characters" / f"player_scheme_{i}_sheet.png")
    names = ["enemy_melee", "enemy_ranged", "enemy_tank", "enemy_boss", "enemy_aquatic", "enemy_dasher"]
    for i, name in enumerate(names):
        save_png(enemy_sprite(i), ASSETS / "enemies" / f"{name}.png")
        save_png(enemy_sprite_sheet(i), ASSETS / "enemies" / f"{name}_sheet.png")
    for wid, color in WEAPON_DEFS:
        save_png(weapon_icon(wid, color), ASSETS / "weapons" / f"{wid}.png")
    save_png(swing_visual("blade_short", (0.95, 0.30, 0.30)), ASSETS / "weapons" / "swing_blade_short.png")
    save_png(swing_visual("hammer_heavy", (0.90, 0.58, 0.24)), ASSETS / "weapons" / "swing_hammer_heavy.png")
    save_png(swing_visual("dagger", (0.60, 0.65, 0.75)), ASSETS / "weapons" / "swing_dagger.png")
    save_png(swing_visual("spear", (0.55, 0.60, 0.70)), ASSETS / "weapons" / "swing_spear.png")
    save_png(swing_visual("chainsaw", (0.35, 0.38, 0.40)), ASSETS / "weapons" / "swing_chainsaw.png")
    save_png(bullet_by_type("firearm", (1.0, 1.0, 0.4)), ASSETS / "bullets" / "bullet_firearm.png")
    save_png(bullet_by_type("laser", (0.88, 0.46, 0.95)), ASSETS / "bullets" / "bullet_laser.png")
    save_png(bullet_by_type("orb", (0.88, 0.46, 0.95)), ASSETS / "bullets" / "bullet_orb.png")
    save_png(bullet_sprite(False), ASSETS / "bullets" / "player_bullet.png")
    save_png(enemy_bullet_sprite(), ASSETS / "bullets" / "enemy_bullet.png")
    save_png(pickup_sprite(False), ASSETS / "pickups" / "coin.png")
    save_png(pickup_sprite(True), ASSETS / "pickups" / "heal.png")
    for tid in ["floor_a", "floor_b", "grass", "shallow_water", "deep_water", "obstacle", "boundary"]:
        save_png(terrain_tile(tid), ASSETS / "terrain" / f"{tid}.png")
    save_png(terrain_atlas(), ASSETS / "terrain" / "terrain_atlas.png")
    print(f"Pixel assets exported to {ASSETS}")


if __name__ == "__main__":
    main()
