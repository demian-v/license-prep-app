import os, json
from PIL import Image, ImageDraw, ImageFont
OUT='/Users/demianvyrozub/projects/license-prep-app/design/memes/own'
S=os.path.dirname(os.path.abspath(__file__))
rows=json.load(open(os.path.join(S,'own_rows.json')))
T={'b1-lt30':'Bucket 1 · under 30 %','b2-30-59':'Bucket 2 · 30–59 %','b3-60-89':'Bucket 3 · 60–89 %','b4-90-100':'Bucket 4 · 90–100 % (passed)','b5-out-of-time':'Bucket 5 · Out of time (Экзамен, not passed)'}
H='/System/Library/Fonts/Helvetica.ttc'; ft=ImageFont.truetype(H,34); fl=ImageFont.truetype(H,17); fs=ImageFont.truetype(H,14)
cols,cw,ch=5,360,270
for b,items in rows.items():
    sh=Image.new('RGB',(cols*cw,80+2*(ch+56)),(243,245,250)); d=ImageDraw.Draw(sh)
    d.text((20,22),T[b],font=ft,fill=(14,31,77))
    for i,r in enumerate(items):
        x=(i%cols)*cw; y=80+(i//cols)*(ch+56)
        im=Image.open(os.path.join(OUT,b,r['file'])).convert('RGB'); im.thumbnail((cw-12,ch))
        sh.paste(im,(x+(cw-im.width)//2,y))
        d.text((x+10,y+ch+6),r['file'][:-4],font=fl,fill=(14,31,77))
        d.text((x+10,y+ch+28),'logic: '+r['logic'][:44],font=fs,fill=(90,100,120))
    sh.save(os.path.join(OUT,f'sheet-{b}.png'))
