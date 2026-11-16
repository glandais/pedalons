---
id: SEC-24
title: "Le mot de passe se choisit sur la page du lien, plus à l'inscription : L4"
status: done
done: 2026-09-30
---

## Livré

`SEC-24` **Le mot de passe se choisit sur la page du lien, plus à l'inscription : L4**
(2026-09-30, **API 7.0.0**, scindé de `SEC-12`, livré avec `SEC-9`) — n'importe qui pouvait
s'inscrire avec l'adresse d'un autre en choisissant le mot de passe : si le propriétaire cliquait le
lien reçu, le compte naissait avec le mot de passe de l'attaquant. `RegisterRequest` perd
`password` ; `POST /api/auth/verify-email` prend `ActivateAccountRequest` (`token`, `password`) et
ouvre la session (`AuthService.activateAccount`). Le mot de passe vient donc de qui tient la boîte
aux lettres. Web (`LoginPage`, `VerifyEmailPage`) et mobile (`login_page.dart`,
`verify_email_page.dart`) déplacent les deux champs. La colonne `pending_password_hash` n'est plus
écrite mais reste, pour le déploiement progressif et les liens émis avant — `activateAccount`
ignore leur hachage ; le champ a été retiré en 10.0.0 (`API-57`), la colonne ensuite par `V54` (`API-58`). La politique de confidentialité (§1, liens envoyés
par e-mail) ne dit plus qu'un mot de passe haché est gardé en attente, en parité FR/EN.
**Décision** : ne jamais recréer un compte avec un mot de passe venu de l'inscription. Tests :
`AuthResourceTest.verifyEmail_setsThePasswordChosenOnActivation_neverTheOneFromSignUp` (un jeton
d'avant portant un hachage : l'ancien mot de passe est refusé, le nouveau ouvre la session ;
devenu `verifyEmail_setsThePasswordChosenOnActivation` sous `API-57`, le hachage n'étant plus
mappé),
`register_storesNoPassword`, `verifyEmail_withoutAPassword_isRefusedAndSpendsNothing`.
Trois scénarios e2e restés sur l'ancien parcours (texte « activer votre compte », champs de mot
de passe à l'inscription) ont été remis au nouveau le 2026-09-30 : `flow-account.e2e.ts`
(inscription puis connexion, nouvel essai après un e-mail non parti) et `invitations.e2e.ts`
(inscription depuis une invitation, mot de passe choisi sur la page du lien).
