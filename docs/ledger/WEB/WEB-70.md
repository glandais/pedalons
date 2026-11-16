---
id: WEB-70
title: "Dates des métadonnées SEO et `og:` en UTC"
status: done
group: "Référencement"
done: 2026-10-06
---

## Livré

`WEB-70` **Dates des métadonnées SEO et `og:` en UTC** (2026-10-06, lot 0 du plan
[fuseau des événements](../../plans/archive/2026-10-06-event-timezones.md)) — `formatDate` de
`config/routeMeta.ts` formatait sans `timeZone`, donc en UTC sur le serveur SSR : une sortie à
00:30 heure de Paris était annoncée la veille dans le titre et l'aperçu de lien. Les dates y sont
formatées en `Europe/Paris` (`META_TIME_ZONE`) en attendant le fuseau de l'entité (`API-60`).
Couvert par `routeMeta.test.ts` (« ride date in the link preview »). **À ne pas défaire** : ni le
fuseau du serveur ni celui du lecteur pour un aperçu de lien.
