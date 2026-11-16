---
id: BILL-12
title: "Refus de quota en cours de tracé : la fenêtre restait une fraction de seconde"
status: done
done: 2026-11-12
---

## Livré

`BILL-12` **Refus de quota en cours de tracé : la fenêtre restait une fraction de seconde** (2026-11-12,
contrat inchangé) — trouvé à la première passe de `planner-quota.e2e.ts`. Un calcul d'itinéraire
refusé (`PLANNER_QUOTA_REACHED`) ouvre la fenêtre d'explication depuis le planificateur et rafraîchit
le quota de l'équipe ; `RouteEditor` retirait alors le planificateur (`canUsePlanner` faux), et la
fenêtre comme le tracé en cours partaient avec lui. Le planificateur ouvert reste désormais affiché
(`showPlanner = plannerOpen && sourceMode === 'planner'`), le champ fichier ne s'affiche qu'à sa
place ; un quota déjà épuisé au chargement ouvre toujours le formulaire sur l'import, bouton
« Tracer sur la carte » désactivé. Avec lui, deux suites de `BILL-10` dans le préchargement :
`teamSettingsData.ts` précharge la vue admin de l'équipe (la note de l'offre que lit `TeamForm`)
pour l'administration de la plateforme, et l'audit de préchargement ignore une requête marquée
`meta.clientOnly` (`CLIENT_ONLY_QUERY`, `lib/prefetchAudit.ts`) — l'état du planificateur, qu'on ne
précharge délibérément pas et que les équipes, nées avec le planificateur ouvert, lisent désormais
sur « Modifier le parcours ». Décision à ne pas défaire : ce marqueur dit un choix, jamais un trou
à faire taire. Tests : `planner-quota.e2e.ts`, `routes-render -g 'routeEdit /|teamSettings /'`.
La même passe a mis des tests au pas de livraisons qu'ils n'avaient pas suivies : `outsider.e2e.ts`
attend un vrai 404 pour un contenu « Équipe uniquement » vu de l'extérieur (`WEB-166`), `flow-team`
l'absence du champ « Visibilité » quand une seule valeur est permise (`WEB-166`), et côté backend
`GpxPreviewDepartureResourceTest` place ses points « Tokyo » dans les montagnes de Nagano — la
vignette du centre de Tokyo demandait 15 à 30 s à froid au tileserver de test sur une machine
lente, le délai du client HTTP (seul échec de la suite, 4 799 tests, sur optiplex).
