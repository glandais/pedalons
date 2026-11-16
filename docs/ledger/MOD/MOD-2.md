---
id: MOD-2
title: "Plus de signalements orphelins après suppression"
status: done
done: 2026-09-30
---

## Livré

`MOD-2` **Plus de signalements orphelins après suppression** (2026-09-30) — `REMOVE_CONTENT` sur
une publication laissait `OPEN` les signalements de ses commentaires, qui pointaient alors vers un
contenu supprimé. `ModerationService.remove` les clôt maintenant en `REMOVED`, dans la même
transaction, par une seule requête (`ContentReportRepository.resolveOpenCommentsOf`, un `update`
sur les commentaires de la publication), comme il le faisait déjà pour les réponses d'un
commentaire retiré. La clôture ne regarde pas l'auteur du commentaire : la décision porte sur la
publication, un organisateur qui la retire clôt aussi le signalement d'un de ses propres
commentaires dessous. Si un admin plateforme restaure la publication, ces signalements restent
clos. Couvert par `ModerationResourceTest.removeContent_ofAPublication_closesTheReportsOfItsComments`
(un commentaire d'une autre publication garde son signalement ouvert).
