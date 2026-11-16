---
id: SEC-7
title: "La connexion par mot de passe se ferme après cinq échecs : M4"
status: done
done: 2026-09-30
---

## Livré

`SEC-7` **La connexion par mot de passe se ferme après cinq échecs : M4** (2026-09-30, API
6.4.0, mineur : `LOGIN_RATE_LIMITED`, réponse 429 sur `POST /api/auth/login` ; migration
`V50__auth_failures`) — chaque mot de passe erroné, adresse inconnue comprise, est noté dans
`auth_failures` (`AuthThrottle`) ; au cinquième en 15 minutes pour une adresse, `/login` répond
`429 LOGIN_RATE_LIMITED` avec `Retry-After: 900`, **avant** tout bcrypt : la rafale ne coûte plus
de CPU. Un bon mot de passe efface les échecs de l'adresse. Décisions à garder : le compteur est
**par adresse** (casse ignorée), jamais par IP — le premier `X-Forwarded-For` est celui que le
client envoie (`forwardedHeaders.insecure`), une limite par IP n'arrêterait que les attaquants
honnêtes ; il compte aussi les adresses sans compte, sinon la limite dirait lesquelles existent ;
la table ne garde qu'une **empreinte SHA-256** de l'adresse, 24 heures (purge dans
`AuthCleanupScheduler`, annoncée par la politique de confidentialité, §1, §6, §9) ; l'échec est
écrit dans sa **propre transaction** (`QuarkusTransaction.requiringNew`), sans quoi le rollback de
l'erreur l'effacerait ; en base et non en mémoire, puisque deux backends coexistent pendant un
déploiement. Le prix assumé : un tiers peut fermer 15 minutes la connexion *par mot de passe*
d'une adresse — le code par e-mail et les passkeys restent ouverts. Reste hors de portée le
bourrage d'identifiants réparti sur beaucoup d'adresses : c'est la limite globale de M10
(`SEC-28`). Tests : `AuthResourceTest` (bloc « Password throttle » : refus même avec le bon mot de
passe, casse, adresse inconnue, remise à zéro, indépendance des adresses) — **écrits sans avoir
été lancés**. Seuils réglables : `pedalons.auth.password.max-failures`,
`…failure-window-minutes`.
