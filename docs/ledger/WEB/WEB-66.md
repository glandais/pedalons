---
id: WEB-66
title: "Un onglet ouvert avant un déploiement tombait sur l'écran d'erreur"
status: done
group: "Défauts d'interface"
done: 2026-10-06
---

## Livré

`WEB-66` **Un onglet ouvert avant un déploiement tombait sur l'écran d'erreur** (feedback #9,
2026-10-06) — les chunks paresseux de l'ancien build (`UserProfilePage-<hash>.js`) ne sont plus
servis après un déploiement, et la route suivante levait « Failed to fetch dynamically imported
module ». `lib/staleChunk.ts` recharge la page, sur `vite:preloadError` comme dans
`ErrorBoundary`, au plus une fois par 30 s (garde en `sessionStorage`) : si le chunk manque encore
après le rechargement, l'erreur s'affiche et se remonte normalement. Test :
`staleChunk.test.ts`. **À ne pas défaire** : la garde anti-boucle.
