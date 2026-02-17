#!/usr/bin/env python3
"""批量将 assets/ 下所有 PNG 的非空白像素设为不透明。运行: python scripts/tools/make_opaque.py"""

from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("需要安装 Pillow: pip install Pillow")
    raise SystemExit(1)

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
ASSETS = PROJECT_ROOT / "assets"


def force_opaque(img: Image.Image) -> Image.Image:
    """将非空白像素的 alpha 设为 255。"""
    img = img.copy()
    for x in range(img.width):
        for y in range(img.height):
            px = img.getpixel((x, y))
            if len(px) == 4:
                r, g, b, a = px
                if a > 0:
                    img.putpixel((x, y), (r, g, b, 255))
            else:
                # RGB 模式无需处理
                pass
    return img


def main():
    if not ASSETS.exists():
        print(f"assets 目录不存在: {ASSETS}")
        return
    count = 0
    for png in ASSETS.rglob("*.png"):
        try:
            img = Image.open(png).convert("RGBA")
            out = force_opaque(img)
            out.save(png)
            count += 1
            print(f"  {png.relative_to(PROJECT_ROOT)}")
        except Exception as e:
            print(f"  跳过 {png}: {e}")
    print(f"已处理 {count} 个 PNG 文件")


if __name__ == "__main__":
    main()
