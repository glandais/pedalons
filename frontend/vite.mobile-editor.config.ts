import path from 'node:path'
import { defineConfig } from 'vite'

/**
 * Builds the editor the mobile app embeds in a WebView (`src/embed/mobile-editor`) into
 * `mobile/assets/editor/`: `pnpm build:mobile-editor`. The output is committed, like the other
 * generated files the app reads; rebuild it after touching the editor's extensions.
 *
 * One classic script (IIFE), no hash: the app loads `index.html` from its assets, by file URL.
 */
export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
  define: { 'process.env.NODE_ENV': JSON.stringify('production') },
  publicDir: path.resolve(import.meta.dirname, 'src/embed/mobile-editor/public'),
  build: {
    outDir: path.resolve(import.meta.dirname, '../mobile/assets/editor'),
    emptyOutDir: true,
    minify: true,
    copyPublicDir: true,
    lib: {
      entry: path.resolve(import.meta.dirname, 'src/embed/mobile-editor/main.ts'),
      formats: ['iife'],
      name: 'PedalonsEditor',
      fileName: () => 'editor.js',
      cssFileName: 'editor',
    },
  },
})
