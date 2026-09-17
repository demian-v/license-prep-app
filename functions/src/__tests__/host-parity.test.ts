import * as fs from 'fs';
import * as path from 'path';

/**
 * Risk #28 — two web hosts, one set of URLs, and they must not disagree.
 *
 * The Flutter web app is served from **both** Firebase Hosting
 * (`firebase.json`) and Cloud Run behind nginx (`cloudbuild.yaml` +
 * `nginx.conf`). They used to do different things with the auth-action URL
 * that password reset arrives on, so the same email link worked or failed
 * depending on which host the user hit.
 *
 * **Resolved 2026-09-17 toward Firebase Hosting's behaviour**, and that
 * direction was the opposite of the first guess. Serving the Flutter app for
 * that path looks like the more capable option and is not: nothing in `lib/`
 * calls `usePathUrlStrategy`, so Flutter web uses **hash** routing, the path
 * never reaches `onGenerateRoute`, and the `oobCode` in the query string is
 * dropped. A user clicking a reset link on the nginx host landed on the login
 * screen. `ActionCodeRouter` is good code that this URL never reaches.
 */
const repoRoot = path.resolve(__dirname, '../../..');
const firebaseJson = JSON.parse(
  fs.readFileSync(path.join(repoRoot, 'firebase.json'), 'utf8'),
);
const nginxConf = fs.readFileSync(path.join(repoRoot, 'nginx.conf'), 'utf8');
const landingPage = fs.readFileSync(
  path.join(repoRoot, 'web/password-reset.html'),
  'utf8',
);
const infoPlist = fs.readFileSync(
  path.join(repoRoot, 'ios/Runner/Info.plist'),
  'utf8',
);
const androidManifest = fs.readFileSync(
  path.join(repoRoot, 'android/app/src/main/AndroidManifest.xml'),
  'utf8',
);
const appBuildGradle = fs.readFileSync(
  path.join(repoRoot, 'android/app/build.gradle'),
  'utf8',
);

const AUTH_ACTION_PATH = '/__/auth/action';

describe('risk #28 — the two hosts agree on the auth-action URL', () => {
  const rewrites: Array<{ source: string; destination: string }> =
    firebaseJson.hosting.rewrites;

  it('Firebase Hosting serves password-reset.html', () => {
    const match = rewrites.find((r) => r.source === AUTH_ACTION_PATH);
    expect(match).toBeDefined();
    expect(match!.destination).toBe('/password-reset.html');
  });

  it('nginx serves the SAME page, via an exact-match location', () => {
    // `location = <path>` is nginx's exact match and takes priority over
    // everything else, including `location /`. A prefix match here would be
    // beaten by the regex blocks further down.
    expect(nginxConf).toMatch(
      /location\s*=\s*\/__\/auth\/action\s*\{[^}]*try_files\s+\/password-reset\.html/,
    );
  });

  it('nginx does NOT fall through to the SPA for it', () => {
    const exact = nginxConf.indexOf('location = /__/auth/action');
    const spa = nginxConf.indexOf('try_files $uri $uri/ /index.html');
    expect(exact).toBeGreaterThan(-1);
    expect(spa).toBeGreaterThan(-1);
    expect(exact).toBeLessThan(spa);
  });

  it('the SPA fallback is still there for every other path', () => {
    expect(rewrites.some((r) => r.source === '**' && r.destination === '/index.html')).toBe(true);
    expect(nginxConf).toContain('try_files $uri $uri/ /index.html');
  });

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
      expect(nginxConf).toContain(`location ${p}`);
    },
  );
});

describe('the landing page handles every mode Firebase sends it', () => {
  // Firebase sends resetPassword, verifyEmail and recoverEmail to one URL.
  // The page used to assume all three were password resets: one heading, one
  // body text, and deep links hardcoded to /reset-password.
  it.each(['resetPassword', 'verifyEmail', 'recoverEmail'])(
    'knows about %s',
    (mode) => {
      expect(landingPage).toContain(`${mode}:`);
    },
  );

  it('no longer hardcodes a password-reset heading', () => {
    expect(landingPage).toContain('id="action-title"');
    expect(landingPage).toContain('id="action-message"');
    expect(landingPage).not.toContain('<div class="subtitle">Password Reset</div>');
  });

  it('admits recoverEmail is unsupported rather than faking it', () => {
    // The app has no screen for Firebase's "undo this email change" flow --
    // ActionCodeRouter says so too. Showing a password-reset page for it was
    // the old behaviour and is worse than saying so.
    expect(landingPage).toMatch(/recoverEmail:[\s\S]{0,400}host:\s*null/);
  });
});

