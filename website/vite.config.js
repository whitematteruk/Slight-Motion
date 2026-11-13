import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { siteUrl } from './scripts/site-url.mjs'

export default defineConfig({
  base: siteUrl.pathname,
  plugins: [vue()],
})
