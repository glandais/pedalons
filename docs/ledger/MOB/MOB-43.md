---
id: MOB-43
title: "Carrousel « À venir » retiré de l'accueil"
status: done
group: "Accueil membre"
done: 2026-10-04
---

## Livré

`MOB-43` **Carrousel « À venir » retiré de l'accueil** (4 octobre 2026, décidé avec le
propriétaire). Il doublait « Cette semaine » (`MOB-42`). Supprimés avec lui : `upcomingProvider`,
le widget, ses clés, les libellés `home.upcoming`, `home.upcomingScope`, `home.chooseGroup`, et
l'inscription automatique qu'ouvrait son bouton « Rejoindre » sur `RideDetailPage` (seul
appelant). Tests : `participation_changes_test.dart` vérifie qu'une inscription recharge « Cette
semaine » ; `upcoming_action_test.dart` et le test Patrol `upcoming_carousel_order_test.dart` sont
supprimés. **À ne pas défaire** : plus aucun test de bout en bout ne couvre le tri « plus proches
d'abord » (`sortDir=ASC`) de `/api/publications`, dont l'app ne dépend plus.
