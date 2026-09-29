"""Scene props in canvas coordinates (1024×768) unless noted. Original drawings."""
import math
from beep import INK, WHITE, BODY, BODY_DARK, _star

F = 'font-family="Arial Black" font-weight="900"'


def fire(x, y, s=1.0):
    return (f'<g transform="translate({x},{y}) scale({s})">'
            f'<path d="M0,0 C-40,-10 -46,-60 -20,-90 C-18,-60 0,-58 4,-80 C10,-110 30,-120 26,-150 C60,-120 70,-70 50,-40 C58,-50 66,-60 64,-76 C84,-50 80,-10 40,0 Z" fill="#FF7A1A" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
            f'<path d="M6,-4 C-14,-12 -16,-40 0,-56 C4,-40 14,-42 16,-58 C34,-40 36,-14 20,-4 Z" fill="#FFD23F"/></g>')


def mug(x, y, s=1.0):
    return (f'<g transform="translate({x},{y}) scale({s})"><rect x="-22" y="-44" width="44" height="44" rx="6" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>'
            f'<path d="M22,-34 q18,0 18,14 q0,14 -18,14" fill="none" stroke="{INK}" stroke-width="4"/>'
            f'<path d="M-8,-56 q-6,-10 0,-18 M6,-56 q-6,-10 0,-18" fill="none" stroke="#9AA7C7" stroke-width="3" stroke-linecap="round"/></g>')


def cone(x, y, s=1.0):
    return (f'<g transform="translate({x},{y}) scale({s})"><path d="M-10,-70 L10,-70 L30,0 L-30,0 Z" fill="#FF8A1F" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
            f'<path d="M-17,-38 L17,-38 L21,-24 L-21,-24 Z" fill="{WHITE}"/><rect x="-40" y="-6" width="80" height="12" rx="4" fill="#FF8A1F" stroke="{INK}" stroke-width="4"/></g>')


def book(x, y, s=1.0, color='#FF5A5F', title=''):
    t = f'<text x="0" y="-8" text-anchor="middle" {F} font-size="12" fill="{WHITE}">{title}</text>' if title else ''
    return (f'<g transform="translate({x},{y}) scale({s})"><rect x="-34" y="-46" width="68" height="46" rx="5" fill="{color}" stroke="{INK}" stroke-width="4"/>'
            f'<rect x="-30" y="-6" width="60" height="6" fill="{WHITE}" stroke="{INK}" stroke-width="2"/>{t}</g>')


def signpost(x, y, text, s=1.0, color='#0F7A3D'):
    return (f'<g transform="translate({x},{y}) scale({s})"><rect x="-6" y="-170" width="12" height="170" fill="#8A6A45" stroke="{INK}" stroke-width="4"/>'
            f'<path d="M-90,-200 H80 L110,-172 L80,-144 H-90 Z" fill="{color}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>'
            f'<text x="0" y="-160" text-anchor="middle" {F} font-size="30" fill="{WHITE}">{text}</text></g>')


def bed(x, y, w=620):
    return (f'<g transform="translate({x},{y})"><rect x="{-w/2}" y="-60" width="{w}" height="80" rx="18" fill="#8A6A45" stroke="{INK}" stroke-width="5"/>'
            f'<rect x="{-w/2-20}" y="-170" width="40" height="190" rx="12" fill="#8A6A45" stroke="{INK}" stroke-width="5"/>'
            f'<rect x="{-w/2+30}" y="-110" width="150" height="60" rx="26" fill="{WHITE}" stroke="{INK}" stroke-width="5"/></g>')


def blanket(x, y, w=460):
    return f'<path d="M{x-w/2},{y} Q{x-w/2},{y-110} {x-w/2+60},{y-120} L{x+w/2-20},{y-120} Q{x+w/2+10},{y-60} {x+w/2},{y} Z" fill="#FFB3C1" stroke="{INK}" stroke-width="5"/><path d="M{x-w/2+50},{y-80} h{w-120} M{x-w/2+40},{y-40} h{w-100}" stroke="#FF8FA6" stroke-width="6" stroke-linecap="round"/>'


def laptop(x, y, s=1.0, screen='#EBF1FE'):
    return (f'<g transform="translate({x},{y}) scale({s})"><rect x="-120" y="-170" width="240" height="150" rx="12" fill="#C9D2E3" stroke="{INK}" stroke-width="5"/>'
            f'<rect x="-104" y="-156" width="208" height="122" rx="6" fill="{screen}" stroke="{INK}" stroke-width="3"/>'
            + ''.join(f'<path d="M-86,{-136+i*22} H{40-i*18}" stroke="#C1272D" stroke-width="7" stroke-linecap="round"/><path d="M60,{-142+i*22} l12,12 m0,-12 l-12,12" stroke="#C1272D" stroke-width="5" stroke-linecap="round"/>' for i in range(4))
            + f'<path d="M-150,-20 H150 L136,0 H-136 Z" fill="#AEB8CC" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/></g>')


