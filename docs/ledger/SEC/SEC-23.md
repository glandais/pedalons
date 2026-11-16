---
id: SEC-23
title: "Les échecs de connexion sont journalisés : L14"
status: done
done: 2026-09-30
---

## Livré

`SEC-23` **Les échecs de connexion sont journalisés : L14** (2026-09-30, contrat inchangé,
scindé de `SEC-12`) — chaque échec de connexion par mot de passe, code OTP ou passkey écrit une
ligne `WARN` `Login failed method=… reason=… email=… domain=… ip=…` (`AuthService.logFailedLogin`),
que Loki garde 14 jours : `{stack="pedalons-prod", service="backend"} |= "Login failed"`. Le motif
distingue ce que la réponse au visiteur confond à dessein (`unknown_account`, `no_password`,
`wrong_password` ; `no_valid_code`, `wrong_code` ; pour une passkey, le code d'erreur, sans
adresse). **Jamais le mot de passe ni le code dans cette ligne** : la politique de confidentialité
promet qu'aucun identifiant de connexion n'est écrit dans les journaux (elle annonce déjà « parfois
votre adresse e-mail » et l'IP). L'IP est celle que lit `AuthResource.getClientIp`, donc aussi
fiable que les en-têtes `X-Forwarded-*` (V3, `SEC-16`). Journaliser ne limite rien : la limitation
reste `SEC-7`. Tests : `AuthServiceTest` (`…_logsTheFailureWithout…`, `…_unknownAccount_isLoggedToo`,
`…_success_logsNoFailure`, `…_unknownCredential_isLogged`), qui capturent le journal de
`AuthService`. **La ligne ne touche jamais la base** : chaque méthode résout le domaine *avant*
la vérification qui peut échouer et le passe à `logFailedLogin`. Une passkey refusée laisse la
transaction inutilisable, et résoudre le domaine après coup changeait le 403 en 500 — couvert par
`PasskeyResourceTest.authenticate_withInvalidCredential_shouldReturn403` (les tests de service
fixent le domaine d'avance et ne pouvaient pas le voir).
