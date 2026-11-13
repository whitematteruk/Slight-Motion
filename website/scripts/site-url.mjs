export const defaultSiteUrl = 'https://slight-motion.cubiceft1.chatgpt.site/'
export const siteUrl = new URL(process.env.SITE_URL || defaultSiteUrl)

if (!['https:', 'http:'].includes(siteUrl.protocol) || siteUrl.search || siteUrl.hash || siteUrl.username || siteUrl.password) {
  throw new Error('SITE_URL must be an HTTP or HTTPS URL without credentials, a query, or a fragment.')
}

if (!siteUrl.pathname.endsWith('/')) siteUrl.pathname += '/'
