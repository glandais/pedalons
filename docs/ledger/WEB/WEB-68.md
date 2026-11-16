---
id: WEB-68
title: "Le fil d'équipe remplacé par « Agenda » (sorties et voyages) et « Publications »"
status: done
group: "Agenda et Publications"
done: 2026-10-06
---

## Livré

`WEB-68` **Le fil d'équipe remplacé par « Agenda » (sorties et voyages) et « Publications »**
(6 octobre 2026, sans changement de contrat d'API : lit `when` et `endDateTime` d'`API-85`,
contrat `10.15.0`, et le tableau de bord ouvert d'`API-86`, `10.16.0`). Le fil mélangeait deux
temporalités : « À venir » y triait du plus lointain au plus proche, « Je participe » ne bornait
pas la date, et ces filtres s'appliquaient aux publications. `contracts/routes.yaml` gagne
`teamAgenda` (`/equipes/{teamSlug}/agenda`) et `teamPosts` (`/equipes/{teamSlug}/articles`,
parent des adresses de publication existantes), `web`, `mobile` et `deeplink`.
- **Agenda** (`pages/team/TeamAgendaPage.tsx`, `teamAgendaData.ts`) : « À venir » (défaut) ·
  « Je participe » (connecté) · « Passées », projetés par `agendaApiParams`
  (`hooks/filters/agendaFilters.ts`) sur `when=UPCOMING|PAST` (+ `participating`) — le serveur
  trie ; plus de `from=now`, donc plus d'horloge dans la clé de requête. Type Tout / Sorties /
  Voyages (chaque type selon ses modules), bouton « Filtres » (recherche, tags du type choisi ;
  sans type, champ désactivé et « Choisissez Sorties ou Voyages pour filtrer par tag. »), nombre
  de résultats par période et type (« 5 sorties et voyages à venir »), `ListViewSwitch`
  Vignettes · Lignes (`?view=`) · Calendrier. État vide : « Rien à l'agenda pour le moment ».
- **Publications** (`TeamPostsPage.tsx`, `teamPostsData.ts`, `teamPostFilters.ts`) : les
  publications seules, la plus récente d'abord, recherche et tags, sans filtre de date.
- **Tableau de bord pour tous** : `TeamHomePage` le rend toujours (visiteur : ni badge de rôle,
  ni « S'abonner au calendrier », ni blocs de membre) ; `prefetchTeamHome` lit l'équipe et le
  tableau de bord côte à côte. « Voir tout » : « Mes prochaines » → `teamAgenda?w=me`,
  « Prochaines sorties » → `teamAgenda`, « Dernières publications » → `teamPosts`.
- **Redirections** (`pages/team/teamLegacyRedirects.ts`) : nouvelle option `redirect` des routes
  (`routes.types.ts`), lue par le loader avant le prefetch, qui lève `replace()` — 302 côté SSR
  (traduit en espace navigateur sur un hôte épinglé), entrée d'historique remplacée côté client.
  `team?tab=publications&type=post` → `teamPosts` ; `…&type=ride|trip` → `teamAgenda?type=…` ;
  `?tab=publications` seul → `team` ; `w=me` gardé, `w=upcoming`/`w=all` → « À venir » ;
  `teamRides` → `teamAgenda`, `teamTrips` → `teamAgenda?type=trip`. Recherche et tags suivent.
- **Supprimés** : `PublicationListPage`, `publicationListData.ts`, `TEAM_FEED_TAB`,
  `teamFeedPath`, `showsTeamDashboard`, le schéma `teamPublicationFiltersSchema` et l'onglet
  « Calendrier ». Le fil d'accueil transverse (`home`) n'est pas touché (plan §7).
- **Onglets** (`useTeamNavItems`) : Tableau de bord, Agenda, Publications, Parcours, Annonces
  (membres), Membres (administrateurs), À propos, pages perso — icônes de la charte (`BRAND-6`).
  Fil d'Ariane : sortie et voyage sous l'Agenda, publication sous les Publications, calendrier
  sous l'Agenda.
- **« En cours »** (`utils/publicationTiming.ts` `isUnderWay`, `components/agenda/InProgressBadge`)
  : départ passé et `endDateTime` à venir, sortie annulée exclue — état dérivé client, vert doux
  à pastille, sur les cartes et les lignes. La fin s'affiche « 08:30 → retour vers 14:10 », un
  voyage « ven. 16 → dim. 18 oct. » (`PublicationTimeSpan`) ; vue Lignes `AgendaRow` avec le
  `DayBox` partagé avec « Mes prochaines ».

Tests : `agendaFilters.test.ts`, `teamLegacyRedirects.test.ts`, `publicationTiming.test.ts`,
`useTeamNavItems.test.tsx`, `TeamDashboard.test.tsx` (visiteur, « Voir tout »),
`tagFilters.test.ts` ; e2e adaptés (à lancer sur la stack e2e) : `team-dashboard`,
`list-filters`, `pagination`, `pinned-host`, `flow-posts`, `routes-render`, et `flow-rides`,
`flow-trips`, `flow-team`, `flow-moderation`, `team-misc`, `slug-change`. **À ne pas défaire** :
page et prefetch de l'Agenda passent par le même `agendaApiParams` — le défaut « À venir » vit
dans le schéma, jamais dans la page seule ; une ancienne adresse se redirige dans le loader
(`replace()`), pas par un `<Navigate>` après rendu, sinon le serveur rend une page que le
client quitte et l'ancienne adresse reste dans l'historique ; `teamRides` et `teamTrips`
restent au contrat (`mobile`, `deeplink`) pour les liens déjà diffusés ; le calendrier reste
aux membres (plan §7) : pas de vue Calendrier pour un visiteur.
