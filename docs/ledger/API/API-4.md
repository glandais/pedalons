---
id: API-4
title: "Le groupe rejoint sur les lignes de liste"
status: done
group: "Petites évolutions d'API"
done: 2026-10-01
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-4` | **Le groupe rejoint sur les lignes de liste** (2026-10-01) — **API 9.3.0** : `RideDto.registeredGroup`, nullable, le `RideGroupDto` complet du groupe que l'utilisateur courant a rejoint (nom, horaire, parcours et ses chiffres, vignettes, capacité, aperçu des inscrits, meneur). Forme tranchée : **un seul groupe complet** plutôt que `groups[]` sur chaque ligne — seul celui-là sert à « Ma prochaine sortie », et le type est celui du détail, que la carte rendait déjà. Il est aussi rempli sur le détail (le même objet que l'entrée correspondante de `groups`). Nul pour un anonyme ou un non-inscrit. Résolu **par page** par `ParticipationLookup.forListPage`, que seul le chemin de liste (`PublicationService.list`) appelle : une projection (`RideGroupRepository.findGroupRows`, groupe, chiffres du parcours et meneur par jointures externes, **aucune entité hydratée** — charger `RideGroup` amènerait sa route EAGER, une par ligne), les aperçus d'inscrits en deux requêtes (`ParticipantPreviewLookup`), les vignettes en une (`ThumbnailLookup`) ; rien du tout quand l'appelant n'a rejoint aucune sortie de la page. Le détail et le calendrier gardent `forPublications`, sans ce coût. À ne pas défaire : pas de `getGroups()` ni de chargement d'entité par ligne, et le meneur est celui du groupe, nul s'il n'y en a pas — jamais `createdBy`. Mobile : `nextRideProvider` ne fait plus qu'**un** appel (`listMyParticipations`, `size: 1`, `COMPACT`) et rend la carte depuis la ligne (`rideFromListRow`) ; le bouton « Quitter » de la carte passe par `nextRideLeaveProvider`, pas par `rideRegistrationProvider`, qui écoute `rideDetailProvider` dès sa création et réintroduirait le `getRide`. L'extension `RideTiming.registeredGroup` est renommée `joinedGroup` (le champ généré l'aurait masquée) : `groups` d'abord, que la bascule optimiste tient à jour, `registeredGroup` ensuite ; `_withRegistration` tient aussi `registeredGroup`. Le web ne rendait pas de prochaine sortie : rien à changer. Tests : `RideMeFieldsTest.registeredGroup_onListRowsAndDetail_isTheJoinedGroupInFull` et `registeredGroup_onAListRow_withoutLeaderNorRoute_carriesNeither`, `ParticipationQueryCountTest.listMyParticipations_registeredGroups_costAPageNotARow` (verts au 16 octobre 2026) ; `participation_changes_test.dart` (« sans getRide », quitter depuis la carte sans détail) | 11 |
