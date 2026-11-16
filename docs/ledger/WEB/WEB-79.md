---
id: WEB-79
title: "Sortie à un seul groupe : la page de la sortie est celle du groupe"
status: done
group: "Accueil et page Fonctionnalités"
done: 2026-10-13
---

## Livré

`WEB-79` **Sortie à un seul groupe : la page de la sortie est celle du groupe** (13 octobre 2026,
contrat inchangé). Prédicats uniques dans `utils/soloGroup.ts` (réexportés par
`rideDetailData.ts`) : `soloGroup` (le groupe si `groups.length == 1`), `leavesGroupPage`
(`<= 1`), `ownLeg` (leg sans `groupId` d'une sortie sans groupe, ou leg du groupe solo). Pour une
sortie solo, `RideDetailPage` remplace la carte de groupe par `RideSoloGroupPanel` : nom et
couleur du tracé (sans lien), inscription Rejoindre / Quitter / Complet par `groupAction`,
places, meneur seulement si `leader`, actions du parcours, puis les statistiques du groupe
(arrivée tirée de `soloLeg`) et les participants en ligne (`?q`/`?p`) ; carte avec profil quand
il n'y a qu'un tracé ; `RideWeatherSection` déroule `ownLeg` dans un bloc `#meteo`
(`useScrollToAnchor`). Les morceaux de la page groupe sont extraits dans `components/ride/group/`
(GroupStats, GroupPlaces, GroupLeader, GroupJoinActions, GroupParticipantsSection,
GroupRouteMap). `prefetchRideDetail` prend l'`url` et précharge la page 0 des participants du
groupe solo (une requête, clé `groupParticipantsParams`). Redirection : `RouteConfig.dataRedirect`,
appelé par `makeLoader` après le prefetch, branché sur `ride-group` (`rideGroupDataRedirect`) —
302 vers la sortie, query string gardé, au SSR comme en navigation client ; repli client dans
`RideGroupPage` (`useEffect` + `navigate(replace)`, garde search et hash, rejoue si une relecture
fait tomber la sortie à un groupe). La méta d'une sortie solo porte allure et km du groupe
(`groupFacts`). Clé i18n `rides.detail.groups.soloLabel`. Plusieurs groupes : rien ne change.
Tests : `rideDetailData.test.ts`, `rideGroupData.test.ts`, `makeLoader.test.ts`,
`RideDetailPage.test.tsx`, `RideGroupPage.test.tsx` (redirections, dont « still leaves when the
ride, first read with two groups, comes back with one »), `RideWeatherSection.test.tsx`,
`routeMeta.test.ts` ; e2e `rides`, `flow-routes`, `pinned-host` adaptés (verts au 16 octobre
2026, comme `WEB-78`). **À ne pas défaire** : l'exception « météo du parcours sur la page sortie » couvre
**0 et 1** groupe ; aucun lien interne vers la page groupe d'une sortie solo ; la redirection
est **302 / replace, jamais 301** (un deuxième groupe ajouté plus tard refait de l'URL une vraie
page) ; sur navigation client, le loader perd `#meteo` (React Router retire le fragment de la
`Request`), limite acceptée faute de lien interne qui y mène.
