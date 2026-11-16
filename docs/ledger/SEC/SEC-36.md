---
id: SEC-36
title: "Les limites d'échecs d'authentification tiennent sous concurrence"
status: done
done: 2026-10-11
---

## Livré

`SEC-36` **Les limites d'échecs d'authentification tiennent sous concurrence** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `AuthThrottle` comptait les échecs déjà commités, puis le bcrypt (ou la recherche du code d'appairage) avait lieu, puis l'échec était inscrit en `requiringNew`. Rien ne sérialisait ce contrôle-puis-inscription par sujet : N connexions simultanées sur une même adresse lisaient toutes un compte inférieur à 5 et passaient, soit environ une par connexion du pool (≈ 20 par instance, 40 pendant un déploiement) au lieu de 5. `POST /api/device/oauth/complete`, `deny` et `verify` dépassaient de la même façon le budget de 5 par compte. Désormais, `admitPassword` et `admitDeviceCode` réservent l'essai d'avance : une transaction `requiringNew` courte prend un verrou consultatif `pg_advisory_xact_lock` par budget (adresse hachée pour le mot de passe, domaine pour les codes d'appairage, verrou qui couvre aussi le budget par compte), compte les échecs, puis inscrit l'échec avant le bcrypt ou la recherche, ou bien répond 429 sans rien inscrire. Le bon mot de passe efface l'ardoise (`clearPassword`), un code connu rend son essai (`forgetDeviceCode`), dans la transaction de l'appelant. `findPendingUserCode` devient `@Transactional`. Pas de migration. Couvert par `AuthThrottleConcurrentGuessRaceTest` (8 essais simultanés, exactement 5 vont jusqu'au bcrypt), ainsi que par les tests SEC-4/SEC-7 existants d'`AuthResourceTest` et `DeviceOAuthThrottleTest`. **À ne pas défaire** :
- l'échec est inscrit **avant** le bcrypt, dans la même section verrouillée que le compte ; le réinscrire après le bcrypt rouvre la course ;
- le verrou vit dans la transaction `requiringNew` et non dans celle de l'appelant : tenu jusqu'à la fin de l'appelant, les requêtes en attente garderaient leur connexion pendant que le détenteur en réclame une seconde pour inscrire l'échec, ce qui épuise le pool, fait échouer l'inscription et laisse l'essai non compté ;
- une requête qui meurt en route laisse son essai compté, ce qui est voulu (on se trompe du côté de la limite).
