import { defineConfig } from 'vite';
import * as path from 'path';
import tailwindcss from "@tailwindcss/vite"
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  base: './',
  resolve: {
    alias: {
      'src': path.resolve(__dirname, './src')
    },
    extensions: ['.ts', '.tsx', '.json']
  },
  server: {
    host: 'localhost',
    port: 3000
  },
  build: {
    outDir: '../backend/templates/dist',
    manifest: true,
    minify: true,
    rollupOptions: {
      output: {
        entryFileNames: `[name].js`,
        assetFileNames: `[name].[ext]`
      }
    }
  }
});
