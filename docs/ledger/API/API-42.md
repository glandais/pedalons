---
id: API-42
title: "« Compléter le compte » retiré"
status: done
group: "Petites évolutions d'API"
done: 2026-09-29
---

## Livré

`API-42` **« Compléter le compte » retiré** (2026-09-29) — **API 6.0.0** : `UserDto.requiresEmail`
(qui valait `!user.isEmailVerified()`) a disparu du contrat, avec la page web
« Compléter le compte » (`/completer-le-compte`, `CompleteAccountPage`) et le bandeau qui y
menait. C'était du code mort : plus aucun compte non vérifié ne peut ouvrir de session —
l'inscription et le bootstrap vérifient l'e-mail, l'OTP et la réinitialisation du mot de passe
refusent un compte non vérifié (`AuthService`), les comptes migrés non vérifiés n'ont pas de mot
de passe, et les comptes factices `strava_<id>@…` ne peuvent plus se connecter depuis le retrait
de Strava (`7cd2bf3a`), l'import par dump qui les créait ayant lui-même été retiré (`d93fd3af`).
**Décision à ne pas défaire** : `POST /api/auth/email/change-request`,
`AuthService.requestEmailChange` et la vérification du changement d'e-mail **restent** — le profil
mobile s'en sert (`profile_identity_section.dart`) ; seul le parcours « compléter » est parti. Aucune
migration Flyway ne supprime les comptes `strava_<id>@…`, mais staging et prod n'en ont plus
(vérifié le 2026-09-29 : aucun compte factice ni non vérifié, bases reparties de zéro depuis
l'import) ; seule une vieille base locale ou une restauration antérieure en porterait encore.
