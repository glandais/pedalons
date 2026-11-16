---
id: API-28
title: "NPE 500 sur un `media` incomplet"
status: done
group: "Défauts relevés"
done: 2026-09-30
---

## Livré

`API-28` **NPE 500 sur un `media` incomplet** (2026-09-30) — `POST /api/teams/{slug}/rides` avec
`media.assets = {}` levait une `NullPointerException` dans `AssetService.updateAssets` : Jackson
construit un record par son constructeur canonique, jamais par le builder qui posait les listes
vides, et `@Schema(required = true)` ne valide rien sur `AssetsDto` ni `MediaDto` (pas de
`@ValidateSchema`). Les deux records ont maintenant un constructeur compact qui **normalise à
vide** : `images` et `attachments` nuls deviennent des listes vides, `assets` nul un inventaire
vide, `markdown` nul la chaîne vide (la valeur par défaut du builder et de l'entité, dont la colonne
est `NOT NULL`). Normaliser plutôt que répondre 400 : les clients envoient toujours les listes, et le
contrat ne change pas. Couvert par `RideResourceTest.createRide_withEmptyAssetsObject_shouldSucceed`
et `createRide_withEmptyMediaObject_shouldSucceed`. Un `media` nul, lui, reste un 400 là où la
requête porte `@ValidateSchema` (`RideRequest`…).
