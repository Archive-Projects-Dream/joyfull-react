import { defineConfig } from 'vite';

export default defineConfig({
  base: './', // Для корректной работы при деплое на GitHub Pages или любой статический хостинг
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
  }
});