def window_frame(x, y, w, h):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{min(w,h)/2}" fill="#BFE3FF" stroke="{INK}" stroke-width="10"/>'
            f'<path d="M{x+w/2},{y} V{y+h} M{x},{y+h/2} H{x+w}" stroke="{INK}" stroke-width="8"/>')


def banner(x, y, text, color='#0F7A3D', s=1.0):
    return (f'<g transform="translate({x},{y}) scale({s})"><rect x="-110" y="-36" width="220" height="72" rx="36" fill="{color}" stroke="{INK}" stroke-width="5"/>'
            f'<text x="0" y="16" text-anchor="middle" {F} font-size="40" fill="{WHITE}">{text}</text></g>')


def thought(x, y, inner, w=300, h=190):
    return (f'<circle cx="{x-w/2+30}" cy="{y+h/2+40}" r="14" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>'
            f'<circle cx="{x-w/2+60}" cy="{y+h/2+10}" r="20" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>'
            f'<ellipse cx="{x}" cy="{y}" rx="{w/2}" ry="{h/2}" fill="{WHITE}" stroke="{INK}" stroke-width="5"/>' + inner)


def license_card(x, y, s=1.0, rot=0):
    return (f'<g transform="translate({x},{y}) rotate({rot}) scale({s})"><rect x="-90" y="-56" width="180" height="112" rx="14" fill="{WHITE}" stroke="{INK}" stroke-width="5"/>'
            f'<rect x="-90" y="-56" width="180" height="30" rx="14" fill="{BODY}" stroke="{INK}" stroke-width="5"/><rect x="-86" y="-40" width="172" height="14" fill="{BODY}"/>'
            f'<text x="0" y="-33" text-anchor="middle" {F} font-size="16" fill="{WHITE}">DRIVER LICENSE</text>'
            f'<rect x="-76" y="-14" width="52" height="58" rx="8" fill="#D6E3FD" stroke="{INK}" stroke-width="3"/><circle cx="-50" cy="8" r="12" fill="{BODY}"/>'
            f'<path d="M-10,-2 H70 M-10,18 H56 M-10,36 H64" stroke="#9AA7C7" stroke-width="7" stroke-linecap="round"/></g>')


def building(x, y, text='DMV'):
    return (f'<g transform="translate({x},{y})"><rect x="-190" y="-230" width="380" height="230" fill="#F4EFE6" stroke="{INK}" stroke-width="6"/>'
            f'<path d="M-215,-230 L0,-320 L215,-230 Z" fill="#C9D2E3" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
            + ''.join(f'<rect x="{cx-14}" y="-200" width="28" height="200" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>' for cx in (-150, -90, 90, 150))
            + f'<rect x="-50" y="-120" width="100" height="120" fill="#8A6A45" stroke="{INK}" stroke-width="5"/>'
            f'<text x="0" y="-252" text-anchor="middle" {F} font-size="40" fill="{INK}">{text}</text></g>')


def hourglass(x, y, s=1.0, sand_top=0.0):
    return (f'<g transform="translate({x},{y}) scale({s})"><rect x="-60" y="-180" width="120" height="16" rx="6" fill="#8A6A45" stroke="{INK}" stroke-width="4"/>'
            f'<rect x="-60" y="-16" width="120" height="16" rx="6" fill="#8A6A45" stroke="{INK}" stroke-width="4"/>'
            f'<path d="M-46,-164 H46 Q46,-110 6,-90 Q46,-70 46,-16 H-46 Q-46,-70 -6,-90 Q-46,-110 -46,-164 Z" fill="#E8F4FF" stroke="{INK}" stroke-width="4"/>'
            f'<path d="M-40,-16 Q0,-60 40,-16 Z" fill="#F2C400"/></g>')


def wall_clock(x, y, r=70, hh=0, mm=0):
    ah = math.radians(hh * 30 + mm * 0.5 - 90)
    am = math.radians(mm * 6 - 90)
    ticks = ''.join(f'<path d="M{x+(r-10)*math.cos(math.radians(i*30)):.1f},{y+(r-10)*math.sin(math.radians(i*30)):.1f} L{x+(r-2)*math.cos(math.radians(i*30)):.1f},{y+(r-2)*math.sin(math.radians(i*30)):.1f}" stroke="{INK}" stroke-width="4"/>' for i in range(12))
    return (f'<circle cx="{x}" cy="{y}" r="{r+8}" fill="#8A6A45" stroke="{INK}" stroke-width="5"/><circle cx="{x}" cy="{y}" r="{r}" fill="{WHITE}" stroke="{INK}" stroke-width="4"/>' + ticks +
            f'<path d="M{x},{y} L{x+r*0.5*math.cos(ah):.1f},{y+r*0.5*math.sin(ah):.1f}" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
            f'<path d="M{x},{y} L{x+r*0.78*math.cos(am):.1f},{y+r*0.78*math.sin(am):.1f}" stroke="#C1272D" stroke-width="5" stroke-linecap="round"/><circle cx="{x}" cy="{y}" r="6" fill="{INK}"/>')


