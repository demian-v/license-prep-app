"""Optimise the Beep memes for the app: WebP, longest side 512 px, <= 60 KB.

Writes webp/<bucket>/<id>.webp and webp/manifest.json (read by
scripts/local/seed-result-memes.js). Run from design/memes/own.
"""
import io, json, os
from PIL import Image

BUCKETS = ['b1-lt30', 'b2-30-59', 'b3-60-89', 'b4-90-100', 'b5-out-of-time']
ID = {'b1-lt30': 'lt30', 'b2-30-59': '30-59', 'b3-60-89': '60-89', 'b4-90-100': '90-100', 'b5-out-of-time': 'out-of-time'}
LIMIT = 60 * 1024
out = []
for folder in BUCKETS:
    bucket = ID[folder]
    os.makedirs(f'webp/{bucket}', exist_ok=True)
    for order, name in enumerate(sorted(f for f in os.listdir(folder) if f.endswith('.png')), 1):
        src = f'{folder}/{name}'
        im = Image.open(src).convert('RGB')
        im.thumbnail((512, 512), Image.LANCZOS)
        for q in range(86, 40, -4):
            buf = io.BytesIO(); im.save(buf, 'WEBP', quality=q, method=6)
            if buf.tell() <= LIMIT: break
        mid = f'{bucket}-{name[:-4]}'
        dst = f'webp/{bucket}/{mid}.webp'
        open(dst, 'wb').write(buf.getvalue())
        out.append(dict(id=mid, bucket=bucket, file=dst, storagePath=f'result_memes/{bucket}/{mid}.webp',
                        width=im.width, height=im.height, bytes=buf.tell(), quality=q,
                        sourceBytes=os.path.getsize(src), order=order))
json.dump(out, open('webp/manifest.json', 'w'), indent=1)
tb = sum(o['sourceBytes'] for o in out); ta = sum(o['bytes'] for o in out)
print(f'{len(out)} files: {tb/1024:.0f} KB PNG -> {ta/1024:.0f} KB WebP; max {max(o["bytes"] for o in out)/1024:.1f} KB; min q {min(o["quality"] for o in out)}')
