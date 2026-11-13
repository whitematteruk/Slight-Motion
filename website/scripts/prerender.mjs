import { readFile, writeFile } from 'node:fs/promises'
import { render } from '../.prerender/entry-server.js'
import { defaultSiteUrl, siteUrl } from './site-url.mjs'

const indexPath = new URL('../dist/index.html', import.meta.url)
let html = await readFile(indexPath, 'utf8')
const canonical = siteUrl.href.replaceAll('&', '&amp;').replaceAll("'", '&#39;')

if (!html.includes('<!--slight-prerender-->')) throw new Error('Missing prerender marker.')
const rendered = await render()
html = html.replaceAll(defaultSiteUrl, () => canonical)
  .replace('<!--slight-prerender-->', () => rendered)

const output = [
  writeFile(indexPath, html),
  writeFile(new URL('../dist/sitemap.xml', import.meta.url),
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>${canonical}</loc></url></urlset>\n`),
]

// Crawlers only use robots.txt at the root of a host.
if (siteUrl.pathname === '/') {
  output.push(writeFile(new URL('../dist/robots.txt', import.meta.url),
    `User-agent: *\nAllow: /\nSitemap: ${new URL('sitemap.xml', siteUrl).href}\n`))
}

await Promise.all(output)
