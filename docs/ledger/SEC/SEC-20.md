---
id: SEC-20
title: "Six constats faibles de l'audit corrigés : L1, L5, L6, L7, L8, L9"
status: done
done: 2026-09-30
---

## Livré

`SEC-20` **Six constats faibles de l'audit corrigés : L1, L5, L6, L7, L8, L9** (2026-09-30,
contrat inchangé, scindé de `SEC-12`, qui garde le reste) —
- **L1** : `AuthService.resetPassword` révoque toutes les sessions du compte (navigateurs, app,
  appareils GPS appairés) avant d'ouvrir celle du navigateur qui réinitialise. Avant, pas après :
  la mise à jour en masse la révoquerait aussi. La politique (§6, sessions d'un appareil GPS) le
  dit, en parité FR/EN.
- **L5** : `AssetAccessChecker` exige que l'asset appartienne à l'équipe que nomme l'URL, résolue
  sur le site courant (redirections de slug comprises). L'identifiant seul atteignait l'asset
  d'un autre site — et, pire que ce que disait l'audit, la suppression vérifiait le rôle de
  l'appelant dans l'équipe **de l'URL**, pas dans celle de l'asset.
- **L6** : `TeamMembershipService.addMember` cherche la cible par `findActiveByIdAndDomain` :
  un compte d'un autre site répond le même 404 qu'un identifiant inconnu.
- **L7** : `server.js` insère le rendu, l'état déshydraté, la session et le bloc `<head>` par des
  fonctions de remplacement. Une chaîne interprétait `` $` ``, `$'` et `$&` : un titre qui en
  contenait dupliquait le gabarit dans la page (reproduit : 12 `<!DOCTYPE html>` dans un
  document). React échappe `'` mais pas le backtick, et le JSON de l'état n'échappe ni l'un ni
  l'autre.
- **L8** : le callback OAuth des services GPS ne recopie plus l'`error` du fournisseur dans sa
  redirection : `access_denied` ou `provider_error` (aucun client ne lit la valeur).
- **L9** : le nom de fichier de `AssetDto.url` est encodé comme un segment de chemin
  (`AssetService.encodePathSegment`) ; le téléchargement l'ignore, mais un `?`, un `#` ou un `/`
  coupaient l'URL.

Tests (suite e2e, passée : 271 tests sur les specs concernées) : `ssr-session.e2e.ts` « user
content holding $` and $' is rendered as text » (L7, vu échouer avant le correctif) ;
`flow-account.e2e.ts` « forgotten password », qui vérifie désormais que la session ouverte avant
la réinitialisation ne se rafraîchit plus (L1). L5, L6, L8 et L9 n'ont pas de test dédié ; les
suites multi-tenant, équipe, publications et parcours passent.
