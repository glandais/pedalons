---
id: WEB-39
title: "Un backend lent affichait le visiteur déconnecté au rendu serveur"
status: done
group: "Défauts d'interface"
done: 2026-10-11
---

## Livré

`WEB-39` **Un backend lent affichait le visiteur déconnecté au rendu serveur** (2026-10-11, sans
changement de contrat) — quand le `/api/auth/refresh` du SSR dépassait 3 s (`TIMEOUT_MS`),
`resolveSsrSession` rendait la même réponse que pour un jeton refusé : page anonyme, annoncée
comme telle dans `window.__AUTH_STATE__`, donc pas de refresh côté client. Le membre voyait un
en-tête anonyme et son équipe privée en **404** jusqu'au document suivant (observé le 2026-09-30
sous charge e2e, `slug-change.e2e.ts:226`). `resolveSsrSession` distingue désormais **pas de
session** (pas de cookie, 401/403, ou réponse sans jeton : `ANONYMOUS`, transmis au client) de
**session inconnue** (délai, réseau, tout autre statut : `undefined`). Dans le second cas,
`entry-server.tsx` laisse `SsrRequestStore.auth` vide : la page est rendue avec l'état anonyme
par défaut (`isLoading`, le même des deux côtés, donc l'hydratation tient), sans
`__AUTH_STATE__`, et le client fait son propre refresh puis revalide le cache (`AuthEffects`).
Le 404 d'une équipe refusée par l'API n'est plus posé quand la session est inconnue. La perte de
session décrite à l'origine (un `Set-Cookie` perdu changé en rejeu, `SEC-27`) a disparu avec
`API-94` : le jeton gardé par le navigateur refait une rotation au lieu de révoquer la session,
donc rien n'oblige à relayer le `Set-Cookie` d'un refresh abandonné. `frontend/docs/SSR.md` est
mis à jour (et sa vérification curl d'un cookie invalide, qui attendait l'absence de
`__AUTH_STATE__` alors que l'état anonyme y est sérialisé). Couvert par `ssrSession.test.ts`
(401/403 → anonyme ; 5xx, 429 et délai → session laissée au client, sans `Set-Cookie`).
**À ne pas défaire** : ne jamais annoncer au client une session anonyme qu'on n'a pas
constatée (un 401/403) ; ne pas poser de 404 d'équipe sur un rendu dont la session est inconnue.
