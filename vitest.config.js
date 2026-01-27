import {defineConfig} from 'vitest/config';
import vue from '@vitejs/plugin-vue';
import path from 'path';
import {fileURLToPath} from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'jsdom',
    globals: true
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './assets')
    }
  }
});
