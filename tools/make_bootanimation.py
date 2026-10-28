#!/usr/bin/env python3
"""Generate the BananaOS boot animation (BlackBerry-style logo + progress bar).

Usage: python3 -I make_bootanimation.py <white-logo.png> <font.ttf> <out.zip>

Layout mirrors the classic BlackBerry boot screen: logo mark + wordmark centred,
silver progress bar underneath that fills while Android boots.
  part0  (play once)  logo fades in, bar fills 0 -> 80 %
  part1  (loop)       bar holds at 80 % with a soft shimmer until boot completes
  part2  (complete)   bar finishes 80 -> 100 % and everything fades out
"""
import os, sys, shutil, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

W, H, FPS = 1080, 560, 30
BAR_W, BAR_H, BAR_Y = 560, 18, 380
HOLD = 0.80

logo_src, font_path, out_zip = sys.argv[1:4]


def build_logo():
    src = Image.open(logo_src).convert("RGBA")
    # The source has a large soft glow; keep only the solid core for a crisp mark.
    alpha = src.getchannel("A").point(lambda a: 255 if a > 235 else 0)
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.2))
    alpha = alpha.crop(alpha.getbbox())
    mark_h = 100
    alpha = alpha.resize((round(alpha.width * mark_h / alpha.height), mark_h), Image.LANCZOS)

    font = ImageFont.truetype(font_path, 80)
    text = "BananaOS"
    tb = font.getbbox(text)
    gap = 20
    lw = alpha.width + gap + (tb[2] - tb[0])
    lh = max(mark_h, tb[3] - tb[1])
    logo = Image.new("L", (lw, lh), 0)
    logo.paste(alpha, (0, (lh - mark_h) // 2))
    d = ImageDraw.Draw(logo)
    d.text((alpha.width + gap - tb[0], (lh - (tb[3] - tb[1])) // 2 - tb[1] + 6), text, font=font, fill=255)
    return logo


LOGO = build_logo()


def bar_layer(progress, shimmer=None):
    """Returns an RGB image of the bar track + fill."""
    img = Image.new("RGB", (W, H), 0)
    d = ImageDraw.Draw(img)
    x0 = (W - BAR_W) // 2
    r = BAR_H // 2
    d.rounded_rectangle((x0, BAR_Y, x0 + BAR_W, BAR_Y + BAR_H), r, outline=(150, 150, 150), width=2, fill=(8, 8, 8))
    fw = int((BAR_W - 6) * progress)
    if fw > BAR_H - 6:
        fill = Image.new("RGB", (fw, BAR_H - 6))
        fd = ImageDraw.Draw(fill)
        # Brushed-silver vertical gradient like the BlackBerry bar.
        for y in range(BAR_H - 6):
            t = y / (BAR_H - 7)
            v = int(255 - 95 * abs(t - 0.3) ** 0.9)
            fd.line((0, y, fw, y), fill=(v, v, v))
        if shimmer is not None:
            sx = int(shimmer * (fw + 160)) - 80
            glow = Image.new("L", fill.size, 0)
            ImageDraw.Draw(glow).rectangle((sx - 40, 0, sx + 40, BAR_H), fill=90)
            glow = glow.filter(ImageFilter.GaussianBlur(18))
            fill = ImageChops.add(fill, Image.merge("RGB", (glow, glow, glow)))
        mask = Image.new("L", fill.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, fw - 1, BAR_H - 7), r - 3, fill=255)
        img.paste(fill, (x0 + 3, BAR_Y + 3), mask)
    return img


def frame(progress, logo_alpha=1.0, master=1.0, shimmer=None):
    img = bar_layer(progress, shimmer)
    lx = (W - LOGO.width) // 2
    ly = 170
    a = LOGO.point(lambda v: int(v * logo_alpha))
    img.paste(Image.new("RGB", LOGO.size, (255, 255, 255)), (lx, ly), a)
    if master < 1.0:
        img = Image.eval(img, lambda v: int(v * master))
    return img


def ease(t):
    return 1 - (1 - t) ** 2


work = tempfile.mkdtemp()
parts = {"part0": [], "part1": [], "part2": []}
fade_in, fill_frames = 24, FPS * 12
for i in range(fade_in):
    parts["part0"].append(frame(0, logo_alpha=ease((i + 1) / fade_in)))
for i in range(fill_frames):
    parts["part0"].append(frame(HOLD * ease((i + 1) / fill_frames)))
for i in range(FPS * 2):
    parts["part1"].append(frame(HOLD, shimmer=i / (FPS * 2)))
finish = 18
for i in range(finish):
    parts["part2"].append(frame(HOLD + (1 - HOLD) * ease((i + 1) / finish)))
for i in range(12):
    parts["part2"].append(frame(1.0, master=1 - (i + 1) / 12))

for name, frames in parts.items():
    os.makedirs(os.path.join(work, name))
    for n, f in enumerate(frames):
        f.convert("P", palette=Image.ADAPTIVE, colors=64).save(os.path.join(work, name, f"{n:05d}.png"), optimize=True)

with open(os.path.join(work, "desc.txt"), "w") as fh:
    fh.write(f"{W} {H} {FPS}\n")
    fh.write("p 1 0 part0 #000000\n")
    fh.write("p 0 0 part1 #000000\n")
    fh.write("c 1 0 part2 #000000\n")

if os.path.exists(out_zip):
    os.remove(out_zip)
# Boot animations must be stored uncompressed.
subprocess.check_call(["zip", "-0qry", os.path.abspath(out_zip), "desc.txt", "part0", "part1", "part2"], cwd=work)
frame(HOLD * 0.6).save(os.path.splitext(out_zip)[0] + "_preview.png")
shutil.rmtree(work)
print("wrote", out_zip)
