"""Makes the test photos of "من صورة" (sketch of the orchard on paper):
mobile_app/test/sketches/*.jpg + truth.json (the true outline of each, as parts
of the sheet's width and height). SYNTHETIC photos: paper, a black felt-tip line
that wobbles like a hand, JPEG noise. Real phone photos go in test/sketches/real/.

    python tool/make_sketch_photos.py        (needs Pillow: pip install pillow)
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'test', 'sketches')
PAGE = (840, 1188)        # an A4 sheet (pixels)
PHOTO = (1200, 1600)      # the phone photo


def font(size):
    for name in ('segoepr.ttf', 'comic.ttf', 'arial.ttf', 'DejaVuSans.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def paper(squared=False, seed=0):
    rnd = random.Random(seed)
    page = Image.new('RGB', PAGE, (246, 244, 237))
    px = page.load()
    for _ in range(9000):  # paper grain
        x, y = rnd.randrange(PAGE[0]), rnd.randrange(PAGE[1])
        g = rnd.randint(-10, 6)
        r, gg, b = px[x, y]
        px[x, y] = (r + g, gg + g, b + g)
    if squared:  # light blue squares (5 mm)
        d = ImageDraw.Draw(page)
        for x in range(0, PAGE[0], 24):
            d.line([(x, 0), (x, PAGE[1])], fill=(168, 198, 232), width=2)
        for y in range(0, PAGE[1], 24):
            d.line([(0, y), (PAGE[0], y)], fill=(168, 198, 232), width=2)
    return page


def hand_line(draw, pts, rnd, width=8, color=(28, 28, 34), close=True, overlap=18):
    """A felt-tip line through pts that wobbles a little, like a hand."""
    seq = pts + [pts[0]] if close else pts
    path = []
    for a, b in zip(seq, seq[1:]):
        length = math.dist(a, b)
        n = max(2, int(length / 6))
        nx, ny = (b[1] - a[1]) / length, -(b[0] - a[0]) / length
        phase, amp = rnd.uniform(0, 6.3), rnd.uniform(1.0, 2.6)
        for k in range(n + 1):
            t = k / n
            off = amp * math.sin(phase + t * rnd.uniform(5, 9)) * math.sin(math.pi * t)
            path.append((a[0] + (b[0] - a[0]) * t + nx * off, a[1] + (b[1] - a[1]) * t + ny * off))
    if close:  # the pen goes a bit past the start (no gap)
        a, b = seq[0], seq[1]
        length = math.dist(a, b)
        path.append((a[0] + (b[0] - a[0]) * overlap / length, a[1] + (b[1] - a[1]) * overlap / length))
    for p, q in zip(path, path[1:]):
        draw.line([p, q], fill=color, width=width + rnd.choice((-1, 0, 0, 1)))
        draw.ellipse([q[0] - width / 2, q[1] - width / 2, q[0] + width / 2, q[1] + width / 2], fill=color)


def to_page(poly):
    return [(x * PAGE[0], y * PAGE[1]) for x, y in poly]


def table(seed=1):
    rnd = random.Random(seed)
    img = Image.new('RGB', PHOTO, (96, 66, 44))
    d = ImageDraw.Draw(img)
    for y in range(0, PHOTO[1], 3):  # wood streaks
        g = rnd.randint(-14, 14)
        d.line([(0, y), (PHOTO[0], y + rnd.randint(-6, 6))], fill=(96 + g, 66 + g, 44 + g), width=3)
    return img.filter(ImageFilter.GaussianBlur(1.2))


def solve(a, b):
    n = len(b)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for c in range(n):
        p = max(range(c, n), key=lambda r: abs(m[r][c]))
        m[c], m[p] = m[p], m[c]
        for r in range(n):
            if r != c:
                f = m[r][c] / m[c][c]
                m[r] = [x - f * y for x, y in zip(m[r], m[c])]
    return [m[i][n] / m[i][i] for i in range(n)]


def place(page, corners, background):
    """The sheet put on the photo with its 4 corners at `corners` (TL, TR, BR, BL)."""
    src = [(0, 0), (PAGE[0], 0), (PAGE[0], PAGE[1]), (0, PAGE[1])]
    a, b = [], []
    for (x, y), (u, v) in zip(corners, src):  # photo (x, y) -> page (u, v)
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); b.append(u)
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y]); b.append(v)
    coeffs = solve(a, b)
    warped = page.transform(PHOTO, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    mask = Image.new('L', PAGE, 255).transform(PHOTO, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    out = background.copy()
    out.paste(warped, (0, 0), mask)
    return out


def rect_corners(cx, cy, w, h, deg):
    t = math.radians(deg)
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    return [(cx + x * math.cos(t) - y * math.sin(t), cy + x * math.sin(t) + y * math.cos(t)) for x, y in pts]


def shade(img, seed=3):
    """A soft shadow over the left part (a person or the phone) + darker corners."""
    w, h = img.size
    sh = Image.new('L', img.size, 255)
    d = ImageDraw.Draw(sh)
    d.polygon([(0, 0), (int(w * 0.55), 0), (int(w * 0.32), h), (0, h)], fill=120)
    sh = sh.filter(ImageFilter.GaussianBlur(60))
    black = Image.new('RGB', img.size, (0, 0, 0))
    return Image.composite(img, black, sh)


def noise(img, seed):
    rnd = random.Random(seed)
    px = img.load()
    w, h = img.size
    for _ in range(w * h // 25):
        x, y = rnd.randrange(w), rnd.randrange(h)
        r, g, b = px[x, y]
        k = rnd.randint(-8, 8)
        px[x, y] = (max(0, min(255, r + k)), max(0, min(255, g + k)), max(0, min(255, b + k)))
    return img.filter(ImageFilter.GaussianBlur(0.6))


OUTLINES = {
    'clean':   [(0.18, 0.20), (0.80, 0.17), (0.84, 0.55), (0.70, 0.80), (0.22, 0.82), (0.10, 0.50)],
    'shadow':  [(0.16, 0.22), (0.82, 0.22), (0.82, 0.78), (0.16, 0.78)],
    'numbers': [(0.20, 0.25), (0.78, 0.20), (0.85, 0.72), (0.45, 0.85), (0.14, 0.66)],
    'angle':   [(0.20, 0.18), (0.82, 0.24), (0.76, 0.80), (0.18, 0.74)],
    'squared': [(0.16, 0.20), (0.62, 0.16), (0.84, 0.40), (0.80, 0.80), (0.20, 0.82)],
    'tilted':  [(0.22, 0.25), (0.78, 0.25), (0.78, 0.72), (0.22, 0.72)],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    truth = {}
    for i, (name, poly) in enumerate(OUTLINES.items()):
        rnd = random.Random(10 + i)
        page = paper(squared=(name == 'squared'), seed=i)
        d = ImageDraw.Draw(page)
        pts = to_page(poly)
        if name == 'tilted':  # the drawing itself turned 9 degrees on the sheet
            cx, cy = PAGE[0] / 2, PAGE[1] / 2
            t = math.radians(9)
            pts = [(cx + (x - cx) * math.cos(t) - (y - cy) * math.sin(t),
                    cy + (x - cx) * math.sin(t) + (y - cy) * math.cos(t)) for x, y in pts]
        hand_line(d, pts, rnd)
        if name == 'numbers':  # numbers, words, trees, a zone line inside; a title outside
            f = font(46)
            for text, (x, y) in [('12', (0.35, 0.38)), ('45 m', (0.52, 0.60)), ('N', (0.62, 0.32))]:
                d.text((x * PAGE[0], y * PAGE[1]), text, fill=(30, 30, 36), font=f)
            for (x, y) in [(0.30, 0.55), (0.40, 0.70), (0.66, 0.45), (0.70, 0.62)]:
                cx, cy = x * PAGE[0], y * PAGE[1]
                d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], outline=(30, 30, 36), width=5)
            hand_line(d, [(0.49 * PAGE[0], 0.226 * PAGE[1]), (0.45 * PAGE[0], 0.85 * PAGE[1])], rnd,
                      width=6, close=False)
            d.text((0.30 * PAGE[0], 0.07 * PAGE[1]), 'Mon verger', fill=(30, 30, 36), font=font(60))
        if name == 'no_shape':
            pass
        if name == 'clean':
            photo = place(page, rect_corners(600, 800, 1000, 1414, 2), table(1))
        elif name == 'shadow':
            photo = shade(place(page, rect_corners(600, 800, 980, 1386, -1.5), table(2)))
        elif name == 'numbers':
            photo = place(page, rect_corners(600, 805, 990, 1400, 1), table(3))
        elif name == 'angle':  # turned 12 degrees AND taken at an angle (top farther)
            photo = place(page, [(330, 190), (1000, 330), (1110, 1490), (150, 1330)], table(4))
        else:  # squared, tilted: the sheet fills the whole photo (no corners)
            photo = page.resize((PHOTO[0] + 160, int((PHOTO[0] + 160) * PAGE[1] / PAGE[0])))
            photo = photo.crop((80, 60, 80 + PHOTO[0], 60 + PHOTO[1]))
        photo = noise(photo, 20 + i)
        photo.save(os.path.join(OUT, f'{name}.jpg'), quality=82)
        truth[name] = {'outline': poly, 'tilt_degrees': 9 if name == 'tilted' else 0}

    # A photo WITHOUT a closed shape: an open line and some words.
    rnd = random.Random(99)
    page = paper(seed=99)
    d = ImageDraw.Draw(page)
    hand_line(d, to_page([(0.2, 0.25), (0.2, 0.75), (0.8, 0.75), (0.8, 0.25)]), rnd, close=False)
    d.text((0.25 * PAGE[0], 0.12 * PAGE[1]), 'Mon verger ?', fill=(30, 30, 36), font=font(60))
    photo = noise(place(page, rect_corners(600, 800, 1000, 1414, 0.5), table(9)), 99)
    photo.save(os.path.join(OUT, 'no_shape.jpg'), quality=82)
    truth['no_shape'] = {'outline': None, 'tilt_degrees': 0}

    with open(os.path.join(OUT, 'truth.json'), 'w', encoding='utf-8') as f:
        json.dump(truth, f, indent=1)
    print('written to', os.path.normpath(OUT))


if __name__ == '__main__':
    main()
