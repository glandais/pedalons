---
id: SEC-26
title: "L'édition d'une annonce ne donne la position exacte qu'au vendeur : M2 (annexe)"
status: done
done: 2026-10-01
---

## Livré

`SEC-26` **L'édition d'une annonce ne donne la position exacte qu'au vendeur : M2 (annexe)**
(2026-10-01, **API 9.2.1**, patch : descriptions de `AdEditDto.locationGeometry` et
`AdDto.locationGeometry` ; pas de migration) — `GET …/classifieds/{slug}/edit` servait le point
exact à quiconque pouvait modifier l'annonce, admins d'équipe et de plateforme compris. `AdEditDto`
porte désormais le point exact pour l'**auteur** seul ; tout autre éditeur reçoit
`CoarseLocation.blur`, le même centre de cellule que `AdDto` (`AdService.toEditDto`, aussi pour la
réponse de `undeleteAd`). Pour qu'un enregistrement par un non-auteur n'écrase pas le point exact
par le centre flouté reçu, `AdService.updateAd` compare la position soumise au flou du point
stocké (tolérance 1e-7°) : identique, le point exact est conservé ; différente ou nulle, elle est
appliquée telle quelle (un admin peut toujours déplacer ou effacer la position). Choix : la
comparaison côté serveur plutôt qu'un indicateur dans `AdRequest` — le serveur seul sait ce qu'il a
servi, et l'éditeur web, qui renvoie le formulaire tel quel, n'a pas eu à changer ; le mobile
n'édite pas d'annonce. Limite assumée : un non-auteur qui choisirait exactement le centre de la
cellule du vendeur garde le point exact — même cellule, rien de publié ne change. **À ne pas
défaire** : ne servir le point exact qu'à `ad.createdBy`, jamais sur le rôle ; garder la
comparaison sur `CoarseLocation.blur` (si le flou change, elle suit). Tests (**écrits, non
lancés**) : `AdServiceTest` (`GetAdEditDto.shouldReturnExactLocationToAuthor`,
`…shouldReturnBlurredLocationToNonAuthorAdmin`, `…shouldReturnBlurredLocationOnUndeleteByNonAuthorAdmin`,
`UpdateAd.adminSaveWithoutMovingKeepsExactLocation`, `…adminMovingLocationReplacesIt`,
`…adminClearingLocationRemovesIt`, `…authorSavingCellCentreReplacesExactLocation`) et
`AdDetailsAndFiltersTest.getAdEdit_asNonAuthorAdmin_givesTheBlurredPointAndARoundTripKeepsTheExactOne`
(aller-retour JSON par HTTP, comme l'éditeur web).
