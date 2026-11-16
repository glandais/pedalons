---
id: WEB-31
title: "Un `sitemap.xml` par site"
status: done
group: "Référencement"
done: 2026-09-30
---

## Livré

`WEB-31` **Un `sitemap.xml` par site** (2026-09-30, API `6.2.0`) — `GET /api/sitemap`
(`SitemapService`) liste ce qu'un moteur peut indexer sur le site de la requête : les équipes
`PUBLIC`, leur page « à propos », leurs pages, sorties, articles, voyages et étapes publics. Chaque type passe par la requête de liste de son dépôt (`TeamEntityRepository.findIndexable`,
requête anonyme, projection seule) : visibilité, statut, modération et modules sont ceux de la
liste, le sitemap ne peut pas annoncer une page que le site refuserait. S'y ajoute
`te.team.visibility = 'PUBLIC'` même sur un hôte épinglé, où la liste laisse passer une équipe non
listée dont toutes les pages sont pourtant `noindex` (`WEB-4`). Une étape n'a pas de visibilité
propre : elle est listée sous un voyage qui l'est. Plafond de 50 000 entrées (limite du protocole),
les plus récentes d'abord. **Jamais les annonces** (lues entre membres seulement), **ni les
parcours** (une carte et un GPX plutôt qu'un texte à indexer ; décision du 30 septembre 2026),
**ni les pages carte** (`…/carte`) : aucun type d'entrée ne les désigne. Le serveur SSR sert `/sitemap.xml`
(`renderSitemap` dans `entry-server.tsx`, XML par `lib/sitemap.ts`) avec les chemins **français**
seulement — la langue servie à un robot, et les deux variantes de chemin rendent la même page —,
sans préfixe d'équipe sur un hôte épinglé (`toBrowser`), en cache public une heure ; et
`/robots.txt`, dont les règles restent dans `public/robots.txt`, avec la ligne `Sitemap:` de l'hôte
ajoutée à la volée (le protocole veut une URL absolue). Couvert par `SitemapServiceTest`
(contenu, parcours, annonces, contenu non public, équipes non publiques, étapes d'un voyage caché, hôte
épinglé, hôte épinglé d'une équipe non listée) et `lib/sitemap.test.ts` (chemins, ni parcours ni
page carte, hôte épinglé, échappement). Ne pas y ajouter les parcours, les pages carte ni les
annonces ; ne pas
construire les entrées par une requête écrite à la main plutôt que par `findIndexable`.
