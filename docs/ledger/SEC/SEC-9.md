---
id: SEC-9
title: "Un lien de vérification ne connecte plus personne à lui seul : M5"
status: done
done: 2026-09-30
---

## Livré

`SEC-9` **Un lien de vérification ne connecte plus personne à lui seul : M5** (2026-09-30,
**API 7.0.0**, livré avec `SEC-24`) — charger la page d'un lien d'inscription ouvrait une session
sur le compte du lien : l'attaquant qui transmettait **son** lien connectait sa victime à son compte
(qui y enregistrait ensuite passkey, sorties, connexions GPS). Désormais la page **lit** le lien sans
le consommer (`POST /api/auth/verify-email/preview` → `EmailLinkPreviewResponse` : adresse et
`EmailLinkKind`), **montre l'adresse**, et n'active le compte qu'au clic, mot de passe choisi (voir
`SEC-24`). Si un autre compte est connecté, la page le dit avant de basculer. La porte voisine était
la même faille : le lien de **changement d'adresse** ouvrait lui aussi une session ; il passe par
`POST /api/auth/confirm-email-change` (204) qui applique l'adresse **sans session** — un client
connecté relit seulement son profil. Chaque endpoint refuse le jeton de l'autre, et un lien n'est
valable que sur le site qui l'a émis (`AuthTokenRepository.findValidByTokenHashAndDomain`).
**Décisions** : aucune requête au chargement de la page ne doit ouvrir de session ; ne pas
réintroduire l'appel automatique à l'activation. Reste une victime qui ignorerait l'adresse
affichée et choisirait un mot de passe pour le compte d'un autre — assumé, l'adresse est en tête de
page. Tests : `AuthResourceTest` (`preview_showsTheAddress_opensNoSession_andSpendsNothing`,
`…_ofALinkFromAnotherSite_isRefused`, `confirmEmailChange_changesTheAddress_andOpensNoSession`,
`eachLinkOpensOnlyItsOwnDoor`), `flow-account.e2e.ts` (« a sign-up link opened while signed in
shows its address, warns, and changes nothing until clicked »), `verify_email_page_test.dart`,
Patrol `sign_up_verify_test`. **Contrat cassant : le mobile doit être republié en même temps que le
déploiement** (une app antérieure ne sait plus activer un compte).
