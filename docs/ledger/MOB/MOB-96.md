---
id: MOB-96
title: "Les éditeurs relisent les modules sur l'équipe elle-même, la puce « Annonces » s'ouvre à l'administrateur de la plateforme"
status: done
done: 2026-11-16
---

## Livré

`MOB-96` **Les éditeurs relisent les modules sur l'équipe elle-même, la puce « Annonces » s'ouvre à l'administrateur de la plateforme** (constaté à la relecture du ledger du 16 novembre 2026, contrat d'API inchangé) — `teamManagePermission` répond toujours « oui » à un administrateur de la plateforme pour une équipe hors de « Mes équipes », mais les cinq éditeurs ne s'en contentent plus : `ride_editor_page.dart` et `trip_editor_page.dart` (`modulesOn`), `route_editor_page.dart`, `post_editor_page.dart` et `ad_editor_page.dart` relisent `enableRides` / `enableRoutes` / `enableTrips` / `enablePosts` / `enableAds` sur l'équipe chargée et refusent avant le serveur. `buildTeamSections` (`team_sections.dart`) ouvre la puce « Annonces » à `isMember || platformAdmin`, comme le site. **À ne pas défaire** : la règle de droit (`canManageTeam…`) ne voit que « Mes équipes » ; c'est la page qui relit les modules.
