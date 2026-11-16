---
id: WEB-64
title: "Onglets « Sorties » et « Voyages » de la maquette"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-06
---

## Livré

`WEB-64` **Onglets « Sorties » et « Voyages » de la maquette** (6 octobre 2026, sans changement
de contrat d'API). Décision de l'utilisateur : deux routes de liste par type plutôt que le seul
fil filtré. `contracts/routes.yaml` gagne `teamRides` (`/equipes/{teamSlug}/sorties`,
`/teams/{teamSlug}/rides`) et `teamTrips` (`/equipes/{teamSlug}/voyages`, `/teams/{teamSlug}/trips`),
en `mobile` et `deeplink` : l'app n'a pas de liste par type, mais les motifs de lien profond de
l'équipe (`/equipes/*` dans l'AASA, `/equipes/.*` dans le manifeste Android) captent ces chemins
quoi que dise `routes.yaml` — publiées web seulement, elles ouvraient l'app sur sa page d'erreur
(corrigé après relecture, même jour). Le `GoRouter` les rend en `TeamHomePage` section `feed`,
avec `feedType` (`PublicationFeedView.initialType`, type de départ que les chips peuvent
changer) ; elles sont dans `internalRouteTemplates` et `_deepLinkHierarchies` (équipes → équipe).
Ce type initial reste **local au fil** jusqu'au premier choix sur les chips — ne pas le recopier
dans `publicationFeedTypeProvider`, partagé par tous les fils de l'équipe : le fil de l'équipe
empilé dessous par le lien profond passait aussi sur « Sorties » et y restait au retour (corrigé
après relecture, même jour).
Test mobile : `team_kind_tab_links_test.dart` (lien interne, ancêtres, écran résolu, première
page déjà filtrée, fil du dessous resté sur « Tout »), `deep_link_hierarchy_test.dart`. Les
routes `team-rides` et `team-trips` (`routes.config.ts`, publiques, sous `team-detail`) rendent
`PublicationListPage` avec `kind` (`TeamRidesPage`, `TeamTripsPage`) : le même fil, le même
`publicationListData.ts`, où `withListKind` impose le type de la route à la place de `?type=`
côté page comme côté prefetch — mêmes clés de requête. Sur un onglet, le sélecteur de type
disparaît, le titre, l'état vide et le total (`ResultCount` `rides`/`trips`) suivent le type,
le bouton de création ne propose que ce type, et un module coupé renvoie à la page de l'équipe.
Les onglets suivent « Fil d'actualités » dans `useTeamNavItems`, pour tous les visiteurs,
gardés comme le sélecteur de type et le backend (`enableRides`/`enableTrips` **et**
`enableRoutes`). « Voir tout » des sorties à venir du tableau de bord mène à
`/sorties?w=upcoming`. Les anciens liens `?tab=publications&type=ride` marchent toujours : le
fil garde son sélecteur. Tests : `useTeamNavItems.test.tsx` ; e2e `team-dashboard.e2e.ts`
(onglet « Sorties », lien « Voir tout ») et `routes-render.e2e.ts` (`teamRides`, `teamTrips`).
**À ne pas défaire** : un onglet par type n'a pas de lecture à lui — il passe par
`usePublicationListData`/`prefetchPublicationList` avec son `kind`, sinon page et prefetch
divergent ; une sortie ou un voyage reste sous `team-detail` dans le fil d'Ariane (on y arrive
aussi du fil et du tableau de bord) ; `teamRides` et `teamTrips` restent `mobile` avec un
écran dans l'app tant que `/equipes/*` est un motif de lien profond — repassées web seules,
le lien ouvrirait de nouveau l'app sur sa page d'erreur.
