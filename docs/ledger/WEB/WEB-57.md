---
id: WEB-57
title: "Le lexique du profil vaut hors du profil, sur les deux clients et dans les e-mails"
status: done
group: "Profil"
done: 2026-10-04
---

## Livré

`WEB-57` **Le lexique du profil vaut hors du profil, sur les deux clients et dans les e-mails**
(4 octobre 2026, pas de changement de contrat). En français, partout : « Nom affiché » (plus
« Nom d'affichage » : `auth.form.displayName`, `admin.users.displayName`,
`admin.domains.namePlaceholder`), « Clé d'accès / Clés d'accès » (plus « Passkey » : connexion,
`auth.errors.passkeyFailed`, `errors.api.PASSKEY_NOT_FOUND`, admin, pages Fonctionnalités ; sur
l'app, connexion, activation par e-mail), « Adresse e-mail » pour tout champ et ses erreurs
(connexion, inscription, mot de passe oublié, inscription bêta, colonnes d'admin ;
`INVALID_CREDENTIALS`, `EMAIL_ALREADY_EXISTS`, `EMAIL_NOT_VERIFIED`, `PASSWORD_NOT_SET` sur l'app),
et « e-mail » avec trait d'union dans toute phrase. En anglais : « Display name », « Email
address », « passkey ». Fichiers : `frontend/src/locales/{fr,en}/common.json`,
`mobile/assets/l10n/{fr,en}.json`, `privacy/privacy-policy.fr.md` (« nom affiché », source de
`frontend/src/assets/legal/` via `pnpm copy-legal`). Le gabarit `ad-contact.{fr,en}.{html,txt}`
du backend nomme le réglage et sa place : « désactivez « Être contacté par les membres » dans
Profil › Confidentialité » (EN « Profile › Privacy »), sans lien (il faudrait un paramètre d'URL
passé par le service). Tests repris : e2e `flow-account` (inscription, connexion, code e-mail,
mot de passe oublié, compte existant, clé d'accès supprimée), `invitations`, `pwa`,
`flow-device`, `flow-platform-admin` (inscriptions bêta) ; Patrol `modules/peripheral.dart`
(« Adresse e-mail invalide », `apps_beta_signup_test`) ; widget
`test/features/teams/pending_invitations_card_test.dart` — e2e et Patrol verts au
16 octobre 2026 (`WEB-56`, `MOB-49`). **À ne pas défaire** : le lexique est le même dans le profil et hors du
profil, sur le site, l'app et les e-mails ; un terme change partout à la fois.
