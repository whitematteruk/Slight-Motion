# Slight Motion

A Vue and Vite product site for a Mac menu bar app prototype. The gesture demo illustrates pinch, move, and release without requesting camera access.

```sh
npm ci
npm run dev
npm run build
npm run preview
```

The build prerenders the landing page into `dist/index.html`. Vue hydrates the interactive demo. The static output also includes a sitemap, self-hosted fonts, and social metadata.

The website is published through GitHub Actions at [whitematteruk.github.io/Slight-Motion](https://whitematteruk.github.io/Slight-Motion/). The deployment workflow sets `SITE_URL` so that Vite asset paths, canonical metadata, the social image, and the sitemap use the project URL. To preview that build locally, use the same `SITE_URL` for both commands:

```sh
SITE_URL=https://whitematteruk.github.io/Slight-Motion/ npm run build
SITE_URL=https://whitematteruk.github.io/Slight-Motion/ npm run preview
```
