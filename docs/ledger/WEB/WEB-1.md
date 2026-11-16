---
id: WEB-1
title: "Trombinoscope : la page web des membres (2026-09-30)"
status: done
group: "Le résidu du portage web"
done: 2026-09-30
---

## Livré

### `WEB-1` Trombinoscope : la page web des membres (2026-09-30)

Le dernier reste de T5.4 (`API-39`). La route `teamMembers` (`/equipes/{slug}/membres`) passe à
`web: true` dans `contracts/routes.yaml` et perd son `webFallback` : elle ne redirige plus vers
l'équipe mais rend `TeamDirectoryPage`, route `team-directory` (`auth: 'authenticated'`, sous
« À propos »), que `scripts/routes-ssr.yml` crawle en `user1` sur `gaby`. Les deeplinks ne changent
pas (AASA et `AndroidManifest.xml` régénérés à l'identique), ni le mobile.

La page est `TeamMembersPage` sans invitations, changement de rôle ni retrait : `TeamMemberList` y
reçoit un rôle nul, donc aucune action. Elle affiche **ce que l'API renvoie** : un 403 est un état de
la page (« Liste des membres non partagée », retour vers « À propos »), jamais contourné ; un
`joinedAt` nul n'est plus rendu « A rejoint le inconnu » (`TeamMemberList`) ; le filtre de rôle
n'apparaît que si les rôles sont rendus au lecteur (admin d'équipe ou de plateforme, ou trombinoscope
ouvert), et la recherche ne promet l'e-mail qu'à un admin. Le prefetch (`prefetchTeamDirectory`,
`teamMembersData.ts`) ne demande pas les invitations, réservées aux admins.

Le lien « N membres » de `TeamAboutPage` est actif pour un admin, un organisateur, ou un membre d'une
équipe qui a ouvert son trombinoscope — la règle de `UserTeamAccessChecker` et de la puce du mobile
(`buildTeamSections`) : un lien qui mène toujours à un 403 est pire que pas de lien. Il n'y a pas
d'onglet « Membres » dans la navigation d'équipe, dont la largeur est mesurée pour huit items au
plus (`WEB-25`).

Couvert par trois scénarios de `frontend/e2e/member-directory.e2e.ts` (membre sur trombinoscope
fermé : pas de lien, page de refus sans aucun nom ; organisateur sur trombinoscope fermé : les noms,
sans rôle, date ni filtre de rôle, sans action d'admin ; membre sur trombinoscope ouvert : les
rôles), et par l'entrée `teamMembers` de `routes-render.e2e.ts` (anonyme renvoyé à la connexion ;
sur l'équipe du jeu de données, trombinoscope ouvert, rendu pour les membres, organisateur, admin et
admin plateforme ; refus sur place pour un extérieur), lancés le 2026-09-30, verts sur desktop et
mobile ; `appOnlyFallbacks.test.ts` et `smoke.e2e.ts` ne comptent plus `/membres` parmi les liens réservés à
l'app. Ne pas déduire les rôles ou l'accès côté client pour élargir ce que le serveur donne.