describe("the page's deep links point at schemes that are actually registered", () => {
  // Every deep link on this page used `licenseprep://` or `licenseprepapp://`.
  // Neither is declared on either platform, so all six opened nothing -- the
  // automatic hand-off to the app has never worked.
  it('iOS declares the driveusa scheme', () => {
    expect(infoPlist).toContain('<string>driveusa</string>');
  });

  it('the page uses that scheme and no invented one', () => {
    expect(landingPage).toContain("const SCHEME = 'driveusa'");
    expect(landingPage).not.toContain('licenseprep://');
    expect(landingPage).not.toContain('licenseprepapp://');
  });

  it.each([
    ['resetPassword', 'resetPassword'],
    ['verifyEmail', 'email-verified'],
  ])('the %s target (%s) is registered in the Android manifest', (_mode, host) => {
    expect(androidManifest).toContain(`android:scheme="driveusa" android:host="${host}"`);
  });

  it('offers the PATH form first, because the host form loses the mode', () => {
    // Measured on the simulator 2026-09-17:
    //   driveusa://resetPassword?oobCode=X   -> route "/?oobCode=X"
    //   driveusa:///resetPassword?oobCode=X  -> route "/resetPassword?oobCode=X"
    // Flutter drops the host, so only the three-slash form tells the app what
    // the link was for. That matters because firebase_auth returned
    // `ActionCodeInfoOperation.unknown` for a valid reset code, leaving the
    // URL as the only way to route it.
    const pathForm = landingPage.indexOf("SCHEME + ':///' + cfg.host");
    const hostForm = landingPage.indexOf("SCHEME + '://' + cfg.host");
    expect(pathForm).toBeGreaterThan(-1);
    expect(hostForm).toBeGreaterThan(-1);
    expect(pathForm).toBeLessThan(hostForm);
  });

  it('the Android intent names the real applicationId', () => {
    expect(appBuildGradle).toContain('applicationId = "com.driveusa.app"');
    expect(landingPage).toContain("const ANDROID_PACKAGE = 'com.driveusa.app'");
    // The old value was a package that does not exist.
    expect(landingPage).not.toContain("package=com.license.prep.app");
  });

  it('does not bounce to a URL the app cannot read', () => {
    // The old fallback sent the browser to
    // https://licenseprepapp.web.app/resetPassword?oobCode=..., which is not a
    // route: Hosting's catch-all serves the Flutter app, hash routing means
    // the path never reaches its router, and the redirect dropped `mode` on
    // the way -- observed landing on a page reporting "Mode: Not provided".
    // Asserted on the CODE, not the prose: the comment above names the old URL
    // on purpose, and a bare `toContain` matched it. (The Dart side of this
    // work hit the same trap -- a guard that its own explanation failed.)
    const code = landingPage
      .split('\n')
      .filter((l) => !l.trim().startsWith('//'))
      .join('\n');
    expect(code).not.toMatch(/location\.href\s*=\s*[`'"]https:\/\/licenseprepapp\.web\.app/);
  });
});

describe('the trap that wastes an afternoon', () => {
  it('Hosting rewrites cannot match query strings, so these entries are inert', () => {
    // firebase.json carries `/__/auth/action?**` and
    // `?mode=resetPassword&oobCode=**`. Hosting matches on PATH only, so they
    // all collapse onto the plain path rule. They read like mode-aware routing
    // and are not -- the mode handling lives in the page, not the config.
    const rewrites: Array<{ source: string }> = firebaseJson.hosting.rewrites;
    const queryRewrites = rewrites.filter(
      (r) => r.source.startsWith(AUTH_ACTION_PATH) && r.source.includes('?'),
    );
    const plainPath = rewrites.findIndex((r) => r.source === AUTH_ACTION_PATH);

    for (const q of queryRewrites) {
      expect(rewrites.indexOf(q)).toBeGreaterThan(plainPath);
    }
  });

  it('Flutter web still uses hash routing, which is WHY the SPA cannot serve this path', () => {
    // If someone later calls usePathUrlStrategy, the nginx rule above becomes
    // a real choice rather than the only working option -- and this test
    // failing is the prompt to revisit it.
    const libDir = path.join(repoRoot, 'lib');
    const walk = (dir: string): string[] =>
      fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
        e.isDirectory()
          ? walk(path.join(dir, e.name))
          : e.name.endsWith('.dart')
            ? [fs.readFileSync(path.join(dir, e.name), 'utf8')]
            : [],
      );
    const allDart = walk(libDir).join('\n');

    expect(allDart).not.toContain('usePathUrlStrategy');
    expect(allDart).not.toContain('PathUrlStrategy');
  });
});
