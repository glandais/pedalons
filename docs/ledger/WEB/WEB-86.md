---
id: WEB-86
title: "`robots.txt` ferme l'API, sauf les images"
status: done
group: "Référencement"
done: 2026-10-15
---

## Livré

`WEB-86` **`robots.txt` ferme l'API, sauf les images** (2026-10-15) — 41 URL en 404 dans la
Search Console étaient des `/api/download/public/images/n-peloton/<id>/{size}` : le gabarit
`{size}` des `imageUrl`/`logoUrl`, laissé littéral dans l'état React Query sérialisé du HTML SSR
(`window.__REACT_QUERY_STATE__`), que Googlebot prend pour un lien ; une soixantaine d'autres
étaient des réponses JSON (`/api/teams`, `/api/version`, `/api/routes`…) et des GPX/FIT sous
`/api/download/public/assets/`. `frontend/public/robots.txt` pose `Disallow: /api/`, puis
`Allow` sur les trois préfixes d'images que référencent les pages : `/api/download/public/images/`,
`/api/download/public_unlisted/images/` (`AssetService.buildImageUrl`, contenu non listé) et
`/api/gpx-previews/*/thumbnail/` (`GpxPreviewDto.thumbnailUrl`) ; sous chacun, deux `Disallow`
pour `{size}` et `%7Bsize%7D`. La ligne `Sitemap` reste ajoutée par `server.js`. Le header côté
backend est `API-109`. Couvert par `lib/robots.test.ts`, qui lit le vrai fichier et applique la
règle standard (la plus longue correspondance gagne, `Allow` à égalité) : les trois préfixes
d'images ouverts, les six formes `{size}` et les URL JSON/GPX/FIT fermées, les pages ouvertes.
**À ne pas défaire** : ne pas fermer `/api/` sans ses `Allow` — `og:image` et `twitter:image`
pointent sur `/api/download/…/images/` (`resolveTemplateUrl` de `lib/seo.ts` remplace `{size}` par
1200), et les robots d'aperçu de lien qui respectent `robots.txt` (Twitterbot, LinkedInBot…)
perdraient l'image. Les règles `{size}` répètent le préfixe complet de l'image **exprès** : plus
courtes que l'`Allow`, elles perdraient contre lui.
