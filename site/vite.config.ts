import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import { PAGES } from './scripts/locales.mjs';

// Every page is real HTML, generated per language by scripts/pages.mjs.
export default defineConfig({
  build: {
    rollupOptions: { input: Object.fromEntries(PAGES.map((p) => [p.name, resolve(import.meta.dirname, p.file)])) },
  },
  server: { port: 5176, strictPort: true },
  preview: { port: 5176, strictPort: true },
});
