"""Scene helpers: backgrounds, SVG → PNG, meme captions (Anton, OFL)."""
import io, os, random
import cairosvg
from PIL import Image, ImageDraw, ImageFont
from beep import *

W, H = 1024, 768
HERE = os.path.dirname(os.path.abspath(__file__))
ANTON = os.path.join(HERE, 'Anton-Regular.ttf')


def svg(*parts, bg='#EBF1FE'):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<rect width="{W}" height="{H}" fill="{bg}"/>' + ''.join(parts) + '</svg>')


def render(s, scale=2):
    png = cairosvg.svg2png(bytestring=s.encode(), output_width=W * scale, output_height=H * scale)
    return Image.open(io.BytesIO(png)).convert('RGB').resize((W, H), Image.LANCZOS)


def caption(im, top='', bottom=''):
    d = ImageDraw.Draw(im)
    for text, is_top in ((top, True), (bottom, False)):
        if not text:
            continue
        size = 96
        while size > 30:
            f = ImageFont.truetype(ANTON, size)
            if d.textlength(text, font=f) <= W * 0.92:
                break
            size -= 4
        tw = d.textlength(text, font=f)
        asc, desc = f.getmetrics()
        y = 18 if is_top else H - 22 - asc - desc
        d.text(((W - tw) / 2, y), text, font=f, fill='white', stroke_width=max(4, size // 12), stroke_fill='black')
    return im


# ---- backgrounds ----
def sky(top='#8EC5FF', bottom='#EAF4FF'):
    return (f'<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{bottom}"/></linearGradient></defs><rect width="{W}" height="{H}" fill="url(#sky)"/>')


def ground(y=600, color='#9BD37A', edge='#6FB24F'):
    return f'<path d="M0,{y} Q{W/2},{y-24} {W},{y} V{H} H0 Z" fill="{color}"/><path d="M0,{y} Q{W/2},{y-24} {W},{y}" fill="none" stroke="{edge}" stroke-width="6"/>'


def road(y=640):
    dashes = ''.join(f'<rect x="{x}" y="{y+52}" width="70" height="12" rx="6" fill="#FFFFFF"/>' for x in range(20, W, 140))
    return f'<rect x="0" y="{y}" width="{W}" height="{H-y}" fill="#5B6478"/>' + dashes


def flower_field(y=430, seed=3):
    rnd = random.Random(seed)
    s = [f'<rect x="0" y="{y}" width="{W}" height="{H-y}" fill="#7DAA3C"/>']
    for _ in range(900):
        fx, fy = rnd.uniform(0, W), rnd.uniform(y, H)
        r = 2 + (fy - y) / (H - y) * 9
        s.append(f'<circle cx="{fx:.0f}" cy="{fy:.0f}" r="{r:.1f}" fill="{rnd.choice(["#F7D23B", "#F2C400", "#FFE36E"])}"/>')
    return ''.join(s)


def clouds(pts=((150, 110, 1), (720, 80, 1.3), (900, 170, 0.8))):
    return ''.join(f'<g transform="translate({x},{y}) scale({s})" fill="#FFFFFF" opacity="0.95"><ellipse cx="0" cy="0" rx="70" ry="30"/>'
                   f'<ellipse cx="-40" cy="10" rx="45" ry="24"/><ellipse cx="45" cy="8" rx="50" ry="26"/></g>' for x, y, s in pts)


def rainbow(cx=512, cy=700, r=520):
    cols = ['#FF5A5F', '#FF9F43', '#FFD93D', '#6BCB77', '#4D96FF', '#9B5DE5']
    return ''.join(f'<path d="M{cx-r+i*34},{cy} A{r-i*34},{r-i*34} 0 0 1 {cx+r-i*34},{cy}" fill="none" stroke="{c}" stroke-width="36"/>' for i, c in enumerate(cols))


def rays(cx=512, cy=420, n=18, c1='#FFE08A', c2='#FFF2C4'):
    s = [f'<rect width="{W}" height="{H}" fill="{c2}"/>']
    import math
    for i in range(n):
        a0, a1 = i * 2 * math.pi / n, (i + 0.5) * 2 * math.pi / n
        s.append(f'<path d="M{cx},{cy} L{cx+1500*math.cos(a0):.0f},{cy+1500*math.sin(a0):.0f} L{cx+1500*math.cos(a1):.0f},{cy+1500*math.sin(a1):.0f} Z" fill="{c1}"/>')
    return ''.join(s)


def room(wall='#F4EFE6', floor='#D9C7A8', y=560):
    return f'<rect width="{W}" height="{y}" fill="{wall}"/><rect y="{y}" width="{W}" height="{H-y}" fill="{floor}"/><path d="M0,{y} H{W}" stroke="#BFA886" stroke-width="6"/>'


def ghost(fn, offsets, opacity=0.28):
    """Motion-blur look without filters: faded copies of a group."""
    return ''.join(f'<g opacity="{opacity}" transform="translate({dx},{dy})">{fn()}</g>' for dx, dy in offsets)
