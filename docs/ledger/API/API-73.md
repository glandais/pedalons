---
id: API-73
title: "Un changement d'adresse coupait les sessions ouvertes pendant 15 min"
status: done
group: "Défauts relevés"
done: 2026-10-04
---

## Livré

`API-73` **Un changement d'adresse coupait les sessions ouvertes pendant 15 min** (2026-10-04) —
`PedalonsQueryContext.doInit` retrouvait l'utilisateur par la valeur `email` du JWT : après
`confirmEmailChange`, chaque jeton d'accès encore valide (web, mobile, autres appareils) ne
résolvait plus personne et prenait un 403, qu'aucun client ne rafraîchit (ils ne le font que sur
401). Il le résout maintenant par le claim `userId` (`findActiveByIdAndDomain`), le contrôle du
`domainId` du jeton restant en tête ; `UserService.lookupUserByEmailAndDomain`, qui ne servait
qu'à ça, a disparu. Tous les jetons émis portent déjà `userId` (`JwtService`, `DeviceJwtService`) :
rien à migrer, et un déploiement roulant n'en coupe aucun. Pas de changement de contrat. Couvert par
`AuthResourceTest.confirmEmailChange_keepsTheAccessTokensIssuedBeforeIt`, le cloisonnement par
`AccessTokenDomainTest`. Le contournement web (`WEB-59`) reste : il renouvelle aussi l'utilisateur
affiché. **À ne pas défaire** : le claim `email` d'un jeton n'identifie personne — il périme au
premier changement d'adresse.
