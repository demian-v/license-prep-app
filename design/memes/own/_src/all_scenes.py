"""All 50 Beep memes. Each keeps the logic of a real meme from the review set, drawn from scratch."""
import json, os, sys
from scene import *
from props import *

OUT = '/Users/demianvyrozub/projects/license-prep-app/design/memes/own'


def panels(*parts, cols=2, rows=1, gap=10):
    """Lay 1024×768 scenes out as a grid of panels."""
    pw, ph = (W - gap * (cols - 1)) / cols, (H - gap * (rows - 1)) / rows
    s = [f'<rect width="{W}" height="{H}" fill="{INK}"/>']
    for i, p in enumerate(parts):
        x, y = (i % cols) * (pw + gap), (i // cols) * (ph + gap)
        s.append(f'<svg x="{x:.0f}" y="{y:.0f}" width="{pw:.0f}" height="{ph:.0f}" viewBox="0 0 {W} {H}" preserveAspectRatio="xMidYMid slice">{p}</svg>')
    return svg(''.join(s), bg=INK)


B = lambda **k: beep(k.pop('x', 512), k.pop('y', 745), k.pop('s', 2.9), **k)

S = {}
# ------------------------------------------------------------------ b1  < 30 %
S['b1-lt30'] = [
 ('this-is-fine', 'this is fine (calm in a burning room)', "I'M NOT MAD. THIS IS FINE.", '',
  lambda: svg(room('#F6D98B', '#C98B4A', 600), fire(120, 600, 1.6), fire(900, 600, 1.8), fire(260, 330, 1.0), fire(820, 300, 1.1),
              '<rect x="0" y="0" width="1024" height="768" fill="#FF7A1A" opacity="0.12"/>',
              B(x=470, s=2.5, eyes='happy', mouth='smile', left='front', right='down', blush=True), mug(640, 700, 1.6))),
 ('not-sure-if', '"not sure if" squint', 'NOT SURE IF THE TEST WAS EASY', 'OR I GOT EVERYTHING WRONG',
  lambda: svg(sky('#5A7BB5', '#90A9D6'), B(y=650, s=2.3, eyes='squint', mouth='flat', brows='focus'))),
 ('one-more-round', 'tired, flat tyres', 'ONE MORE ROUND OF THEORY', '',
  lambda: svg(sky('#F6B98A', '#FDE6C8'), ground(640, '#C9B28A', '#A88F63'),
              B(rot=4, eyes='tired', mouth='meh', brows='sad', left='limp', right='limp', flat=True, squash=0.92, extras=sweat(176, 70) + sweat(26, 84, 0.7)))),
 ('under-control', 'everything under control (chaos)', 'EVERYTHING IS UNDER CONTROL', '',
  lambda: svg(room('#EAF0FA', '#B9C4D9', 620),
              ''.join(f'<g transform="rotate({r} {x} {y})">' + paper(x, y, 60, 76) + '</g>' for x, y, r in ((140, 260, -20), (870, 230, 25), (230, 520, 40), (800, 500, -30), (520, 170, 10))),
              cone(160, 700, 1.4), cone(880, 700, 1.2),
              B(eyes='happy', mouth='grin', left='out', right='thumb', hat=cone_hat(), extras=sweat(176, 70)))),
 ('after-40-questions', 'exhausted, spiral eyes, paper stack', 'ME AFTER 40 QUESTIONS', '',
  lambda: svg(room('#E4D3F2', '#B7A3C9', 620),
              ''.join(paper(200, 690 - i*14, 150, 20) for i in range(14)),
              B(x=560, s=2.6, eyes='spiral', mouth='wavy', left='limp', right='limp', extras=sweat(176, 70)))),
 ('back-to-theory', 'heading out: back to theory', 'OK, BACK TO THEORY', '',
  lambda: svg(sky('#9FD0FF', '#E7F4FF'), clouds(), ground(660), signpost(800, 690, 'THEORY', 1.4),
              B(x=420, s=2.5, eyes='normal', look=(8, 0), mouth='smile', left='front', right='side', lprop=lambda x, y: book(x + 10, y + 20, 1.0, '#0F7A3D')))),
 ('back-to-basics', 'caveman: stone wheels', 'BACK TO BASICS', '',
  lambda: svg(sky('#F2C27A', '#FBE3B8'), '<path d="M0,420 L180,260 L330,420 Z M620,420 L820,220 L1024,420 Z" fill="#C79A62"/>', ground(640, '#B08A5A', '#8A6A45'),
              B(eyes='normal', look=(0, -4), mouth='teeth', brows='raised', left='out', right='down', stone=True, body='#6E8FCF'))),
 ('nap-then-retry', 'sleeping it off', 'NAP FIRST.', 'RETRY LATER.',
  lambda: svg(room('#C7D4F2', '#8E9CC2', 620), bed(512, 690, 700),
              B(y=660, s=2.2, rot=-8, eyes='closed', mouth='sleep', left='down', right='down', extras=zzz(170, 30), blush=True),
              blanket(560, 700, 520))),
 ('surprised', 'shocked face', 'WHEN YOU SKIP THE THEORY', '',
  lambda: svg(sky('#7EC87A', '#C8EBC4'), B(eyes='wide', mouth='bigo', brows='raised', left='down', right='down'))),
 ('reading-answers', 'cringing at the screen', 'READING MY ANSWERS BACK', '',
  lambda: svg(room('#DCE7F7', '#A9B7D3', 640), B(x=300, s=2.4, eyes='x', mouth='grimace', brows='worried', left='face', right='down', extras=sweat(176, 70)),
              laptop(740, 720, 1.6))),
]
# ------------------------------------------------------------------ b2  30–59 %
S['b2-30-59'] = [
 ('wait-that-wasnt-it', 'confused "???"', "WAIT, THAT WASN'T IT?", '',
  lambda: svg(room('#F1EDE4', '#CDBFA6', 640), B(eyes='normal', look=(-6, -4), mouth='smirk', brows='one', left='down', right='down', extras=qmarks()))),
 ('question-20', 'blurry panic', 'WHEN QUESTION 20 HITS', '',
  lambda: (lambda p: svg(room('#EAF0FA', '#B9C4D9', 640), ghost(p, [(-60, 0), (60, 6), (-30, -8), (34, -6)], 0.22), p()))(
      lambda: B(eyes='wide', mouth='wavy', brows='worried', left='face', right='face', extras=sweat(180, 60) + sweat(16, 70, 0.8)))),
 ('which-half', 'hmm, half right', 'HALF RIGHT...', 'BUT WHICH HALF?',
  lambda: svg(sky('#7FC6C9', '#D2EEEF'), B(y=650, s=2.3, eyes='squint', look=(6, 0), mouth='smirk', brows='focus', left='down', right='chin', extras=qmarks(((190, 40, 40),))))),
 ('half-and-half', 'happy / sad two-panel', 'HALF RIGHT', 'HALF WRONG',
  lambda: panels(svg(sky('#FFE08A', '#FFF6D6'), B(y=640, s=2.3, eyes='happy', mouth='grin', left='up', right='up', blush=True, extras=sparkles())),
                 svg(sky('#7F9CC9', '#C6D3EA'), B(y=640, s=2.3, eyes='tired', mouth='frown', brows='sad', left='limp', right='limp', extras=tear(52, 142) + tear(148, 142))))),
 ('pass-mark-window', 'looking out of the window at the pass mark', 'THE PASS MARK FROM HERE', '',
  lambda: svg(room('#3B4A6B', '#27324A', 700), window_frame(262, 150, 500, 420), banner(600, 300, '90%', '#0F7A3D', 1.0),
              B(x=400, y=760, s=2.2, eyes='normal', look=(6, -6), mouth='meh', brows='sad', left='down', right='down'))),
 ('side-eye', 'awkward side-eye, two panels', 'WHEN YOU SEE THE RIGHT ANSWER', '',
  lambda: panels(svg(sky('#C7E0F4', '#E9F3FB'), B(eyes='normal', look=(0, 0), mouth='flat', left='down', right='down')),
                 svg(sky('#C7E0F4', '#E9F3FB'), B(eyes='normal', look=(10, 2), mouth='flat', brows='worried', left='down', right='down', extras=sweat(176, 70))))),
 ('halfway-rest', 'lying down halfway', 'HALFWAY THERE. QUICK REST.', '',
  lambda: svg(room('#DDE6F2', '#AFC0D8', 600), B(y=720, s=2.6, eyes='closed', mouth='smile', left='limp', right='limp', flat=True, squash=0.62, blush=True, extras=zzz(170, 40)))),
 ('not-bad', '"not bad" face', 'NOT BAD. NOT GREAT.', '',
  lambda: svg(sky('#E9E4DA', '#F7F4EE'), B(eyes='normal', look=(0, 2), mouth='frown', brows='raised', left='hip', right='hip'))),
 ('half-ready', 'scared and not scared, two panels', 'HALF READY', 'HALF NOT',
  lambda: panels(svg(sky('#BFE3C3', '#E6F5E8'), B(eyes='smug', mouth='smirk', left='hip', right='thumb', shades=False)),
                 svg(sky('#F6C2C2', '#FBE6E6'), B(eyes='wide', mouth='grimace', brows='worried', left='face', right='face', extras=sweat(176, 70))))),
 ('thinking-hard', 'smoke from thinking', 'THINKING REALLY HARD', '',
  lambda: svg(sky('#C9D6F0', '#EDF2FB'), B(eyes='squint', mouth='wavy', brows='focus', left='temple', right='down',
                                           extras=smoke(150, -20, 1.0) + sweat(26, 84, 0.8)))),
]
# ------------------------------------------------------------------ b3  60–89 %
S['b3-60-89'] = [
 ('now-youre-thinking', 'finger to temple, smug', "NOW YOU'RE THINKING", '',
  lambda: svg(sky('#9DB4CF', '#DCE6F1'), B(eyes='smug', mouth='smirk', left='down', right='temple'))),
 ('good-work-it-is', 'wise mentor praise', 'GOOD WORK', 'IT IS',
  lambda: svg(sky('#7BAA8C', '#CFE5D6'), B(y=650, s=2.3, eyes='smug', mouth='smile', brows='raised', left='down', right='thumb', hat=grad_cap()))),
 ('eye-on-you', 'keeping an eye on you (magnifier)', 'KEEPING MY', 'EYE ON YOU',
  lambda: svg(sky('#E7D7F3', '#F6EEFB'), B(y=650, s=2.3, eyes='squint', look=(0, 0), mouth='smirk', brows='one', left='down', right='temple', rprop=None,
                                           extras=magnifier(190, 166)))),
 ('good-job', 'grudging "good job"', 'GOOD JOB', '',
  lambda: svg(sky('#3E3A5C', '#6C6490'), spotlight(512, 0, 300), B(eyes='normal', look=(-4, 4), mouth='frown', brows='raised', left='hip', right='thumb', extras=bow_tie()))),
 ('almost-dmv', 'excited outside the DMV', 'ALMOST READY FOR THE DMV', '',
  lambda: svg(sky('#9FD0FF', '#E7F4FF'), clouds(), ground(660), building(700, 660),
              B(x=320, s=2.3, eyes='sparkle', mouth='grin', left='wave', right='down', blush=True))),
 ('so-close', 'joyful, almost there', 'SO CLOSE!', '',
  lambda: svg(sky('#8FB8FF', '#DCE8FF'), B(eyes='happy', mouth='grin', left='up', right='up', blush=True, extras=sparkles(((-20, 60, 10), (215, 50, 12)))))),
 ('good-job-buddy', 'pat on the back for little Beep', 'GOOD JOB, BUDDY', '',
  lambda: svg(sky('#D7E8C8', '#F0F7EA'), ground(680, '#B7D69A', '#94BC72'),
              B(x=360, s=2.4, eyes='happy', mouth='smile', left='down', right='side', blush=True),
              beep(700, 745, 1.5, eyes='happy', mouth='grin', left='up', right='down', blush=True))),
 ('right-road', 'cruising on the road', 'ON THE RIGHT ROAD', '',
  lambda: svg(sky('#8CC8FF', '#E3F2FF'), clouds(), '<path d="M0,560 H1024 V640 H0 Z" fill="#8BC34A"/>', road(620),
              signpost(860, 640, 'PASS 1 MI', 1.2, '#0F7A3D'),
              B(x=420, s=2.4, eyes='normal', look=(6, 0), mouth='smile', left='wave', right='down'))),
 ('imagine-passing', 'dreaming of the licence', 'IMAGINE PASSING', 'NEXT TIME',
  lambda: svg(sky('#B9A7F0', '#E9E2FF'), thought(700, 250, license_card(700, 250, 1.0), 320, 210),
              B(x=380, y=650, s=2.2, eyes='sparkle', look=(8, -8), mouth='smile', left='down', right='chin', blush=True))),
 ('leveling-up', 'flexing, getting stronger', 'LEVELING UP', '',
  lambda: svg(room('#F2D7B6', '#C9A57C', 640), B(eyes='smug', mouth='grin', brows='angry', left='flex', right='flex', extras=sweat(180, 50)))),
]
# ------------------------------------------------------------------ b4  ≥ 90 %
S['b4-90-100'] = [
 ('success', 'fist of success', '', 'SUCCESS',
  lambda: svg(sky('#8E7BD8', '#5A8BE0'), B(y=650, s=2.3, eyes='smug', mouth='smirk', brows='angry', left='down', right='fistup'))),
 ('woo-hoo', 'arms up joy', '', 'WOO HOO!',
  lambda: svg(sky('#4DA8FF', '#A6D4FF'), confetti(2), B(y=650, s=2.3, eyes='happy', mouth='grin', left='up', right='up', blush=True))),
 ('future-driver', 'a toast', 'TO THE FUTURE DRIVER', '',
  lambda: svg(sky('#1D2B4F', '#3B4F80'), confetti(7, 40), B(eyes='smug', mouth='smirk', brows='raised', left='down', right='wave', rprop=glass, extras=bow_tie()))),
 ('first-try', 'glow-up with shades', 'PASSED ON THE FIRST TRY', '',
  lambda: svg(rays(512, 460, 20, '#FFC6A8', '#FFE6D6'), B(eyes='normal', mouth='smirk', shades=True, left='hip', right='thumb', extras=sparkles()))),
 ('you-get-a-license', 'giving licences to everyone', 'YOU GET A LICENSE!', '',
  lambda: svg(sky('#6A3FB5', '#B28DF0'), spotlight(512, 0, 320),
              license_card(170, 330, 0.8, -18), license_card(860, 300, 0.8, 16), license_card(880, 560, 0.6, -10), license_card(150, 580, 0.6, 12),
              B(eyes='happy', mouth='grin', left='up', right='up', blush=True))),
 ('nailed-it', 'the dab', 'NAILED IT', '',
  lambda: svg(sky('#E8F0FF', '#FFFFFF'), B(x=560, s=2.5, rot=-14, eyes='closed', mouth='smirk', left='dabout', right='dabin', extras=sparkles(((210, 40, 14),))))),
 ('license-unlocked', 'rainbow win', 'LICENSE UNLOCKED', '',
  lambda: svg(sky('#7FB6FF', '#DDEBFF'), rainbow(512, 720, 560), clouds(), ground(680),
              B(eyes='sparkle', mouth='grin', left='up', right='up', blush=True, extras=sparkles()))),
 ('passed-with-style', 'tuxedo fancy', 'PASSED WITH STYLE', '',
  lambda: svg(sky('#2B2140', '#4E3A73'), spotlight(512, 0, 300), B(eyes='smug', mouth='smirk', brows='raised', left='hip', right='front', hat=top_hat(), extras=bow_tie()))),
 ('score-going-up', 'the chart goes up', 'MY SCORE:', '',
  lambda: svg(sky('#07163A', '#0B1F4F'), chart(150, 640, 740, 400),
              B(x=300, s=2.2, eyes='smug', mouth='smirk', left='down', right='thumb', extras=bow_tie()),
              '<text x="700" y="610" font-family="Arial Black" font-weight="900" font-size="64" fill="#3DDC84">UP ONLY</text>')),
 ('full-power', 'maximum power aura', 'FULL POWER', '',
  lambda: svg(sky('#FF7A59', '#FFC46B'), aura(512, 470, 420), B(eyes='star', mouth='grin', brows='angry', left='flex', right='flex', extras=sparkles()))),
]
# ------------------------------------------------------------------ b5  out of time (Экзамен)
S['b5-out-of-time'] = [
 ('timer-hits-zero', 'checking the watch in a field', 'WHEN THE TIMER HITS 0:00', '',
  lambda: svg(sky('#A9CCEB', '#E3EEF6'), clouds(((200, 120, 1.1), (820, 90, 0.9))), flower_field(440),
              beep(540, 745, 2.8, eyes='normal', look=(-5, 8), mouth='meh', brows='focus', left='watch', right='hip', lprop=watch))),
 ('still-on-32', 'sitting and waiting in a field', 'STILL ON QUESTION 32', '',
  lambda: svg(sky('#A9CCEB', '#E3EEF6'), clouds(((260, 110, 1.0), (780, 140, 1.2))), flower_field(360, 5),
              beep(300, 730, 1.6, eyes='normal', look=(8, -2), mouth='smile', left='front', right='front'))),
 ('sixty-minutes-later', 'lying down in the field', '60 MINUTES LATER', '',
  lambda: svg(sky('#A9CCEB', '#E3EEF6'), clouds(((200, 120, 1.0),)), flower_field(380, 9),
              beep(512, 715, 2.0, eyes='closed', mouth='sleep', left='limp', right='limp', flat=True, squash=0.6, extras=zzz(170, 40)), '<path d="M0,720 H1024 V768 H0 Z" fill="#7A7F88"/>')),
 ('still-on-12', 'waited so long: cobwebs and dust', 'STILL ON QUESTION 12', '',
  lambda: svg(sky('#9AA5B8', '#D5DBE5'), ground(660, '#8FA07A', '#6F7F5C'), bench(512, 700, 620),
              beep(512, 676, 2.4, eyes='closed', mouth='flat', left='limp', right='limp', flat=True, body='#7F96C4'),
              cobweb(250, 330, 140), cobweb(780, 320, 140, True), '<path d="M240,590 q30,-20 60,0 M700,560 q30,-20 60,0" stroke="#FFFFFF" stroke-width="3" fill="none" opacity="0.7"/>')),
 ('one-eternity-later', 'the time card', '', '',
  lambda: svg(title_card(['ONE', 'ETERNITY', 'LATER'], '#FFD23F', '#0048C3'))),
 ('empty-hourglass', 'the sand ran out', 'THE SAND RAN OUT', '',
  lambda: svg(room('#F3E6CF', '#CDB48B', 640), hourglass(760, 720, 2.2),
              B(x=330, s=2.4, eyes='wide', look=(8, 0), mouth='o', brows='worried', left='down', right='side', extras=sweat(176, 70)))),
 ('look-at-the-time', '"would you look at the time"', 'OH WOW, WOULD YOU LOOK AT THE TIME', '',
  lambda: svg(sky('#EFEFEF', '#FFFFFF'), B(eyes='normal', look=(-6, 8), mouth='o', brows='raised', left='watch', right='down', lprop=watch))),
 ('waiting-for-last-answer', 'staring at the clock, four panels', 'WAITING FOR THE LAST ANSWER', '',
  lambda: panels(*[svg(room('#E9D2A8', '#B98E5A', 700), wall_clock(512, 260, 110, 10, m),
                       B(y=780, s=2.1, eyes='normal', look=(0, -8), mouth=mo, brows=br, left='down', right='down'))
                   for m, mo, br in ((0, 'smile', None), (20, 'flat', None), (40, 'meh', 'worried'), (59, 'wavy', 'worried'))], cols=2, rows=2)),
 ('take-your-time', 'relaxing while the timer runs out', '"TAKE YOUR TIME," THEY SAID', '',
  lambda: svg(sky('#7FD1FF', '#DDF4FF'), sun(860, 140), '<rect y="560" width="1024" height="208" fill="#F7DFA6"/>',
              lounger(470, 700), B(x=450, y=640, s=2.0, rot=-12, eyes='closed', mouth='smile', left='up', right='front', shades=True),
              wall_clock(150, 170, 70, 12, 0))),
 ('alarm-clocks', 'surrounded by ringing alarms', 'THE EXAM TIMER', '',
  lambda: svg(room('#D5D9F2', '#9EA4C9', 640),
              ''.join(alarm_clock(x, y, s, r) for x, y, s, r in ((150, 300, 1.2, -12), (870, 280, 1.3, 14), (160, 620, 1.1, 8), (880, 610, 1.2, -10), (512, 230, 0.8, 4))),
              B(s=2.4, eyes='wide', mouth='grimace', brows='worried', left='face', right='face', extras=sweat(176, 70)))),
]


def build():
    rows = {}
    for b, items in S.items():
        os.makedirs(f'{OUT}/{b}', exist_ok=True)
        os.makedirs(f'{OUT}/_blank/{b}', exist_ok=True)
        rows[b] = []
        for i, (slug, logic, top, bottom, fn) in enumerate(items, 1):
            name = f'{i:02d}-{slug}.png'
            im = render(fn())
            im.save(f'{OUT}/_blank/{b}/{name}')
            caption(im, top, bottom).save(f'{OUT}/{b}/{name}')
            rows[b].append(dict(file=name, logic=logic, caption=' / '.join(x for x in (top, bottom) if x) or '(text in the picture)'))
            print(b, name, flush=True)
    json.dump(rows, open(os.path.join(HERE, 'own_rows.json'), 'w'), indent=1)


if __name__ == '__main__':
    build()
