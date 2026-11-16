---
id: SEC-37
title: "Le challenge d'authentification par passkey est strictement à usage unique"
status: done
done: 2026-10-11
---

## Livré

`SEC-37` **Le challenge d'authentification par passkey est strictement à usage unique** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `PasskeyService.verifyAuthentication` lisait le challenge sans verrou puis le supprimait en `requiringNew` par `deleteById`, dont il ignorait le résultat. Deux soumissions simultanées d'une même assertion signée lisaient toutes deux le challenge. Pour la seconde, `deleteById` ne trouvait plus rien et répondait `false` sans lever d'exception, puis webauthn4j validait l'assertion une deuxième fois. Le compteur de signatures ne protégeait pas : `Passkey` n'a pas de `@Version`, et les passkeys synchronisées envoient 0. Résultat : deux sessions pour un seul challenge. Désormais, `WebAuthnChallengeRepository.consume(id)` émet un unique `DELETE … WHERE id = ?`, qui attend le verrou de ligne d'un consommateur concurrent et renvoie `true` seulement s'il a supprimé la ligne. La vérification refuse en `400 TOKEN_INVALID` quand il renvoie `false`, et cela **avant** `webAuthnManager.verify`. `verifyRegistration`, qui avait le même défaut, passe aussi par `consume`. Couvert par `PasskeyChallengeDoubleUseRaceTest` (`challengeConsumedConcurrentlyAfterLookup_isRefused` ; le test témoin `control_validAssertionAuthenticatesOnce` prouve que l'authentificateur logiciel est valide). **À ne pas défaire** : on ne vérifie l'assertion que si **cette** requête a supprimé la ligne. Ni revenir à `deleteById` en ignorant son résultat, ni se contenter de tester son booléen : dans l'autre entrelacement, il lève une exception au lieu de renvoyer `false`.
