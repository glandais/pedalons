---
id: SEC-34
title: "compteur d'essais OTP rendu sûr face aux devinettes concurrentes"
status: done
done: 2026-10-11
---

## Livré

`SEC-34` **compteur d'essais OTP rendu sûr face aux devinettes concurrentes** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `verifyOtp` lisait le code sans verrou. `recordFailedAttempt` incrémentait le compteur en mémoire, puis Hibernate réécrivait toute la ligne depuis cet instantané (pas de `@Version` sur `AuthToken`). Une mauvaise devinette lue avant l'épuisement du code (5 échecs) ou avant la connexion du titulaire, mais validée après, réécrivait donc `failed_attempts=1, used_at=NULL`. Le code redevenait valide et son compteur repartait de zéro : une rafale parallèle obtenait bien plus de 5 essais par code. Désormais, `verifyOtp` verrouille d'abord le compte (`UserRepository.findByEmailAndDomainForUpdate`), puis le code vivant le plus récent (`AuthTokenRepository.findValidByEmailAndTypeForUpdate`, `PESSIMISTIC_WRITE`, même idiome que `AUD-16`). Les devinettes sur une même adresse passent donc l'une après l'autre. Sous READ COMMITTED, une devinette qui attendait relit `used_at is null and expires_at > now` et ne trouve plus un code épuisé ou utilisé. `dontRollbackOn = BadRequestException` reste en place pour que l'échec compté soit validé. Couvert par `OtpFailedAttemptLostUpdateRaceTest` et par `OtpVerifyRequestDeadlockRaceTest`. **À ne pas défaire** : l'ordre des verrous, compte puis code, identique à `createOtp`. Verrouiller le code d'abord interbloque une connexion valide contre une demande de nouveau code : la connexion tient le code et attend le compte pour `recordLogin`, la demande tient le compte et attend le code pour l'invalider. PostgreSQL abandonne alors l'une des deux, d'où une 500 côté connexion ou côté `requestOtp`. Ne pas remplacer ce verrou par un `@Version` (migration, et une 500 `OptimisticLockException` sous contention).
