/**
 * The site's facts and pages. Two tests tie it to the app's code, so the
 * site can't drift from what the app does: the state list
 * (lib/data/state_data.dart) and the trial length
 * (lib/services/subscription_management_service.dart).
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
// @ts-expect-error plain ESM build script
import { buildPages, STATES } from '../scripts/pages.mjs';
// @ts-expect-error plain ESM build script
import { LOCALES, STORE } from '../scripts/locales.mjs';

const APP = resolve(__dirname, '../..');
const i18n = (code: string) => JSON.parse(readFileSync(resolve(__dirname, `../src/i18n/${code}.json`), 'utf8')) as Record<string, string>;
const pages: Record<string, string> = buildPages();

describe('copy', () => {
  const en = i18n('en');
  it.each(LOCALES.map((l: { code: string }) => l.code))('%s has every key, none empty', (code) => {
    const t = i18n(code);
    expect(Object.keys(t).sort()).toEqual(Object.keys(en).sort());
    for (const [k, v] of Object.entries(t)) {
      if (k === 'footer.policyNote' && code === 'en') continue;
      expect(v.trim(), `${code} ${k}`).not.toBe('');
    }
  });
  it('the policy note shows only where the policy is in another language', () => {
    expect(en['footer.policyNote']).toBe('');
  });
});

describe('facts match the app', () => {
  it('the 20 states are the app\'s release list, in its order', () => {
    const dart = readFileSync(resolve(APP, 'lib/data/state_data.dart'), 'utf8');
    const block = dart.match(/releasedStateIds = \{([^}]*)\}/)![1];
    const ids = [...block.matchAll(/'([A-Z]{2})'/g)].map((m) => m[1]);
    expect(STATES.map((s: string[]) => s[0])).toEqual(ids);
    expect(ids).toHaveLength(20);
  });
  it('the trial is the app\'s 3 days', () => {
    const dart = readFileSync(resolve(APP, 'lib/services/subscription_management_service.dart'), 'utf8');
    expect(dart).toMatch(/trialDurationDays = 3;/);
    expect(pages['index.html']).toContain('data-count="3"');
    expect(i18n('en')['hero.trial']).toMatch(/^3 days free/);
  });
  it('the 5 languages are the app\'s locales', () => {
    for (const l of LOCALES) expect(() => readFileSync(resolve(APP, `lib/localization/l10n/${l.code}.json`))).not.toThrow();
  });
});

describe('pages', () => {
  it('builds the 5 welcome pages, the privacy and terms pages and the sitemap', () => {
    expect(Object.keys(pages).sort()).toEqual(['es/index.html', 'index.html', 'pl/index.html', 'privacy/index.html', 'ru/index.html', 'sitemap.xml', 'terms/index.html', 'uk/index.html']);
  });
  it.each(LOCALES.map((l: { code: string; dir: string }) => [l.code, l.dir ? `${l.dir}/index.html` : 'index.html']))('%s page is complete', (code, file) => {
    const html = pages[file];
    expect(html).not.toMatch(/\{\{/);
    expect(html).toContain(`<html lang="${code}">`);
    expect(html.match(/hreflang="[a-z-]+" href=/g)).toHaveLength(6);
    expect(html).toContain(STORE.ios);
    expect(html).toContain(STORE.android);
    expect(html).toContain('href="/privacy/"');
    expect(html).toContain('href="/terms/"');
    expect(html.match(/class="card step"/g)).toHaveLength(4);
    expect(html.match(/<li title="/g)).toHaveLength(20);
    expect(html).toContain(i18n(code)['story.soon']);
  });
  it('every screenshot, image and font a page uses exists', () => {
    for (const [file, html] of Object.entries(pages)) {
      for (const m of html.matchAll(/(?:src|href)="(\/(?:shots|img|fonts)\/[^"]+|\/[a-z0-9-]+\.(?:png|js|txt))"/g)) {
        expect(() => readFileSync(resolve(__dirname, '../public', '.' + m[1])), `${file} → ${m[1]}`).not.toThrow();
      }
    }
  });
  it('each language shows its own 4 screens, in the app\'s tab order', () => {
    for (const l of LOCALES) {
      const html = pages[l.dir ? `${l.dir}/index.html` : 'index.html'];
      const shots = [...html.matchAll(/src="\/shots\/([a-z]+)\/([a-z]+)\.webp"/g)];
      expect(shots.map((m) => m[1])).toEqual(Array(4).fill(l.code));
      expect(shots.map((m) => m[2])).toEqual(['tests', 'theory', 'instructors', 'profile']);
      expect(html.match(/class="dot"/g)).toHaveLength(4);
    }
  });
  it('the privacy page keeps the policy\'s dates and is English', () => {
    const html = pages['privacy/index.html'];
    expect(html).toContain('<html lang="en">');
    expect(html).toContain('Last Updated: October 20, 2026');
    // Google Play's Data safety "Delete account URL" points here.
    expect(html).toMatch(/id="delete-account">5\.1 How to Delete Your Account/);
    expect(html).not.toMatch(/\{\{/);
  });
  it('the terms page keeps its effective date, has the Last Updated date §9 refers to, is English and links back to privacy', () => {
    const html = pages['terms/index.html'];
    expect(html).toContain('<html lang="en">');
    expect(html).toContain('Effective Date: March 17, 2026');
    expect(html).toContain('Last Updated: October 20, 2026');
    expect(html).toContain('href="/privacy/"');
    expect(html).not.toMatch(/\{\{/);
  });
  it('the Terms describe the trial the app actually has (no automatic charge)', () => {
    const html = pages['terms/index.html'];
    expect(html).not.toMatch(/automatically charged/i);
    expect(html).toContain('No payment method is required to start the trial');
    expect(html).toContain('$9.99 per month');
  });
  it('every contact address is the domain one (never the old Gmail)', () => {
    for (const html of Object.values(pages)) expect(html).not.toContain('@gmail.com');
  });
  it('the trial line matches the app: free on sign-up, no store purchase', () => {
    // The trial is granted server-side at sign-up (functions/src/index.ts
    // createTrialSubscription) and never charges by itself, so the site must not say
    // "cancel in the store" about it.
    for (const l of LOCALES) expect(i18n(l.code)['hero.trial']).not.toMatch(/App Store|Google Play/);
  });
  it('loads nothing from another host (no trackers, no web fonts)', () => {
    for (const html of Object.values(pages)) {
      for (const m of html.matchAll(/(?:src|href)="(https?:[^"]+)"/g)) {
        expect(m[1], 'only links, never loaded resources').toMatch(/^https:\/\/(driveusallc\.com|apps\.apple\.com|play\.google\.com)\//);
      }
      expect(html).not.toMatch(/<script[^>]+src="https?:/);
      expect(html).not.toMatch(/<link[^>]+rel="stylesheet"[^>]+href="https?:/);
    }
  });
});
