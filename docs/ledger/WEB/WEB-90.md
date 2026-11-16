---
id: WEB-90
title: "Le compteur de pages vues, sans cookie"
status: done
group: "Mesure d'audience du site"
done: 2026-10-15
---

## Livré

`WEB-90` **Le compteur de pages vues, sans cookie** (2026-10-15, avec le contrat `11.3.0`
d'`API-117` ; **coupé tant que le drapeau n'est pas posé**, ce qui est `OPS-41`) — plan
[`2026-10-15-web-analytics.md`](../../plans/2026-10-15-web-analytics.md) (§4, étape 3 du §8). Le site
ne savait pas quelles pages sont vues, ni sur quel domaine de club. `frontend/src/lib/analytics/`,
sans le `count.js` de GoatCounter et sans effet à l'import (il est dans le bundle SSR) :
`installPageViewCounter(router)` dans `getRouter()` (`App.tsx`), client seulement, compte la
première page sur `router.state` puis chaque navigation par `router.subscribe` (`PUSH` et `POP`
comptés, `REPLACE` de même route non ; une redirection de loader, y compris vers la route
quittée, comptée une fois ; une page vue arrivée pendant le délai d'une autre envoie celle-ci
aussitôt). `toCountHit` n'envoie que l'hôte et le **gabarit** de la route, où seul `:teamSlug`
est remplacé par le slug de l'équipe, publique ou privée, pris de `match.params` (donc aussi sur
un hôte épinglé) et gardé seulement s'il a la forme d'un slug ; jamais un autre paramètre, la
query string ni `document.title` ; `t` = `routeId` et propriété statique `auth` de la route,
jamais l'état de session ; `r` = origine du référent externe, au premier hit seulement ; `s` =
catégorie d'écran (borne haute de la tranche du tableau de bord : 600, 1000, 1920, 2560). Une
route sans `handle` n'est pas comptée ; la route `*` porte `NOT_FOUND_ROUTE_ID` et compte `/404`
(`RouteGenerator.tsx`). L'expéditeur (`sender.ts`) fait un `fetch` en `credentials: 'omit'`,
`referrerPolicy: 'no-referrer'`, `keepalive`, **jamais `sendBeacon`** ; rien ne part sans
`analytics` dans `/api/config`, sous Do Not Track, Global Privacy Control, l'opposition locale
(`pedalons-analytics-optout`, propre à ce navigateur et à ce site), un navigateur piloté
(`navigator.webdriver`) ou un hôte de bouclage. L'interrupteur d'opposition
(`components/analytics/AnalyticsPreference.tsx`, `useAnalyticsOptOut`) est sur
`/profil/vie-privee` et dans `PrivacyPolicyPage.tsx`, au-dessus du Markdown de la politique
(nouveau `beforeContent` de `LegalPage`, le Markdown étant aussi un asset du mobile), rendu à
l'état neutre côté serveur pour ne pas casser l'hydratation ; libellés FR/EN. Tests vitest :
`lib/analytics/countHit.test.ts` (toute la table des routes × `LOCALES`, paramètres sentinelles,
`teamSlug` mal formé), `countHit.pinned.test.ts` (hôte épinglé), `sender.test.ts` (options du
`fetch`, garde-fous, opposition après rechargement du module), `sender.localhost.test.ts`,
`importNoWindow.test.ts`, `pageViewCounter.test.ts` (routeur mémoire, dont « without the
analytics config »), `pages/legal/PrivacyPolicyPage.test.tsx` (interrupteur, signal du
navigateur, rendu serveur). E2e : `e2e/analytics-off.e2e.ts` (aucune requête `/count` sur la
pile e2e) — **écrit, pas encore lancé** ; il ne prouve que la configuration de la pile (le
`webdriver` et l'hôte de bouclage y coupent aussi l'envoi), l'effet du drapeau seul étant prouvé
par le vitest. **À ne pas défaire** : ni `location.pathname`, ni `document.title`, ni
`sendBeacon` (il enverrait le cookie `refresh_token` et l'URL entière en `Referer`), ni l'état de
session ; seul `:teamSlug` est substitué ; l'opposition n'est jamais stockée sur le compte.
**Comptes exacts, justifiés par une analyse d'anonymat** (décidé le 15 octobre 2026, plan §7 et
§5.1 ligne 5) : pas d'arrondi à la dizaine, parce que rien ne relie deux pages vues entre elles
(ni session, ni identifiant, ni ligne par page vue) ni une page vue à un compte (aucun champ de
compte, aucun état de connexion, base séparée), et que le responsable du traitement est le seul
lecteur. Si un second lecteur reçoit l'accès, l'analyse tombe et est à refaire avant (`WEB-91`).
Un slug d'équipe renommé coupe l'historique en deux chemins, accepté.
