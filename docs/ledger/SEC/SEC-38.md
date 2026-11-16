---
id: SEC-38
title: "Quitter un groupe ne vérifiait pas que le groupe appartenait à la sortie contrôlée"
status: done
done: 2026-10-11
---

## Livré

`SEC-38` **Quitter un groupe ne vérifiait pas que le groupe appartenait à la sortie contrôlée** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — `RideAccessChecker` (LEAVE) validait la sortie de l'URL (publiée, membre de l'équipe, sorties activées), puis `RideService.leaveGroup` supprimait la participation de l'appelant par `findByUserAndGroup(userId, groupId)` seul, sans lien avec la sortie : `DELETE /teams/A/rides/<sortie publiée de A>/groups/<groupe d'une sortie annulée, en brouillon, ou d'une équipe B quittée ou aux sorties désactivées>/participation` désinscrivait l'appelant de cette autre sortie en contournant les règles PUBLISHED, d'appartenance et d'activation des sorties (sa propre ligne seulement, même domaine : ni autre utilisateur ni autre tenant). `leaveGroup` résout désormais l'équipe et la sortie de l'URL et exige `rideGroupRepository.findByIdAndRide(groupId, ride.getId())` (404 `RIDE_GROUP` sinon), comme `joinGroup`. Test : `RideLeaveGroupScopeTest` (sortie annulée de la même équipe, sortie d'une autre équipe). **À ne pas défaire** : un identifiant de groupe venu de l'URL n'est jamais utilisé sans être rattaché à la sortie que le contrôle d'accès a validée.