def alarm_clock(x, y, s=1.0, rot=0):
    return (f'<g transform="translate({x},{y}) rotate({rot}) scale({s})"><path d="M-30,30 l-12,16 M30,30 l12,16" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
            f'<circle cx="-30" cy="-36" r="16" fill="#FFC53D" stroke="{INK}" stroke-width="4"/><circle cx="30" cy="-36" r="16" fill="#FFC53D" stroke="{INK}" stroke-width="4"/>'
            f'<circle cx="0" cy="0" r="44" fill="#FF5A5F" stroke="{INK}" stroke-width="5"/><circle cx="0" cy="0" r="33" fill="{WHITE}" stroke="{INK}" stroke-width="3"/>'
            f'<path d="M0,0 V-22 M0,0 L14,8" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
            f'<path d="M-62,-30 l-14,-6 M-60,-6 h-16 M62,-30 l14,-6 M60,-6 h16" stroke="{INK}" stroke-width="4" stroke-linecap="round"/></g>')


def bench(x, y, w=520):
    return (f'<g transform="translate({x},{y})"><rect x="{-w/2}" y="-150" width="{w}" height="22" rx="8" fill="#A87B4F" stroke="{INK}" stroke-width="5"/>'
            f'<rect x="{-w/2}" y="-110" width="{w}" height="22" rx="8" fill="#A87B4F" stroke="{INK}" stroke-width="5"/>'
            f'<rect x="{-w/2}" y="-40" width="{w}" height="24" rx="8" fill="#A87B4F" stroke="{INK}" stroke-width="5"/>'
            f'<rect x="{-w/2+30}" y="-20" width="18" height="20" fill="#6B4A2B"/><rect x="{w/2-48}" y="-20" width="18" height="20" fill="#6B4A2B"/></g>')


def cobweb(x, y, r=110, flip=False):
    sx = -1 if flip else 1
    rays = ''.join(f'<path d="M0,0 L{r*math.cos(math.radians(a)):.0f},{r*math.sin(math.radians(a)):.0f}" />' for a in (0, 22, 45, 68, 90))
    rings = ''.join(f'<path d="M{k*r/4},0 Q{k*r/4*0.8:.0f},{k*r/4*0.4:.0f} {k*r/4*math.cos(math.radians(22)):.0f},{k*r/4*math.sin(math.radians(22)):.0f} Q{k*r/4*0.6:.0f},{k*r/4*0.7:.0f} {k*r/4*0.7:.0f},{k*r/4*0.7:.0f} Q{k*r/4*0.4:.0f},{k*r/4*0.85:.0f} {k*r/4*0.38:.0f},{k*r/4*0.92:.0f} Q{k*r/4*0.15:.0f},{k*r/4*0.9:.0f} 0,{k*r/4}"/>' for k in (1, 2, 3, 4))
    return f'<g transform="translate({x},{y}) scale({sx},1)" fill="none" stroke="#FFFFFF" stroke-width="2.5" opacity="0.9">{rays}{rings}</g>'


def lounger(x, y):
    return (f'<g transform="translate({x},{y})"><path d="M-260,-40 L160,-40 L260,-150" fill="none" stroke="{INK}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="M-260,-40 L160,-40 L260,-150" fill="none" stroke="#4DB6E8" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="M-230,-40 V0 M130,-40 V0" stroke="{INK}" stroke-width="8"/></g>')


def sun(x, y, r=60):
    rays = ''.join(f'<path d="M{x+(r+14)*math.cos(math.radians(a)):.0f},{y+(r+14)*math.sin(math.radians(a)):.0f} L{x+(r+40)*math.cos(math.radians(a)):.0f},{y+(r+40)*math.sin(math.radians(a)):.0f}" stroke="#FFB400" stroke-width="10" stroke-linecap="round"/>' for a in range(0, 360, 30))
    return rays + f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFD23F" stroke="#FFB400" stroke-width="6"/>'


