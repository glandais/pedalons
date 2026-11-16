---
id: MOB-62
title: "Profil refondu (`MOB-48`, `WEB-57`) : finitions"
status: open
size: "S"
group: "Couverture e2e Patrol — ce que les tests ne couvrent pas encore"
verified: 2026-11-16
---

## Reste à faire

`MOB-62` **Profil refondu (`MOB-48`, `WEB-57`) : finitions (S)** —
reste de `MOB-49`, dont les tests Patrol sont verts depuis le 6 octobre 2026.
- La recette sur appareil du profil refondu est portée par `MOB-15`.
- La bascule d'une puce de canal n'est exercée nulle part : la pile e2e ne déclare aucun canal
  (e-mail coupé, pas de FCM, `NOTIF-4`).
- Mineurs (XS, revérifiés le 16 octobre 2026) : la ligne d'état de Mon compte (« Photo, nom
  affiché, suppression du compte ») et la carte d'identité (« Photo, nom et compte ») se
  répètent un peu ; `Moderation.goBack()` (`patrol_test/modules/moderation.dart`) n'a plus
  d'appelant et repose sur `$.tester.pageBack()`, que `PdlAppBar` ne satisfait pas — à
  retirer. Clés de traduction sans appel littéral ni clé construite (`fr.json` et `en.json`) :
  `profile.security`, `profile.community`, `profile.passkeys.enabled` / `notConfigured` /
  `replace`, `notifications.preferences.inAppAlwaysOn`.
