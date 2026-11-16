---
id: SEC-25
title: "Un identifiant ne résout plus un compte ni une passkey d'un autre site : M8"
status: done
done: 2026-09-30
---

## Livré

`SEC-25` **Un identifiant ne résout plus un compte ni une passkey d'un autre site : M8**
(2026-09-30, contrat inchangé, pas de migration ; détaché de `SEC-11`) — `UserRepository.findActiveById`
et `PasskeyRepository.findByCredentialId` cherchaient sur toute la table, et chaque appelant
devait penser à comparer le domaine après coup. `findActiveById` est remplacé par
`findActiveByIdAndDomain` partout où l'on sert un site : utilisateur de la requête et du jeton de
tuiles (`PedalonsQueryContext`), retrait d'un membre (`TeamMembershipService`), connexion GPS et
son retour OAuth (`GpsService`), migration biketeam en direct (`BiketeamLiveMigrationWorker`, le
domaine du job). Seule l'administration plateforme, transverse par construction, garde une
recherche tous sites, renommée `findActiveByIdOnAnyDomain` pour que l'exception se voie. La
connexion par passkey cherche par `findByCredentialIdAndDomain` ; la vérification de domaine qui
suivait reste en seconde barrière. L'enregistrement garde une recherche tous sites
(`existsByCredentialId`) : la colonne `credential_id` est unique sur toute la table. Tests :
`UserRepositoryTest.findActiveByIdAndDomain_shouldNotReachAnotherSitesAccount`,
`PasskeyRepositoryTest.findByCredentialIdAndDomain_shouldNotFindAnotherSitesPasskey` —
**écrits sans avoir été lancés**. Ne pas réintroduire de recherche par identifiant sans domaine
dans un chemin de requête.