def chart(x, y, w=760, h=380):
    grid = ''.join(f'<path d="M{x},{y-i*h/5:.0f} H{x+w}" stroke="#2C4A8F" stroke-width="2"/>' for i in range(6))
    return (f'<rect x="{x-20}" y="{y-h-20}" width="{w+40}" height="{h+40}" rx="20" fill="#0B1F4F"/>' + grid +
            f'<polyline points="{x},{y-40} {x+w*0.2:.0f},{y-90} {x+w*0.35:.0f},{y-70} {x+w*0.55:.0f},{y-190} {x+w*0.7:.0f},{y-160} {x+w*0.92:.0f},{y-h+30}" fill="none" stroke="#3DDC84" stroke-width="16" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<path d="M{x+w*0.92-40:.0f},{y-h+34} L{x+w*0.92+14:.0f},{y-h+22} L{x+w*0.92:.0f},{y-h+78} Z" fill="#3DDC84"/>')


def confetti(seed=1, n=70):
    import random
    rnd = random.Random(seed)
    cols = ['#FF5A5F', '#FFD23F', '#3DDC84', '#4D96FF', '#9B5DE5', '#FF9F43']
    return ''.join(f'<rect x="{rnd.uniform(0,1024):.0f}" y="{rnd.uniform(120,700):.0f}" width="{rnd.uniform(10,20):.0f}" height="{rnd.uniform(6,12):.0f}" rx="2" fill="{rnd.choice(cols)}" transform="rotate({rnd.uniform(0,180):.0f} {rnd.uniform(0,1024):.0f} {rnd.uniform(0,768):.0f})"/>' for _ in range(n))


def spotlight(x=512, top=0, w=260, y=740):
    return f'<path d="M{x-60},{top} L{x+60},{top} L{x+w},{y} L{x-w},{y} Z" fill="#FFF6C8" opacity="0.55"/>'


def aura(x, y, r=330):
    return (f'<defs><radialGradient id="au"><stop offset="0" stop-color="#FFF6A8" stop-opacity="0.95"/><stop offset="0.6" stop-color="#FFD23F" stop-opacity="0.55"/>'
            f'<stop offset="1" stop-color="#FF9F43" stop-opacity="0"/></radialGradient></defs><circle cx="{x}" cy="{y}" r="{r}" fill="url(#au)"/>')


def smoke(x, y, s=1.0):
    return ''.join(f'<circle cx="{x+dx*s}" cy="{y+dy*s}" r="{r*s}" fill="#8E97A8" stroke="{INK}" stroke-width="3" opacity="0.9"/>' for dx, dy, r in ((0, 0, 22), (26, -30, 28), (-10, -64, 34), (30, -100, 26)))


def title_card(text_lines, bg='#FFD23F', fg=BODY_DARK):
    import random
    rnd = random.Random(5)
    blobs = ''.join(f'<circle cx="{rnd.uniform(0,1024):.0f}" cy="{rnd.uniform(0,768):.0f}" r="{rnd.uniform(30,90):.0f}" fill="#FFFFFF" opacity="0.18"/>' for _ in range(24))
    lines = ''.join(f'<text x="512" y="{250 + i*150}" text-anchor="middle" {F} font-size="130" fill="{fg}" stroke="{WHITE}" stroke-width="10" paint-order="stroke" transform="rotate({(-3 if i % 2 else 3)} 512 {250 + i*150})">{t}</text>' for i, t in enumerate(text_lines))
    return f'<rect width="1024" height="768" fill="{bg}"/>' + blobs + lines


def top_hat():  # Beep-local
    return (f'<rect x="70" y="-24" width="60" height="56" rx="6" fill="{INK}"/><rect x="52" y="26" width="96" height="12" rx="6" fill="{INK}"/>'
            f'<rect x="70" y="14" width="60" height="10" fill="#C1272D"/>')


def bow_tie():  # Beep-local
    return f'<path d="M100,160 L78,150 L78,172 Z M100,160 L122,150 L122,172 Z" fill="#C1272D" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/><circle cx="100" cy="161" r="6" fill="#C1272D" stroke="{INK}" stroke-width="3"/>'


def grad_cap():  # Beep-local
    return (f'<path d="M100,8 L160,28 L100,48 L40,28 Z" fill="{INK}"/><rect x="74" y="34" width="52" height="16" fill="{INK}"/>'
            f'<path d="M150,32 V60" stroke="#FFD23F" stroke-width="4"/><circle cx="150" cy="62" r="6" fill="#FFD23F"/>')


def cone_hat():  # Beep-local
    return cone(100, 40, 0.7)


def magnifier(x, y):  # hand prop
    return (f'<path d="M{x},{y} L{x-28},{y-46}" stroke="#8A6A45" stroke-width="10" stroke-linecap="round"/>'
            f'<circle cx="{x-44}" cy="{y-72}" r="34" fill="#DDF1FF" fill-opacity="0.55" stroke="{INK}" stroke-width="7"/>')


def card_in_hand(x, y):
    return license_card(x + 30, y - 40, 0.5, -12)
