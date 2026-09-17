import * as fs from 'fs';
import * as path from 'path';

/**
 * Risk #28 — two web hosts, one set of URLs, two different behaviours.
 *
 * The Flutter web app is served from **both** Firebase Hosting (`firebase.json`)
 * and Cloud Run behind nginx (`cloudbuild.yaml` + `nginx.conf`). Nothing in the
 * repo says which is canonical, and they do not agree about the auth-action
 * URL that password reset arrives on.
 *
 * This test does not pick a winner — that needs a deploy to test, and picking
 * one silently would change a live auth path. What it does is make the
 * divergence **fail the build instead of being discovered by a user**, and
 * pin the two facts that make it hard to reason about.
 */
const repoRoot = path.resolve(__dirname, '../../..');
const firebaseJson = JSON.parse(
  fs.readFileSync(path.join(repoRoot, 'firebase.json'), 'utf8'),
);
const nginxConf = fs.readFileSync(path.join(repoRoot, 'nginx.conf'), 'utf8');
const passwordResetHtml = fs.readFileSync(
  path.join(repoRoot, 'web/password-reset.html'),
  'utf8',
);

const AUTH_ACTION_PATH = '/__/auth/action';

describe('risk #28 — Firebase Hosting and nginx serve the same paths', () => {
  const rewrites: Array<{ source: string; destination: string }> =
    firebaseJson.hosting.rewrites;

  describe('the documented state of the divergence', () => {
    it('Firebase Hosting rewrites the auth action to password-reset.html', () => {
      const match = rewrites.find((r) => r.source === AUTH_ACTION_PATH);
      expect(match).toBeDefined();
      expect(match!.destination).toBe('/password-reset.html');
    });

    it('nginx has NO rule for it, so it falls through to the SPA', () => {
      // nginx's `location /` does `try_files $uri $uri/ /index.html`, so the
      // same URL serves the Flutter app. The app routes an oobCode by mode via
      // ActionCodeRouter, which is arguably the BETTER behaviour — which is
      // exactly why this must not be "fixed" by copying Firebase's rule across
      // without testing a deploy.
      expect(nginxConf).not.toContain(AUTH_ACTION_PATH);
      expect(nginxConf).toContain('try_files $uri $uri/ /index.html');
    });

    it('is recorded as a known divergence, so it cannot be forgotten', () => {
      // If someone resolves this, they update the note and this test with it.
      const note = fs.readFileSync(path.join(repoRoot, 'SESSION.md'), 'utf8');
      expect(note).toContain('#28');
    });
  });

  describe('the two facts that make this confusing', () => {
    it('password-reset.html handles resetPassword ONLY', () => {
      expect(passwordResetHtml).toContain('resetPassword');
      // Firebase sends three modes to this one URL. The page implements one.
      expect(passwordResetHtml).not.toContain('verifyEmail');
      expect(passwordResetHtml).not.toContain('recoverEmail');
    });

    it('Hosting rewrites cannot match query strings, so the mode-specific entries are dead', () => {
      // firebase.json carries `/__/auth/action?**` and
      // `/__/auth/action?mode=resetPassword&oobCode=**`. Hosting matches on
      // PATH only, so all of them collapse onto the plain path rule above and
      // none of them can ever route by mode. They read like mode-aware routing
      // and are not, which is the trap.
      const queryRewrites = rewrites.filter((r) => r.source.includes('?'));
      expect(queryRewrites.length).toBeGreaterThan(0);

      const plainPathFirst = rewrites.findIndex((r) => r.source === AUTH_ACTION_PATH);
      for (const q of queryRewrites) {
        if (!q.source.startsWith(AUTH_ACTION_PATH)) continue;
        expect(rewrites.indexOf(q)).toBeGreaterThan(plainPathFirst);
      }
    });
  });

  describe('parity on everything they DO both implement', () => {
    it.each(['/auth-redirect.html', '/password-reset.html'])(
      'both hosts serve %s with no-store caching',
      (p) => {
        const headerRule = firebaseJson.hosting.headers.find(
          (h: { source: string }) => h.source === p,
        );
        expect(headerRule).toBeDefined();
        expect(
          headerRule.headers.some(
            (h: { key: string; value: string }) =>
              h.key === 'Cache-Control' && h.value.includes('no-store'),
          ),
        ).toBe(true);

        // nginx sets the same on its matching location block.
        expect(nginxConf).toContain(`location ${p}`);
      },
    );

    it('both fall back to index.html for unknown paths', () => {
      expect(rewrites.some((r) => r.source === '**' && r.destination === '/index.html')).toBe(true);
      expect(nginxConf).toContain('/index.html');
    });
  });
});
