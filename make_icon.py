#!/usr/bin/env python3
"""生成 NotchDock 应用图标 (AppIcon.icns)。"""
import os
import subprocess
import sys
from PIL import Image, ImageDraw

S = 1024
HERE = os.path.dirname(os.path.abspath(__file__))
ICONSET = os.path.join(HERE, "AppIcon.iconset")
ICNS = os.path.join(HERE, "AppIcon.icns")

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# 背景渐变（深灰 → 黑）
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
for y in range(S):
    t = y / S
    c = (
        int(46 - 24 * t),
        int(47 - 24 * t),
        int(52 - 30 * t),
        255,
    )
    gd.line([(0, y), (S, y)], fill=c)

mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([40, 40, 984, 984], radius=230, fill=255)
img = Image.composite(grad, img, mask)

# 顶部“刘海/灵动岛”胶囊
cap = Image.new("RGBA", (S, S))
cd = ImageDraw.Draw(cap)
cd.rounded_rectangle([252, 128, 772, 288], radius=80,
                     fill=(11, 11, 14, 255), outline=(255, 255, 255, 42), width=6)
for dx in (-150, 0, 150):
    cd.ellipse([512 + dx - 11, 208 - 11, 512 + dx + 11, 208 + 11],
               fill=(255, 255, 255, 210))
img = Image.alpha_composite(img, cap)

# 白色文件（带折角）
file_img = Image.new("RGBA", (S, S))
fd = ImageDraw.Draw(file_img)
fd.rounded_rectangle([362, 470, 662, 730], radius=40, fill=(242, 243, 246, 255))
fd.polygon([(522, 470), (662, 470), (662, 610)], fill=(196, 200, 210, 255))
# 文件上的几行文字示意
for i, w in enumerate((120, 170, 90)):
    fd.rounded_rectangle([410, 556 + i * 44, 410 + w, 556 + i * 44 + 14],
                         radius=7, fill=(170, 174, 184, 255))
img = Image.alpha_composite(img, file_img)

# 向下的箭头
arrow = Image.new("RGBA", (S, S))
ad = ImageDraw.Draw(arrow)
ad.polygon([(452, 762), (572, 762), (512, 830)], fill=(148, 156, 172, 255))
img = Image.alpha_composite(img, arrow)

# 底部托盘
tray = Image.new("RGBA", (S, S))
td = ImageDraw.Draw(tray)
td.rounded_rectangle([350, 856, 674, 912], radius=28, fill=(116, 124, 140, 235))
img = Image.alpha_composite(img, tray)

# 生成 iconset
os.makedirs(ICONSET, exist_ok=True)
sizes = {
    "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
}
for name, size in sizes.items():
    img.resize((size, size), Image.LANCZOS).save(os.path.join(ICONSET, name))

subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", ICNS], check=True)
print("OK:", ICNS)
