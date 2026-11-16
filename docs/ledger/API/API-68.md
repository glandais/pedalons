---
id: API-68
title: "Un asset déjà attaché ailleurs était ignoré sans erreur"
status: done
group: "Défauts relevés"
done: 2026-10-06
---

## Livré

`API-68` **Un asset déjà attaché ailleurs était ignoré sans erreur** (2026-10-06, contrat
`10.12.0`) — relevé à la recette mobile (`MOB-18`) : un `MediaDto` citant une pièce jointe d'un
autre contenu ou d'une autre équipe répondait 200/201 sans la porter, et un client d'API (seed,
migration, futur « dupliquer ») croyait le fichier joint. `AssetService.addAssetToEntity` refuse
maintenant par un **400 `ASSET_NOT_AVAILABLE`** dont `errorDetails` (`AssetNotAvailableDetails`,
nouvelle variante de l'union `ErrorDetails`) ne porte que `type` et `assetId`, l'id tel que la
requête l'a cité. Même réponse pour un id inconnu (avant : 404 `NOT_FOUND` de l'asset) ou
illisible : l'API n'est pas un oracle de ce que tiennent les autres contenus. La transaction de
la requête est annulée, le contenu garde ses pièces jointes d'avant. Contrat (10.11.0 → 10.12.0,
mineur) : la valeur d'enum, la variante d'erreur, la description d'`AssetsDto` ; messages
`errors.api.ASSET_NOT_AVAILABLE` au web. Aucun client actuel ne réutilise un asset (web et app
téléversent pour chaque contenu), donc rien à changer côté écrans. Couvert par
`AssetResourceTest.attachAsset_*` (autre contenu, autre équipe, inconnu : même corps ; recité
par son propre contenu : 200) et `AssetServiceTest.UpdateAssets.shouldRefuse*`. **À ne pas
défaire** : un asset n'a qu'un propriétaire, et le refus ne nomme ni le contenu ni l'équipe qui le
tient — une seule forme de réponse pour les trois cas. Les images non citées par le markdown sont
toujours écartées *avant* ce contrôle, sans erreur (comportement voulu, pas un défaut).
