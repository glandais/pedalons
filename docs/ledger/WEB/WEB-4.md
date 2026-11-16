---
id: WEB-4
title: "`PUBLIC_UNLISTED` n'est plus indexé"
status: done
group: "Référencement"
done: 2026-09-30
---

## Livré

`WEB-4` **`PUBLIC_UNLISTED` n'est plus indexé** (2026-09-30) — `frontend/index.html` servait un
`<meta name="robots" content="index, follow">` statique et rien n'émettait de `noindex` : une page
non listée, rendue en SSR, était indexable. La balise statique est retirée ; `buildMetaTags`
(`lib/seo.ts`) émet maintenant **l'unique** balise robots de la page, dans le bloc injecté à
`<!--ssr-head-->` (dans le `<head>`, donc lue sans JavaScript) : `noindex` si `RouteMeta.noindex`,
sinon `index, follow`. Les `meta()` de `routeMeta.ts` le posent d'après la visibilité du contenu
(équipe, page d'équipe, publication, sortie, voyage, étape — celle de son voyage —, parcours), et
`withIndexing`, appliqué par `entry-server` après le `meta()` de la route, l'ajoute à **toute**
page d'une équipe qui n'est pas `PUBLIC`, y compris celles sans `meta()` (listes, calendrier…) :
l'équipe est déjà dans le cache de la requête, lue pour la décision 404/301. Seul `PUBLIC` est
indexable : `TEAM` ne se rend que pour une session de membre, jamais pour un robot. Couvert par
`frontend/src/config/routeMeta.test.ts` (une seule balise robots dans le bloc, `noindex` pour un
contenu non listé, pour un contenu public d'une équipe non listée, et pour une page sans `meta()`
de cette équipe). Ne pas remettre de balise robots dans `index.html` : elle côtoierait la balise
par page et la contredirait. Le mode dev SPA sans SSR n'a pas de balise robots, ce qui vaut
`index, follow`.
