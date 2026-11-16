---
id: MOB-60
title: "L'équipe découpée en Agenda et Publications, comme au web"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-06
---

## Livré

`MOB-60` **L'équipe découpée en Agenda et Publications, comme au web** (6 octobre 2026, contrat
inchangé — il lit `when` et `endDateTime` de la `10.15.0` et le tableau de bord public de la
`10.16.0`), plan [`2026-10-06-team-agenda.md`](../../plans/archive/2026-10-06-team-agenda.md) §6, publié avec
`WEB-68`.
- **Sections** (`team_sections.dart`) : `TeamSectionKind` perd `feed` et `calendar`, gagne
  `agenda` et `posts`, dans l'ordre du site — Tableau de bord, Agenda (sorties ou voyages, et les
  parcours), Publications (`enablePosts`), Parcours, Annonces (membres), Membres, À propos. Le
  tableau de bord est à l'adresse de l'équipe **pour tout le monde** (`API-86`) ; un visiteur n'y
  a ni badge de rôle ni « S'abonner au calendrier ». « Voir tout » : « Mes prochaines » →
  `teamAgenda?w=me`, « Prochaines sorties » → `teamAgenda`, « Dernières publications » →
  `teamPosts` ; la cellule « sorties à venir » de l'en-tête mène à l'Agenda.
- **Agenda** (`team_agenda_page.dart`) : `PublicationFeedView` avec la période « À venir /
  Je participe / Passées » (`when=UPCOMING|PAST` + `participating`, le serveur triant), les
  chips Tout / Sorties / Voyages, les tags du type choisi et la recherche ; le nombre de
  résultats (« 5 sorties et voyages à venir », les neuf tournures du site) ; l'état vide « Rien à
  l'agenda pour le moment » et « Voir les passées ». Une bascule Liste / Calendrier, icônes
  seules (`PdlSegment.iconOnly`), rend `CalendarPage` filtré sur l'équipe — membres seulement ;
  en calendrier la période devient « Tout / Je participe », filtrés en mémoire comme le type
  (`CalendarMonth.filtered(registeredOnly:)`). **Publications** : `PublicationFeedView` sur
  `type=POST`, sans chip de type ni filtre de date.
- **`PublicationFeedView`** gagne `when`/`participating` (dans `PublicationFeedKey`), un type
  piloté par l'appelant (`selectedType` + `onTypeChanged`), `typeOptions`, `filterScope`
  (`agenda/<slug>`, `posts/<slug>` : recherche et tags d'une section ne passent pas à l'autre),
  `toolbarHeader`, `countLabel` et un état vide paramétrable. `initialType` et `TeamFeedPage`
  sont supprimés.
- **Adresses** (`router.dart`) : `teamAgenda` (lit `?type=` et `?w=`), `teamPosts`,
  `teamCalendar` (l'Agenda en vue Calendrier), `teamRides` → l'Agenda, `teamTrips` → l'Agenda
  sur les voyages ; l'adresse nue lit encore `?tab=publications`, `?type=` et `?w=` avec les
  redirections du site (`resolveTeamRootSection`). Le relais provisoire vers le fil est retiré.
  `_deepLinkHierarchies` range une sortie, un voyage et une étape sous l'Agenda, une publication
  sous les Publications — l'Agenda est un parent **logique** d'une sortie, pas un préfixe de
  son adresse, ce que `deep_link_hierarchy_test.dart` admet pour lui seul.
- **« En cours »** (`teams/domain/publication_timing.dart` `isUnderWay`) : départ passé et
  `endDateTime` à venir, sortie annulée exclue, comparés en UTC — badge vert doux à pastille
  (`PdlDerivedTones.underWay`, `PdlBadge.dot`) à la place de « Terminée », sur les cartes de
  sortie et de voyage. La fin s'affiche « demain 08:30 → retour vers 14:10 » (`rideTimeSpan`),
  un voyage « ven. 16 → dim. 18 oct. » (`tripDaySpan`) ; `PdlStat` laisse passer sa valeur à la
  ligne au lieu de déborder.

Tests : `team_agenda_test.dart` (chaque adresse et chaque ancienne adresse, `when` et
`participating` envoyés, le type du lien servi dès la première page sans être écrit dans
`publicationFeedTypeProvider`, la bascule en calendrier qui garde type et « Je participe », pas
de calendrier pour un visiteur), `publication_timing_test.dart`, `team_dashboard_test.dart`
(ordre et icônes des puces, sections d'un visiteur, tableau de bord visiteur),
`deep_link_hierarchy_test.dart`, `sign_in_resume_test.dart` ; Patrol adapté (à lancer sur la
stack e2e) : `feed_pagination_test.dart`. **À ne pas défaire** : le type de l'Agenda reste
**local** à la page (ouvert sur celui du lien, gardé d'une vue à l'autre) et n'est jamais écrit
dans `publicationFeedTypeProvider` (leçon de `WEB-64`) ; l'Agenda et les Publications gardent
chacun leur `filterScope` ; le calendrier d'une équipe reste aux membres (plan §7) ; « En cours »
se calcule sur les instants du contrat, jamais sur leur heure de cadran.
