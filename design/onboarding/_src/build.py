"""Build design/onboarding/driveusa-onboarding.html from the template and the composited screenshots."""
import base64, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
shots = {}
for k in ['tests', 'theory', 'instructors', 'profile']:
    p = os.path.join(HERE, 'shots', f'c_{k}.jpg')
    if os.path.exists(p):
        shots[k] = 'data:image/jpeg;base64,' + base64.b64encode(open(p, 'rb').read()).decode()
s = open(os.path.join(HERE, 'onboarding.template.html')).read().replace('/*SHOTS*/', json.dumps(shots))
out = os.path.join(HERE, '..', 'driveusa-onboarding.html')
open(out, 'w').write(s)
print(out, len(s), sorted(shots))
