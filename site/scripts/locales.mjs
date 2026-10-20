/** The site's languages, in the app's order, and the pages built from them. */
export const LOCALES = [
  { code: 'en', name: 'English', dir: '' },
  { code: 'es', name: 'Español', dir: 'es' },
  { code: 'pl', name: 'Polski', dir: 'pl' },
  { code: 'ru', name: 'Русский', dir: 'ru' },
  { code: 'uk', name: 'Українська', dir: 'uk' },
];

export const PAGES = [
  ...LOCALES.map((l) => ({ name: l.code, file: l.dir ? `${l.dir}/index.html` : 'index.html' })),
  { name: 'privacy', file: 'privacy/index.html' },
  { name: 'terms', file: 'terms/index.html' },
];

export const ORIGIN = 'https://driveusallc.com';
export const STORE = {
  ios: 'https://apps.apple.com/us/app/drive-usa-theory-and-practice/id6756199100',
  android: 'https://play.google.com/store/apps/details?id=com.driveusa.app',
};
