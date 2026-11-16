---
id: WEB-35
title: "Les e2e ne cliquent plus avant la fin de l'hydratation"
status: done
group: "Outillage"
done: 2026-09-30
---

## Livré

`WEB-35` **Les e2e ne cliquent plus avant la fin de l'hydratation** (2026-09-30) — le tiroir
mobile de `flow-notifications.e2e.ts` (:59, puis :475 en relance) ne s'ouvrait pas une fois sur
quelques centaines sous charge : le burger disait encore « Ouvrir le menu » juste après le clic,
avant toute réponse réseau. Cause : `hydrated()` (`e2e/support/ui.ts`) attendait la clé
`__reactProps` du nœud, que React pose **pendant le rendu d'hydratation, avant son commit** ; un
clic dans cet intervalle est perdu, pas rejoué. Mesuré par une sonde (clic dès `hydrated()`,
mobile, ×40) : 3 clics perdus, tous sur une fibre pas encore validée (`alternate` nul), 37 réussis,
tous sur une fibre validée. Correctif à la cause, sans retry ni délai : `HydrationMarker`
(`src/components/common/HydrationMarker.tsx`, dernier enfant de la racine dans
`entry-client.tsx`) pose `<html data-hydrated="true">` dans un effet, donc après le commit de tout
l'arbre, côté client seulement (jamais dans le HTML du SSR), une fois ; le rendu sans hydratation
(`createRoot`) le pose aussi. `hydrated()` attend ce marqueur **et** la clé, `pageHydrated()` le
marqueur au lieu de la clé du conteneur (posée dès l'appel à `hydrateRoot`). Même sonde après :
40/40. Validation : `flow-notifications`, `flow-moderation`, `flow-account` et `flow-posts` en mobile ×20 sous charge (les ouvertures du burger comprises), 1 280/1 280 ; puis la suite complète, 1 580 réussis, 0 échec. À ne pas défaire : ne pas revenir à la seule clé
`__reactProps` comme signal d'interactivité. Le défaut côté utilisateur (un tap trop tôt est
ignoré) reste ouvert : `WEB-36`.
**Instables observés une fois sous charge, non reproduits, non désactivés** : les 10 tests relevés
pendant `API-16` — `routes-render.e2e.ts:692` (8 cas : l'onglet des modèles de l'admin d'équipe,
refus « only the team organizers/admins manage it », `rideNew` en organisateur, une redirection
d'`unauthenticated route`), `ssr-session.e2e.ts:191` (« home: the server blocks survive hydration
untouched ») et `flow-rides.e2e.ts:1267` (mobile) — 0 échec dans la suite complète sur `b167aa06`
puis 0 sur 40 exécutions sous charge (`--repeat-each=4`, 8 workers) ; leurs traces d'origine sont
perdues, la cause n'est pas établie. `flow-posts.e2e.ts:69` (mobile, dialogue « Supprimer » sans
nom accessible, menu resté ouvert) : 0 sur 6 sous charge ; hypothèse non prouvée, un clic tombé
avant un commit, ce que `WEB-35` ferme aussi. À rouvrir sur une nouvelle occurrence, trace en main.
