/**
 * Builds every page as real HTML: the welcome page once per language
 * (`/`, `/es/`, `/pl/`, `/ru/`, `/uk/`) and the privacy policy (`/privacy/`,
 * English — the binding version). Vite then bundles the CSS/JS they load.
 *
 *   node scripts/pages.mjs
 *
 * Templates: src/template.html, src/privacy.html, partials in src/partials/.
 * `{{key}}` is a key of src/i18n/<code>.json (HTML-escaped); `{{=NAME}}` is a
 * block built here.
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LINE_ART, ICONS, beep, esc } from './art.mjs';
import { LOCALES, ORIGIN, STORE } from './locales.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(resolve(ROOT, p), 'utf8');
const i18n = Object.fromEntries(LOCALES.map((l) => [l.code, JSON.parse(read(`src/i18n/${l.code}.json`))]));

/** The 20 released states, in the app's order (lib/data/state_data.dart:11-14). */
export const STATES = [
  ['CA', 'California'], ['TX', 'Texas'], ['FL', 'Florida'], ['NJ', 'New Jersey'], ['PA', 'Pennsylvania'],
  ['WA', 'Washington'], ['MI', 'Michigan'], ['AZ', 'Arizona'], ['OH', 'Ohio'], ['NC', 'North Carolina'],
  ['MA', 'Massachusetts'], ['MD', 'Maryland'], ['IL', 'Illinois'], ['NY', 'New York'], ['GA', 'Georgia'],
  ['VA', 'Virginia'], ['CO', 'Colorado'], ['NV', 'Nevada'], ['OR', 'Oregon'], ['MN', 'Minnesota'],
];

/** The app's own onboarding screenshots per language (assets/images/onboarding/<code>/), 540 px, in the app's tab order. */
const SHOTS = ['tests', 'theory', 'instructors', 'profile'];
/** Phone screen → Beep's pose while it shows (coach = the driving-school Beep). */
const SHOT_POSE = { tests: 'pass', theory: 'study', instructors: 'coach', profile: 'wave' };

const href = (l) => (l.dir ? `/${l.dir}/` : '/');

function badges(t, light) {
  const apple = '<svg aria-hidden="true" focusable="false" viewBox="0 0 24 24"><path fill="currentColor" d="M16.37 12.6c-.02-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.73-1.35-.14-2.64.8-3.33.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.19-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.6 2.25 2.75 2.2 1.1-.04 1.52-.71 2.85-.71 1.33 0 1.71.71 2.87.69 1.19-.02 1.94-1.08 2.66-2.14.84-1.23 1.19-2.42 1.21-2.48-.03-.01-2.31-.89-2.33-3.53zM14.18 6.13c.61-.74 1.02-1.76.91-2.78-.88.04-1.94.59-2.57 1.32-.56.65-1.06 1.69-.93 2.69.98.08 1.98-.5 2.59-1.23z"/></svg>';
  const play = '<svg aria-hidden="true" focusable="false" viewBox="0 0 24 24"><path fill="currentColor" d="M3.6 2.3c-.2.2-.3.6-.3 1v17.4c0 .4.1.8.3 1l9.5-9.7L3.6 2.3zm10.6 8.6 2.7-2.7L5.1 1.5c-.3-.2-.7-.2-1 0l10.1 9.4zm0 2.2L4.1 22.5c.3.2.7.2 1 0l11.8-6.7-2.7-2.7zm6.4-2.8-2.5-1.4-3 3 3 3 2.5-1.5c.9-.5.9-1.6 0-2.1z"/></svg>';
  // Placeholders in the official badges' shape until Apple's and Google's own
  // badge artwork is added (their marketing guidelines require it).
  return `<div class="badges${light ? ' on-blue' : ''}">
    <a class="store" href="${STORE.ios}" rel="noopener" aria-label="${esc(t['badge.ios'])}">${apple}<span><small>Download on the</small>App Store</span></a>
    <a class="store" href="${STORE.android}" rel="noopener" aria-label="${esc(t['badge.android'])}">${play}<span><small>Get it on</small>Google Play</span></a>
  </div>`;
}

function langMenu(current, label, path) {
  const items = LOCALES.map((l) => `<li><a href="${path(l)}" hreflang="${l.code}" lang="${l.code}"${l.code === current ? ' aria-current="true"' : ''}>${l.name}</a></li>`).join('');
  const cur = LOCALES.find((l) => l.code === current);
  return `<details class="lang"><summary aria-label="${esc(label)}: ${cur.name}"><svg aria-hidden="true" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2c2.8 3 4 6.3 4 10s-1.2 7-4 10c-2.8-3-4-6.3-4-10s1.2-7 4-10z"/></g></svg><span>${cur.code.toUpperCase()}</span></summary><ul>${items}</ul></details>`;
}

function fill(tpl, t, blocks) {
  return tpl
    .replace(/\{\{=([A-Z_]+)\}\}/g, (_, k) => {
      if (!(k in blocks)) throw new Error(`unknown block ${k}`);
      return blocks[k];
    })
    .replace(/\{\{([a-zA-Z0-9.]+)\}\}/g, (_, k) => {
      if (!(k in t)) throw new Error(`missing i18n key ${k}`);
      return esc(t[k]);
    });
}

function partials(code, t, homeHref, menu) {
  return {
    HEADER: fill(read('src/partials/header.html'), t, { HOME: homeHref, LANG_MENU: menu, ICON_ARROW: ICONS['alt-arrow-right-linear'] }),
    FOOTER: fill(read('src/partials/footer.html'), t, {
      HOME: homeHref,
      PRIVACY: '/privacy/',
      POLICY_NOTE: t['footer.policyNote'] ? `<p class="note">${esc(t['footer.policyNote'])}</p>` : '',
      YEAR: String(new Date().getUTCFullYear()),
    }),
  };
}

