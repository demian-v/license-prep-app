"""Build design/video-ads/story-drafts.html from the template, the Beep poses and the screenshots."""
import base64, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
shots = {k: 'data:image/jpeg;base64,' + base64.b64encode(open(os.path.join(HERE, 'shots', f'c_{k}.jpg'), 'rb').read()).decode()
         for k in ['tests', 'theory', 'profile']}
s = (open(os.path.join(HERE, 'story-drafts.template.html')).read()
     .replace('/*POSES*/', open(os.path.join(HERE, 'poses.json')).read())
     .replace('/*SHOTS*/', json.dumps(shots)))
open(os.path.join(HERE, '..', 'story-drafts.html'), 'w').write(s)
print('built', len(s))
