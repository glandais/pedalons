---
id: API-71
title: "Changement d'adresse e-mail en 500"
status: done
group: "Défauts relevés"
done: 2026-10-04
---

## Livré

`API-71` **Changement d'adresse e-mail en 500** (2026-10-04) — `POST
/api/auth/email/change-request` échouait pour tout le monde, web comme mobile
(`profile_identity_section.dart`) : `AuthTokenType.EMAIL_CHANGE` avait été ajouté sans migration,
et la contrainte `auth_tokens_token_type_check` (V4) n'admettait que `EMAIL_VERIFICATION`, `OTP` et
`PASSWORD_RESET`. Le jeton était refusé à l'insertion, la transaction annulée avant tout envoi de
mail. Constaté en prod sur une vraie demande, pas par les tests : ceux-ci créent le schéma depuis
les entités (`drop-and-create`, Flyway coupé en `%test`), donc avec une contrainte générée à
partir de l'enum. `V60__auth_token_type_email_change.sql` élargit la contrainte, rien d'autre (la
release précédente reste compatible pendant le déploiement). Pas de changement de contrat. Aucun
test ne la couvre ; le garde-fou est `API-72`. **À ne pas défaire** : une valeur ajoutée à un enum
persisté en `varchar` sous contrainte CHECK (`AuthTokenType`, `AssetType`, `GpsServiceType`…)
part avec sa migration Flyway, dans le même commit.