function head(code, t, path, alternates) {
  return `<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(t['meta.title'])}</title>
<meta name="description" content="${esc(t['meta.description'])}">
<link rel="canonical" href="${ORIGIN}${path}">
${alternates}
<meta property="og:type" content="website">
<meta property="og:site_name" content="Drive USA">
<meta property="og:title" content="${esc(t['meta.title'])}">
<meta property="og:description" content="${esc(t['meta.description'])}">
<meta property="og:url" content="${ORIGIN}${path}">
<meta property="og:image" content="${ORIGIN}/img/og.png">
<meta property="og:locale" content="${{ en: 'en_US', es: 'es_US', pl: 'pl_PL', ru: 'ru_RU', uk: 'uk_UA' }[code]}">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#F2F4F8">
<meta name="apple-itunes-app" content="app-id=6756199100">
<link rel="icon" href="/favicon.ico" sizes="48x48">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
<link rel="icon" type="image/png" sizes="192x192" href="/favicon-192.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="preload" href="/fonts/rubik.woff2" as="font" type="font/woff2" crossorigin>
<script src="/boot.js"></script>`;
}

const homeAlternates = LOCALES.map((l) => `<link rel="alternate" hreflang="${l.code}" href="${ORIGIN}${href(l)}">`).join('\n') +
  `\n<link rel="alternate" hreflang="x-default" href="${ORIGIN}/">`;

export function buildPages() {
  const out = {};
  const home = read('src/template.html');
  for (const l of LOCALES) {
    const t = i18n[l.code];
    const shots = SHOTS.map((s, i) => `<img class="shot${i ? '' : ' on'}" src="/shots/${l.code}/${s}.webp" width="540" height="1174" draggable="false" alt="${esc(t['phone.label'])}: ${esc(t[`shot.${s}`])}" data-pose="${SHOT_POSE[s]}"${i ? ' loading="lazy" aria-hidden="true"' : ''}>`).join('');
    const dots = SHOTS.map((s, i) => `<button type="button" class="dot" role="tab" aria-selected="${i ? 'false' : 'true'}" aria-label="${esc(t[`shot.${s}`])}"></button>`).join('');
    const story = [1, 2, 3, 4].map((n) => `<li class="card step" data-step>
      <div class="art">${LINE_ART[n - 1]({ ready: t['story.ready'] }).replace('<svg ', '<svg aria-hidden="true" focusable="false" ')}</div>
      <span class="num">0${n}</span>
      <h3>${esc(t[`story.s${n}.t`])}${n === 3 ? ` <span class="soon">${esc(t['story.soon'])}</span>` : ''}</h3>
      <p>${esc(t[`story.s${n}.d`])}</p>
    </li>`).join('\n');
    const blocks = {
      LANG: l.code,
      HEAD: head(l.code, t, href(l), homeAlternates),
      ...partials(l.code, t, href(l), langMenu(l.code, t['nav.lang'], href)),
      BADGES: badges(t, false),
      BADGES_LIGHT: badges(t, true),
      SHOTS: shots,
      DOTS: dots,
      BEEP_HERO: beep(['pass', 'study', 'coach', 'wave'], 'beep hero-beep'),
      BEEP_CTA: beep(['pass'], 'beep cta-beep'),
      STORY: story,
      STATES: STATES.map(([c, n]) => `<li title="${n}">${c}</li>`).join(''),
      LANGUAGES: LOCALES.map((x) => `<li lang="${x.code}">${x.name}</li>`).join(''),
      ICON_TESTS: ICONS['clipboard-check-linear'],
      ICON_THEORY: ICONS['book-2-linear'],
      ICON_LANG: ICONS['chat-round-line-linear'],
      ICON_STATES: ICONS['layers-minimalistic-linear'],
      ICON_CHECK: ICONS['check-linear'],
      ICON_CLOCK: ICONS['clock-circle-linear'],
    };
    out[l.dir ? `${l.dir}/index.html` : 'index.html'] = fill(home, t, blocks);
  }
  // Privacy Policy and Terms of Use: English only (the binding versions),
  // moved unchanged from Google Sites; the language menu leads to each
  // language's welcome page.
  const t = i18n.en;
  const docs = [
    ['privacy', 'src/privacy.html', 'Privacy Policy — Drive USA', 'How Drive USA (DEMROS WEST LLC) collects, uses and protects your information.'],
    ['terms', 'src/terms.html', 'Terms of Use — Drive USA', 'The Terms of Use for the Drive USA app (DEMROS WEST LLC).'],
  ];
  for (const [slug, src, title, description] of docs) {
    const dt = { ...t, 'meta.title': title, 'meta.description': description };
    out[`${slug}/index.html`] = fill(read(src), dt, {
      LANG: 'en',
      HEAD: head('en', dt, `/${slug}/`, ''),
      ...partials('en', t, '/', langMenu('en', t['nav.lang'], href)),
    });
  }
  out['sitemap.xml'] = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${LOCALES.map((l) => `  <url><loc>${ORIGIN}${href(l)}</loc>${LOCALES.map((a) => `<xhtml:link rel="alternate" hreflang="${a.code}" href="${ORIGIN}${href(a)}"/>`).join('')}</url>`).join('\n')}
  <url><loc>${ORIGIN}/privacy/</loc></url>
  <url><loc>${ORIGIN}/terms/</loc></url>
</urlset>
`;
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  for (const [file, html] of Object.entries(buildPages())) {
    // sitemap.xml goes to public/ so Vite copies it as-is.
    const target = file.endsWith('.xml') ? resolve(ROOT, 'public', file) : resolve(ROOT, file);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, html);
  }
  console.log('pages: built', Object.keys(buildPages()).join(', '));
}
