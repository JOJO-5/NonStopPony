"""
Generate Android ic_launcher PNG assets from SVG using Pillow + draw.
Run: python scripts/gen_icons.py
"""
import os
import math
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

SIZES = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

BG        = (26, 10, 6)       # #1A0A06
DARK      = (44, 18, 8)       # #2C1208
ACCENT    = (232, 147, 106)   # #E8936A
WHITE     = (255, 255, 255)
GLOW      = (61, 26, 8)       # #3D1A08


def draw_icon(size: int) -> Image.Image:
    img = Image.new('RGBA', (size, size), (*BG, 255))
    d = ImageDraw.Draw(img)

    cx = cy = size / 2
    r_clock = size * 0.29          # clock face radius
    r_outer = size * 0.292         # stroke outer ring
    knob_r  = size * 0.051         # alarm bell top knobs
    knob_y  = size * 0.185

    # Warm glow
    glow_r = int(size * 0.33)
    glow_box = [cx - glow_r, cy * 1.07 - glow_r, cx + glow_r, cy * 1.07 + glow_r]
    d.ellipse(glow_box, fill=(*GLOW, 180))

    # Bell top knobs
    kr = int(knob_r)
    d.ellipse([cx - size*0.16 - kr, knob_y - kr, cx - size*0.16 + kr, knob_y + kr], fill=ACCENT)
    d.ellipse([cx + size*0.16 - kr, knob_y - kr, cx + size*0.16 + kr, knob_y + kr], fill=ACCENT)
    # Connector bar
    bar_h = kr
    d.rounded_rectangle(
        [cx - size*0.13, knob_y - bar_h, cx + size*0.13, knob_y + bar_h],
        radius=bar_h, fill=ACCENT)

    # Clock face
    rc = int(r_clock)
    d.ellipse([cx-rc, cy-rc, cx+rc, cy+rc], fill=DARK, outline=(*ACCENT, 255), width=max(2, size//56))

    # Inner decorative ring
    ri = int(r_clock * 0.9)
    d.ellipse([cx-ri, cy-ri, cx+ri, cy+ri], fill=None, outline=(*ACCENT, 90), width=max(1, size//128))

    # Tick marks
    tick_len_maj = size * 0.04
    tick_len_min = size * 0.02
    tick_w_maj = max(2, size // 56)
    tick_w_min = max(1, size // 96)
    for i in range(12):
        angle = math.radians(i * 30 - 90)
        is_major = True
        tl = tick_len_maj if is_major else tick_len_min
        tw = tick_w_maj if is_major else tick_w_min
        ox = cx + rc * math.cos(angle)
        oy = cy + rc * math.sin(angle)
        ix = cx + (rc - tl) * math.cos(angle)
        iy = cy + (rc - tl) * math.sin(angle)
        d.line([ix, iy, ox, oy], fill=ACCENT, width=tw)

    # Minor ticks (30 in total but we'll do all 60 with 2 widths)
    for i in range(60):
        if i % 5 == 0:
            continue
        angle = math.radians(i * 6 - 90)
        tl = tick_len_min
        tw = max(1, size // 192)
        ox = cx + rc * math.cos(angle)
        oy = cy + rc * math.sin(angle)
        ix = cx + (rc - tl) * math.cos(angle)
        iy = cy + (rc - tl) * math.sin(angle)
        d.line([ix, iy, ox, oy], fill=(*ACCENT, 100), width=tw)

    # Hour hand (~10 o'clock = -60 degrees from 12)
    h_len = rc * 0.55
    h_angle = math.radians(-60 - 90)
    d.line([cx, cy, cx + h_len * math.cos(h_angle), cy + h_len * math.sin(h_angle)],
           fill=WHITE, width=max(3, size // 38))

    # Minute hand (~2 o'clock = 60 degrees from 12)
    m_len = rc * 0.72
    m_angle = math.radians(60 - 90)
    d.line([cx, cy, cx + m_len * math.cos(m_angle), cy + m_len * math.sin(m_angle)],
           fill=WHITE, width=max(2, size // 48))

    # Second hand (~7 o'clock direction for visual balance)
    s_len = rc * 0.75
    s_angle = math.radians(150 - 90)
    d.line([cx, cy, cx + s_len * math.cos(s_angle), cy + s_len * math.sin(s_angle)],
           fill=ACCENT, width=max(1, size // 72))

    # Center cap
    cap_r = max(4, size // 32)
    d.ellipse([cx - cap_r, cy - cap_r, cx + cap_r, cy + cap_r], fill=ACCENT)
    inner_r = max(2, cap_r // 2)
    d.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=DARK)

    # Clapper
    clapper_y = cy + rc + size * 0.025
    clapper_rx, clapper_ry = size * 0.044, size * 0.022
    d.ellipse([cx - clapper_rx, clapper_y - clapper_ry,
               cx + clapper_rx, clapper_y + clapper_ry], fill=ACCENT)

    return img.convert('RGBA')


def main():
    for folder, size in SIZES.items():
        out_dir = os.path.join(ANDROID_RES, folder)
        os.makedirs(out_dir, exist_ok=True)
        img = draw_icon(size)
        out = os.path.join(out_dir, 'ic_launcher.png')
        img.save(out, 'PNG')
        print(f'  saved {out} ({size}x{size})')

        # Round icon variant
        out_round = os.path.join(out_dir, 'ic_launcher_round.png')
        # Apply circular mask for round icon
        mask = Image.new('L', (size, size), 0)
        dm = ImageDraw.Draw(mask)
        dm.ellipse([0, 0, size, size], fill=255)
        img_round = img.copy()
        img_round.putalpha(mask)
        img_round.save(out_round, 'PNG')
        print(f'  saved {out_round} (round)')


if __name__ == '__main__':
    main()
    print('\nAll icons generated successfully!')
