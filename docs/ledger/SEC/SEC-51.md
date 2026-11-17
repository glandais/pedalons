---
id: SEC-51
title: "Une réponse de l'API distingue deux cas qu'elle devrait confondre pour un appelant sans droit"
status: done
done: 2026-11-17
---

## Livré

`SEC-51` **Le téléchargement d'une pièce jointe distinguait « rattachée à un contenu caché » de
« inexistante »** (audit des permissions du 11 novembre 2026, plan
[`2026-11-11-visibilite-contenu-equipe-privee.md`](../../plans/archive/2026-11-11-visibilite-contenu-equipe-privee.md),
A4, faible ; contrat inchangé) — `AssetAccessChecker` refusait par un 403 une pièce jointe
inexistante, d'une autre équipe ou pas encore rattachée, mais laissait passer le 404 du contrôleur
du contenu porteur (son `findBySlug` filtre en SQL) quand ce contenu était caché à l'appelant :
le statut révélait qu'une pièce jointe existait derrière un contenu invisible (étape de voyage
comprise, `TripStageAccessChecker` déléguant au voyage). Le contrôle du contenu porteur passe
maintenant par `canReadHolder`, qui traite ce 404 comme un refus : un seul statut, 403, quelle que
soit la raison. La convention « inexistante → 403 » des téléchargements reste celle du dépôt
(`downloadAsset_nonexistent_shouldReturn403`). Couvert par
`AssetResourceTest#downloadAsset_heldByHiddenContent_answersLikeANonexistentOne`.
