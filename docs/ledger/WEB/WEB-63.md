---
id: WEB-63
title: "Tableau de bord d'équipe selon le rôle"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-06
---

## Livré

`WEB-63` **Tableau de bord d'équipe selon le rôle** (6 octobre 2026, **API 10.8.0**, `API-79`).
Pour un membre connecté, `/equipes/{slug}` ouvre le tableau de bord (`TeamDashboardPage`,
composants `components/team/dashboard/`) ; visiteurs et non-membres gardent le fil, que les membres
trouvent à `?tab=publications` (`teamFeedPath`, `showsTeamDashboard` dans
`pages/team/teamHomeData.ts`, `tab` gardé par les filtres du fil). Membre : prochaines sorties
(envoi vers l'appareil), sorties à venir avec remplissage par groupe, publications, parcours,
annonces (« Prix à négocier », secteur en texte). Organisateur et admin : « Créer une sortie »,
« Nouvelle publication », bande « À traiter » (brouillons, sans parcours, groupe complet,
signalements), « Modifier », « Créer depuis un modèle ». Admin : panneau Administration (rôles,
nouveaux membres, fonctionnalités, webhook, « Inviter »), onglet « Membres ». Sous `sm`, les
actions d'en-tête passent en icônes avec `aria-label`. `CreateRidePage` lit `?template=` et
`TeamMembersPage` `?invite=1` (adresses utilisées par le mobile). Tests : `TeamDashboard.test.tsx`,
`useTeamNavItems.test.tsx`, `CreateRidePage.test.tsx` ; e2e `team-dashboard.e2e.ts` (trois rôles,
non-membre, fil à `?tab=publications`) et `list-filters`, `pagination`, `pinned-host`,
`flow-posts` adaptés ; `routes-render` de la route `team` vert. **À ne pas défaire** : toute
mutation qui change ce que montre le tableau de bord l'invalide (`lib/teamDashboardCache.ts`,
`routeCacheInvalidation`, `moderationCacheInvalidation`) ; `prefetchTeamHome` s'arrête quand
l'équipe n'a pas pu être lue — sinon le fil la relit et une 404 est demandée deux fois
(`error-states.e2e.ts`) ; pas de route nouvelle dans `contracts/routes.yaml` (levé pour les
deux listes par type de `WEB-64`).
