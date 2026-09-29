"""Beep — the DriveUSA meme mascot, drawn in SVG. Original artwork, no third-party parts."""
import math

INK = '#0E1F4D'
BODY = '#3D79F0'
BODY_DARK = '#0048C3'
GLASS = '#D6E3FD'
WHITE = '#FFFFFF'
TYRE = '#1B2340'


def _eye(cx, cy, kind, look=(0, 0), lid=BODY_DARK):
    lx, ly = look
    s = [f'<circle cx="{cx}" cy="{cy}" r="21" fill="{WHITE}" stroke="{INK}" stroke-width="5"/>']
    if kind == 'normal':
        s.append(f'<circle cx="{cx+lx}" cy="{cy+ly}" r="9" fill="{INK}"/><circle cx="{cx+lx+3}" cy="{cy+ly-3}" r="3" fill="{WHITE}"/>')
    elif kind == 'wide':
        s.append(f'<circle cx="{cx+lx}" cy="{cy+ly}" r="5" fill="{INK}"/>')
    elif kind == 'sparkle':
        s.append(f'<circle cx="{cx+lx}" cy="{cy+ly}" r="13" fill="{INK}"/><circle cx="{cx+lx+4}" cy="{cy+ly-5}" r="4.5" fill="{WHITE}"/><circle cx="{cx+lx-5}" cy="{cy+ly+5}" r="2.2" fill="{WHITE}"/>')
    elif kind == 'happy':
        s.append(f'<path d="M{cx-11},{cy+5} Q{cx},{cy-11} {cx+11},{cy+5}" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>')
    elif kind == 'closed':
        s.append(f'<path d="M{cx-11},{cy-1} Q{cx},{cy+9} {cx+11},{cy-1}" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>')
    elif kind in ('tired', 'squint', 'smug'):
        py = {'tired': 6, 'squint': 2, 'smug': 3}[kind]
        s.append(f'<circle cx="{cx+lx}" cy="{cy+py+ly}" r="8" fill="{INK}"/>')
        top = {'tired': cy - 1, 'squint': cy - 5, 'smug': cy - 3}[kind]
        s.append(f'<path d="M{cx-22},{top} A22,22 0 0 1 {cx+22},{top} Z" fill="{lid}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
        if kind == 'squint':
            s.append(f'<path d="M{cx-22},{cy+10} A22,22 0 0 0 {cx+22},{cy+10} Z" fill="{lid}" stroke="{INK}" stroke-width="5"/>')
    elif kind == 'spiral':
        pts = []
        for i in range(60):
            a = i * 0.32
            r = 1 + i * 0.28
            pts.append(f'{cx + r*math.cos(a):.1f},{cy + r*math.sin(a):.1f}')
        s.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{INK}" stroke-width="3.2" stroke-linecap="round"/>')
    elif kind == 'star':
        s.append(_star(cx, cy, 14, 6, '#FFC53D', INK, 3))
    elif kind == 'x':
        s.append(f'<path d="M{cx-9},{cy-9} L{cx+9},{cy+9} M{cx+9},{cy-9} L{cx-9},{cy+9}" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>')
    return ''.join(s)


def _star(cx, cy, R, r, fill, stroke, sw):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = R if i % 2 == 0 else r
        pts.append(f'{cx + rr*math.cos(a):.1f},{cy + rr*math.sin(a):.1f}')
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>'


def _mouth(kind):
    k = {
        'smile': f'<path d="M84,146 Q100,161 116,146" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>',
        'grin': f'<path d="M78,143 Q100,172 122,143 Z" fill="{INK}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/><path d="M86,147 Q100,151 114,147" stroke="{WHITE}" stroke-width="4" fill="none" stroke-linecap="round"/><path d="M90,158 Q100,152 110,158 Q100,166 90,158 Z" fill="#FF7A8A"/>',
        'flat': f'<path d="M88,151 L112,151" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>',
        'wavy': f'<path d="M80,152 q5,-6 10,0 t10,0 t10,0 t10,0" fill="none" stroke="{INK}" stroke-width="4.5" stroke-linecap="round"/>',
        'o': f'<ellipse cx="100" cy="151" rx="7" ry="9" fill="{INK}"/>',
        'bigo': f'<ellipse cx="100" cy="152" rx="11" ry="13" fill="{INK}"/><ellipse cx="100" cy="158" rx="6" ry="4" fill="#FF7A8A"/>',
        'grimace': f'<rect x="80" y="142" width="40" height="18" rx="7" fill="{WHITE}" stroke="{INK}" stroke-width="4"/><path d="M80,151 H120 M90,142 V160 M100,142 V160 M110,142 V160" stroke="{INK}" stroke-width="2.5"/>',
        'frown': f'<path d="M86,156 Q100,142 114,156" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>',
        'smirk': f'<path d="M86,151 Q104,158 116,144" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>',
        'meh': f'<path d="M86,154 Q100,146 114,152" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>',
        'teeth': f'<path d="M80,144 Q100,166 120,144 Z" fill="{WHITE}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/><path d="M80,144 Q100,150 120,144" fill="none" stroke="{INK}" stroke-width="3"/>',
        'sleep': f'<ellipse cx="100" cy="152" rx="6" ry="5" fill="{INK}"/>',
        'tongue': f'<path d="M84,146 Q100,161 116,146" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/><path d="M104,153 q4,12 10,6 q2,-4 -2,-8" fill="#FF7A8A" stroke="{INK}" stroke-width="3"/>',
    }
    return k[kind]


def _brows(kind):
    if kind is None:
        return ''
    d = {
        'worried': 'M46,100 L76,94 M154,100 L124,94',
        'sad': 'M46,94 L74,101 M154,94 L126,101',
        'angry': 'M46,93 L76,101 M154,93 L124,101',
        'raised': 'M46,92 Q61,84 78,92 M122,92 Q139,84 154,92',
        'one': 'M46,99 L78,99 M122,92 Q139,82 154,92',
        'focus': 'M46,97 L78,100 M154,97 L122,100',
    }[kind]
    return f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'


def _hand(x, y, kind, flip=False):
    f = -1 if flip else 1
    if kind == 'thumb':
        # fist with knuckle lines and a short, tilted thumb on the inner side
        tx = x + 6 * f
        return (f'<g transform="rotate({-18*f} {tx} {y-14})"><rect x="{tx-6}" y="{y-30}" width="12" height="20" rx="6" fill="{WHITE}" stroke="{INK}" stroke-width="4"/></g>'
                f'<rect x="{x-14}" y="{y-11}" width="28" height="24" rx="9" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>'
                f'<path d="M{x-14},{y-3} H{x+8} M{x-14},{y+5} H{x+8}" stroke="{INK}" stroke-width="2.5"/>')
    if kind == 'point':
        return (f'<g transform="rotate({-55*f} {x} {y})"><rect x="{x-4}" y="{y-26}" width="8" height="18" rx="4" fill="{WHITE}" stroke="{INK}" stroke-width="4"/></g>'
                f'<circle cx="{x}" cy="{y}" r="11" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>')
    base = f'<circle cx="{x}" cy="{y}" r="11" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>'
    if kind == 'fist':
        return base + f'<path d="M{x-6},{y-3} h12 M{x-6},{y+3} h12" stroke="{INK}" stroke-width="2.5"/>'
    return base


ARMS = {
    # side: (end, ctrl, hand)
    'down': ((4, 162), (-2, 138), 'open'),
    'up': ((-14, 58), (-4, 96), 'open'),
    'out': ((-34, 112), (-8, 104), 'open'),
    'hip': ((30, 150), (-16, 132), 'open'),
    'wave': ((-24, 64), (-24, 108), 'open'),
    'flex': ((-8, 70), (-40, 118), 'fist'),
    'fistup': ((-18, 46), (-10, 92), 'fist'),
    'thumb': ((-30, 88), (-24, 124), 'thumb'),
    'shrug': ((-30, 100), (-6, 140), 'open'),
    'face': ((60, 116), (-14, 150), 'open'),
    'front': ((64, 150), (0, 160), 'open'),
    'temple': ((34, 86), (-30, 128), 'point'),
    'chin': ((66, 170), (4, 174), 'open'),
    'watch': ((70, 166), (-8, 168), 'open'),
    'side': ((-52, 126), (-20, 122), 'open'),
    'limp': ((-6, 176), (-10, 150), 'open'),
    'dabout': ((-52, 40), (-18, 80), 'open'),
    'dabin': ((62, 92), (150, 40), 'open'),
}


def _arm(name, right, prop=None):
    (ex, ey), (qx, qy), hand = ARMS[name]
    sx, sy = 20, 120
    if right:
        ex, qx, sx = 200 - ex, 200 - qx, 180
    s = f'<path d="M{sx},{sy} Q{qx},{qy} {ex},{ey}" fill="none" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>'
    s += _hand(ex, ey, hand, flip=right)
    if prop:
        s += prop(ex, ey)
    return s


def beep(x, y, scale=1.0, rot=0, eyes='normal', look=(0, 0), mouth='smile', brows=None,
         left='down', right='down', lprop=None, rprop=None, extras='', flat=False,
         blush=False, body=BODY, shades=False, squash=1.0, back_extras='', stone=False, hat=''):
    """Beep standing with its wheels on (x, y). Local box is 200×200, anchor bottom-centre."""
    sy = squash
    tyre_ry = 9 if flat else 16
    tyre_y = 184 if flat else 177
    g = [f'<g transform="translate({x},{y}) rotate({rot}) scale({scale},{scale*sy}) translate(-100,-196)">']
    g.append(back_extras)
    # antenna
    g.append(f'<path d="M126,36 Q132,14 140,4" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/><circle cx="141" cy="4" r="7" fill="#FF5A5F" stroke="{INK}" stroke-width="3.5"/>')
    # tyres
    for tx in (50, 150):
        if stone:
            g.append(f'<rect x="{tx-20}" y="160" width="40" height="36" rx="6" fill="#9C9486" stroke="{INK}" stroke-width="4"/><path d="M{tx-10},170 l8,6 M{tx+6},184 l6,-5" stroke="{INK}" stroke-width="2.5"/>')
            continue
        g.append(f'<ellipse cx="{tx}" cy="{tyre_y}" rx="{24 if flat else 20}" ry="{tyre_ry}" fill="{TYRE}" stroke="{INK}" stroke-width="4"/>')
        if not flat:
            g.append(f'<circle cx="{tx}" cy="{tyre_y}" r="7" fill="#9AA7C7"/>')
    # arms behind? drawn after body so hands overlap
    # cabin
    g.append(f'<path d="M50,98 L64,46 Q68,34 81,34 L119,34 Q132,34 136,46 L150,98 Z" fill="{body}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>')
    g.append(f'<path d="M64,94 L75,53 Q77,45 85,45 L115,45 Q123,45 125,53 L136,94 Z" fill="{GLASS}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>')
    g.append(f'<path d="M86,54 L77,86" stroke="{WHITE}" stroke-width="7" stroke-linecap="round" opacity="0.85"/>')
    # mirrors
    for mx in (22, 178):
        g.append(f'<ellipse cx="{mx}" cy="98" rx="11" ry="8" fill="{body}" stroke="{INK}" stroke-width="4"/>')
    # lower body
    g.append(f'<rect x="18" y="90" width="164" height="82" rx="32" fill="{body}" stroke="{INK}" stroke-width="6"/>')
    g.append(f'<path d="M24,148 Q100,170 176,148 L176,150 Q176,170 150,170 L50,170 Q24,170 24,150 Z" fill="{BODY_DARK}" opacity="0.35"/>')
    # bumper + plate
    g.append(f'<rect x="28" y="162" width="144" height="16" rx="8" fill="#E6EBF5" stroke="{INK}" stroke-width="4"/>')
    g.append(f'<rect x="84" y="163" width="32" height="13" rx="3" fill="{WHITE}" stroke="{INK}" stroke-width="2.5"/><path d="M90,169.5 H110" stroke="{BODY}" stroke-width="3" stroke-linecap="round"/>')
    # face
    g.append(_eye(62, 122, eyes, look))
    g.append(_eye(138, 122, eyes, look))
    if shades:
        g.append(f'<path d="M36,110 H164 V116 Q160,142 138,142 Q118,142 112,118 H88 Q82,142 62,142 Q40,142 36,116 Z" fill="{INK}"/><path d="M48,118 L60,118" stroke="{WHITE}" stroke-width="4" stroke-linecap="round" opacity="0.7"/><path d="M124,118 L136,118" stroke="{WHITE}" stroke-width="4" stroke-linecap="round" opacity="0.7"/>')
    g.append(_brows(brows))
    if blush:
        g.append('<ellipse cx="40" cy="146" rx="10" ry="6" fill="#FF7A8A" opacity="0.55"/><ellipse cx="160" cy="146" rx="10" ry="6" fill="#FF7A8A" opacity="0.55"/>')
    g.append(_mouth(mouth))
    g.append(_arm(left, False, lprop))
    g.append(_arm(right, True, rprop))
    g.append(hat)
    g.append(extras)
    g.append('</g>')
    return ''.join(g)


# ---- extras in Beep's local box ----
def sweat(x=172, y=62, s=1):
    return f'<path transform="translate({x},{y}) scale({s})" d="M0,-16 Q12,0 8,8 Q0,16 -8,8 Q-12,0 0,-16 Z" fill="#8FD3FF" stroke="{INK}" stroke-width="3"/>'


def zzz(x=160, y=20):
    return ''.join(f'<text x="{x + i*18}" y="{y - i*20}" font-family="Arial Black" font-weight="900" font-size="{24 + i*8}" fill="{INK}">Z</text>' for i in range(3))


def qmarks(pts=((-10, 40, 34), (190, 30, 44), (210, 90, 28))):
    return ''.join(f'<text x="{x}" y="{y}" font-family="Arial Black" font-weight="900" font-size="{s}" fill="{INK}" stroke="{WHITE}" stroke-width="2" paint-order="stroke">?</text>' for x, y, s in pts)


def sparkles(pts=((-20, 50, 12), (210, 40, 14), (196, 150, 9), (0, 150, 8))):
    return ''.join(_star(x, y, s, s * 0.38, '#FFE066', INK, 2.5) for x, y, s in pts)


def tear(x=52, y=142):
    return f'<path d="M{x},{y} Q{x+7},{y+12} {x},{y+18} Q{x-7},{y+12} {x},{y} Z" fill="#8FD3FF" stroke="{INK}" stroke-width="2.5"/>'


def watch(x, y):
    return (f'<rect x="{x-13}" y="{y-6}" width="26" height="12" rx="4" fill="#6B4A2B" stroke="{INK}" stroke-width="3"/>'
            f'<circle cx="{x}" cy="{y}" r="10" fill="{WHITE}" stroke="{INK}" stroke-width="3.5"/><path d="M{x},{y} V{y-6} M{x},{y} H{x+5}" stroke="{INK}" stroke-width="2.5" stroke-linecap="round"/>')


def glass(x, y):
    return (f'<path d="M{x-12},{y-40} L{x+12},{y-40} L{x+4},{y-18} L{x+4},{y-8} L{x+10},{y-4} L{x-10},{y-4} L{x-4},{y-8} L{x-4},{y-18} Z" fill="#FFF3C4" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
            f'<path d="M{x-9},{y-34} L{x+9},{y-34}" stroke="#FFC53D" stroke-width="5"/>')


def paper(x, y, w=46, h=58, mark=''):
    lines = ''.join(f'<path d="M{x-w/2+8},{y-h/2+14+i*10} H{x+w/2-8}" stroke="#9AA7C7" stroke-width="3"/>' for i in range(4))
    m = f'<text x="{x}" y="{y+h/2-8}" text-anchor="middle" font-family="Arial Black" font-weight="900" font-size="22" fill="#C1272D">{mark}</text>' if mark else ''
    return f'<rect x="{x-w/2}" y="{y-h/2}" width="{w}" height="{h}" rx="4" fill="{WHITE}" stroke="{INK}" stroke-width="3.5"/>' + lines + m
