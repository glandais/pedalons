---
id: WEB-85
title: "Une URL canonique par page, et les pages utilitaires hors de l'index"
status: done
group: "Référencement"
done: 2026-10-15
---

## Livré

`WEB-85` **Une URL canonique par page, et les pages utilitaires hors de l'index** (2026-10-15,
sans changement de contrat) — la Search Console du 15 octobre 2026 classait `/teams` et
`/forgot-password` en « Page en double sans URL canonique » : aucune page n'émettait de
`<link rel="canonical">`, alors que chaque route a deux chemins (`/equipes` et `/teams`,
`contracts/routes.yaml`), et `/forgot-password`, `/routes` et les autres pages utilitaires
annonçaient `index, follow`. `buildCanonicalUrl(routePaths, params, origin, pinned?)`
(`lib/seo.ts`) reconstruit le chemin depuis l'entrée de `routes.config.ts` de la route trouvée
(`generatePath` de React Router, pas de seconde table de routes), **toujours dans la langue par
défaut du site, le français** (`SITE_DEFAULT_LOCALE`, distinct du `DEFAULT_LOCALE = 'en'` de
`paths.generated.ts`), ou dans la seule langue qu'a la route, sans query string ; `og:url` le
reprend. `entry-server.tsx` le passe à `buildMetaTags` par `RouteMetaContext.canonical`. Sur un
hôte épinglé à une équipe, le préfixe d'équipe est retiré, et le canonical est abandonné si
`toRouter` ne ramène pas le chemin à la même route. Ce dernier contrôle a révélé un 404 :
`toRouter('/rides/x')` donnait `/equipes/n-peloton/rides/x` à un visiteur français, pour tout lien
écrit dans l'autre langue ; `config/pinnedHistory.ts` essaie maintenant la langue du visiteur et
ne la garde que si le résultat correspond à une route d'équipe de cette langue, sinon l'autre.
Passent en `noindex` : toute route qui n'est pas `auth: 'public'` (connexion, mot de passe
oublié, appareils Garmin/Karoo, profil, admin, création et édition…), les routes publiques
marquées du nouveau drapeau `noindex: true` de `routes.config.ts` (`verify-email`, `invitation`,
`biketeam-migration`, `reset-password`, `gpx-tools-view` et `gpx-tools-map` : le fichier d'un
membre, montré à qui a le lien, traité comme un contenu non listé), le catalogue global
`all-routes` et sa carte (`all-routes-map`), les listes de parcours d'une équipe (`routes`,
`routes-map`), et toute réponse qui n'est pas un 200 (un 404).
Couvert par `config/routeMeta.test.ts` (« canonical link » : même canonical français pour un
rendu fr et en, paramètres encodés, rien quand le chemin ne se reconstruit pas, hôte épinglé ;
canonical et `og:url` dans le head, pas de canonical sur une page `noindex` ; « routes kept out of
the index », une vérification par route) et `config/pinnedHistory.test.ts` (chaque route d'équipe
revient à elle-même, visiteur fr puis en ; un lien anglais pour un visiteur français ; un
canonical servable pour chaque route sur un hôte épinglé). La balise robots unique de `WEB-4` est
intacte. **À ne pas défaire** : le canonical ne dépend **ni** de la langue de rendu, **ni** du
cookie `lang`, **ni** d'`Accept-Language` — la langue d'une page vient de la préférence du compte,
du cookie puis d'`Accept-Language`, pas de l'URL (`WEB-31`), donc un canonical « dans la langue
rendue » aurait varié d'une requête à l'autre ; **pas de `hreflang`** tant que l'URL ne choisit
pas la langue (un robot servi en français sur `/teams/x` ignorerait l'alternate `en` : il faudrait
d'abord servir chaque URL dans sa langue à un visiteur sans préférence) ; **pas de canonical sur
une page `noindex`** ni hors d'un 200 — un canonical dit « indexe plutôt celle-ci », ce qui
contredit `noindex` et brouille le signal ; le catalogue `/routes` reste `noindex` (une même
liste de parcours sous autant d'URL que de combinaisons de filtres, et les parcours sont hors du
sitemap depuis `WEB-31`), de même que les listes de parcours d'une équipe ; **chaque parcours,
lui, reste indexable** (`route-detail`, `route-map`), même s'il n'est pas dans le sitemap
(décision du 15 octobre 2026).
