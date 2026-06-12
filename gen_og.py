from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

W, H = 1200, 630
img = Image.new('RGB', (W, H), '#0A0E1A')

# Gold orb bottom-left
orb1 = Image.new('RGB', (W, H), '#0A0E1A')
ImageDraw.Draw(orb1).ellipse([-240, 390, 300, 930], fill=(200, 148, 42))
img = Image.blend(img, orb1.filter(ImageFilter.GaussianBlur(80)), 0.10)

# Blue orb top-right
orb2 = Image.new('RGB', (W, H), '#0A0E1A')
ImageDraw.Draw(orb2).ellipse([620, -120, 1620, 880], fill=(26, 42, 94))
img = Image.blend(img, orb2.filter(ImageFilter.GaussianBlur(80)), 0.18)

draw = ImageDraw.Draw(img)

# Border frame
draw.rectangle([28, 28, W - 28, H - 28], outline=(200, 148, 42), width=1)


def get_font(size, bold=False):
    candidates = [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    ]
    for c in candidates:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


def get_font_italic(size):
    candidates = [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf',
    ]
    for c in candidates:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return get_font(size)


GOLD = (200, 148, 42)
WHITE = (245, 240, 228)
GRAY = (155, 168, 200)
DIM = (106, 112, 144)
X = 96
STATS_RIGHT = W - X  # 1104

# ── Logo ──────────────────────────────────────────────────────────────────
coin_x, coin_y = X, 90
draw.ellipse([coin_x, coin_y, coin_x + 50, coin_y + 50], outline=(180, 135, 38), width=1)
draw.text((coin_x + 16, coin_y + 12), 'L', font=get_font_italic(24), fill=GOLD)

f_wm = get_font(32, bold=True)
lan_w = int(draw.textlength('lan', font=f_wm))
draw.text((coin_x + 62, coin_y + 10), 'lan', font=f_wm, fill=(255, 255, 255))
draw.text((coin_x + 62 + lan_w, coin_y + 10), 'vivo', font=f_wm, fill=GOLD)

# ── Headline ──────────────────────────────────────────────────────────────
f_h = get_font(50, bold=True)
f_hi = get_font_italic(48)
draw.text((X, 172), 'US real estate,', font=f_h, fill=WHITE)
draw.text((X, 228), 'built for the one', font=f_hi, fill=GOLD)
draw.text((X, 284), 'who crossed borders.', font=f_h, fill=WHITE)

# ── Sub copy ──────────────────────────────────────────────────────────────
f_sub = get_font(18)
draw.text((X, 358), 'Visa-aware mortgage eligibility · Cash flow analysis', font=f_sub, fill=GRAY)
draw.text((X, 384), 'Shareable reports · Free during beta', font=f_sub, fill=GRAY)

# ── Pills ─────────────────────────────────────────────────────────────────
f_pill = get_font(13)
pills = ['H-1B & work visas', 'ITIN buyers', 'Foreign nationals', 'F-1 / OPT']
px = X
for pill in pills:
    tw = draw.textlength(pill, font=f_pill)
    pw = tw + 24
    draw.rounded_rectangle([px, 432, px + pw, 462], radius=15, outline=GOLD, width=1)
    draw.text((px + 12, 440), pill, font=f_pill, fill=GOLD)
    px += pw + 10

# ── Stats ─────────────────────────────────────────────────────────────────
f_sn = get_font(34, bold=True)
f_sl = get_font(11)

stats = [
    ('45M+', 'IMMIGRANTS IN THE US'),
    ('8M+', 'WORK VISA HOLDERS'),
    ('$15B+', 'FOREIGN PURCHASES / YR'),  # dollar sign safe inside Python string
]

sy = H // 2 - 90
for i, (num, label) in enumerate(stats):
    nw = int(draw.textlength(num, font=f_sn))
    lw = int(draw.textlength(label, font=f_sl))
    draw.text((STATS_RIGHT - nw, sy), num, font=f_sn, fill=GOLD)
    draw.text((STATS_RIGHT - lw, sy + 44), label, font=f_sl, fill=DIM)
    if i < 2:
        divider_x = STATS_RIGHT - max(nw, lw)
        draw.line([(divider_x, sy + 96), (STATS_RIGHT, sy + 96)], fill=(180, 130, 35), width=1)
    sy += 120

# ── Domain badge ──────────────────────────────────────────────────────────
f_dom = get_font(13)
dw = int(draw.textlength('lanvivo.com', font=f_dom))
draw.text((STATS_RIGHT - dw, H - 52), 'lanvivo.com', font=f_dom, fill=DIM)

# ── Save ──────────────────────────────────────────────────────────────────
out = '/sessions/zen-dreamy-gauss/mnt/outputs/og-image.png'
img.save(out, 'PNG', optimize=True)
print('Saved:', out, '|', os.path.getsize(out), 'bytes')
