---
id: WEB-24
title: "T3.5 — Abandonnée, puis tranchée dans l'autre sens (2.0.0)"
status: done
group: "Le résidu du portage web"
---

## Livré

### `WEB-24` T3.5 — Abandonnée, puis tranchée dans l'autre sens (2.0.0)

Alimenter `ElevationChart` par `…/elevation-profile` au lieu de la géométrie complète. **La prémisse
ne tenait pas** : il n'existe aucune vue web qui rende un profil *sans* rendre de carte, donc la
géométrie est de toute façon nécessaire et l'appel supplémentaire **ajoutait** une requête au lieu
d'en retirer une.

C'est finalement l'inverse qui a été fait, et pour la même raison : `…/elevation-profile` a été
**supprimé** de l'API en 2.0.0, et le mobile dérive désormais son profil de la géométrie comme le
web le faisait déjà. Voir `API-40`. Ne pas rouvrir : le sujet est clos dans les deux clients.
