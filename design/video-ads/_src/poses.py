import os, sys, json
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'memes', 'own', '_src'))
from beep import *

book = ('<g class="bk">'
        '<path d="M58,146 Q100,138 100,150 Q100,138 142,146 L142,184 Q100,176 100,188 Q100,176 58,184 Z" fill="#0048C3" stroke="#0E1F4D" stroke-width="5" stroke-linejoin="round"/>'
        '<path d="M63,146 Q96,140 100,150 L100,183 Q96,173 63,179 Z" fill="#fff" stroke="#0E1F4D" stroke-width="3"/>'
        '<path d="M137,146 Q104,140 100,150 L100,183 Q104,173 137,179 Z" fill="#fff" stroke="#0E1F4D" stroke-width="3"/>'
        '<path d="M70,156 L92,153 M70,164 L92,161 M108,153 L130,156 M108,161 L124,163" stroke="#9AA7C7" stroke-width="3" stroke-linecap="round"/>'
        '<path class="pg" d="M137,146 Q104,140 100,150 L100,183 Q104,173 137,179 Z" fill="#EBF1FE" stroke="#0E1F4D" stroke-width="3"/>'
        '</g>')

def testpaper(ok):
    def f(x, y):
        m = ('<path d="M%d,%d l6,6 l12,-13" fill="none" stroke="#0F7A3D" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>' % (x-9, y+10)) if ok else ''
        lines = ''.join('<path d="M%d,%d H%d" stroke="#9AA7C7" stroke-width="3"/>' % (x-14, y-22+i*9, x+14) for i in range(3))
        return ('<g><rect x="%d" y="%d" width="44" height="56" rx="5" fill="#fff" stroke="#0E1F4D" stroke-width="3.5"/>' % (x-22, y-40)) + lines + m + '</g>'
    return f

topper = ('<rect x="70" y="14" width="60" height="22" rx="6" fill="#fff" stroke="#0E1F4D" stroke-width="4"/>'
          '<path d="M80,25 H120" stroke="#C1272D" stroke-width="5" stroke-linecap="round"/>')

P = {
 'study': beep(0,0, eyes='normal', look=(0,6), brows='focus', mouth='smile', left='front', right='front', extras=book),
 'think': beep(0,0, eyes='normal', look=(-7,-6), brows='raised', mouth='meh', left='temple', right='out', rprop=testpaper(False)),
 'pass':  beep(0,0, eyes='sparkle', mouth='grin', blush=True, left='fistup', right='up', rprop=testpaper(True), extras=sparkles()),
 'wave':  beep(0,0, eyes='happy', mouth='smile', blush=True, left='wave', right='down'),
 'coach': beep(0,0, eyes='normal', look=(-6,0), brows='raised', mouth='smile', left='down', right='thumb', body='#FFB547', hat=topper),
 'drive': beep(0,0, eyes='happy', mouth='grin', blush=True, left='wave', right='fistup'),
}
for i,l in enumerate([(-8,7),(-3,8),(3,8),(8,7)]):
    P['look%d'%i] = beep(0,0, eyes='normal', look=l, mouth='smile', left='down', right='down')
json.dump(P, open(sys.argv[1],'w'))
print({k:len(v) for k,v in P.items()})
