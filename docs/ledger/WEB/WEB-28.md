---
id: WEB-28
title: "« Déconnecter tous les appareils » sur le site"
status: done
group: "Défauts d'interface"
done: 2026-09-30
---

## Livré

`WEB-28` **« Déconnecter tous les appareils » sur le site** (2026-09-30, contrat inchangé) — le
profil web (`UserProfilePage.tsx`, section « Actions du compte ») a le bouton du mobile, avec la
même confirmation et une ligne qui dit ce qu'il ferme (ce navigateur, l'app, le Karoo ou le Garmin
appairé : ce sont tous des `AuthSession`, que `AuthService.logoutAll` révoque). L'action
`authStore.logoutAll` retire d'abord l'enregistrement Web Push du navigateur, comme `logout`, puis
appelle `POST /api/auth/logout-all` par le client **authentifié** et recharge sur la connexion.
**Un refus du serveur laisse la session ouverte** et le dit (« vos sessions sont toujours
ouvertes ») au lieu d'annoncer une déconnexion qui n'a pas eu lieu — d'où `skipErrorToast` sur
l'appel. Trouvé en chemin, le défaut que le mobile avait corrigé en `MOB-32` : l'intercepteur web
ne rafraîchissait jamais le jeton sur `/api/auth/*`, si bien qu'un jeton d'accès expiré faisait
échouer en 401 `logout-all`, la demande de changement d'e-mail et la gestion des clés d'accès.
`refreshesOn401` (`lib/authRefresh.ts`) reprend la table du mobile, plus
`email/change-request`. La politique (§1, extensions GPS) cite désormais le site et l'app, en
parité FR/EN. Tests : `lib/authRefresh.test.ts` (la table), et `flow-account.e2e.ts` « signing
out of every device from the profile closes the other sessions too » (desktop et mobile) : la
session du navigateur **et** une session ouverte ailleurs ne se rafraîchissent plus. Non couvert
de bout en bout : le rafraîchissement d'un jeton expiré avant l'appel (pendant web de `MOB-38`).
