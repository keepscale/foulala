import { defineConfig } from 'vite';

export default defineConfig({
  // Chemins relatifs : le site marche à la racine d'un domaine comme sous
  // keepscale.github.io/foulala/ (GitHub Pages sans domaine personnalisé).
  base: './',
  server: {
    port: 5173,
    strictPort: true,
    // design/tokens.json, design/logo.svg et les polices de app/ sont lus hors de web/
    fs: { allow: ['..'] },
  },
  build: {
    outDir: 'dist',
    assetsInlineLimit: 0,
  },
});
