---
id: SEC-4
title: "Les codes d'appairage ne se devinent plus : H5"
status: done
done: 2026-09-30
---

## Livré

`SEC-4` **Les codes d'appairage ne se devinent plus : H5** (2026-09-30, API 6.4.0, mineur :
`DEVICE_CODE_RATE_LIMITED`, réponse 429 sur `POST /api/device/oauth/complete` et
`GET /api/device/oauth/verify` ; même table que `SEC-7`) — un code à 6 caractères (32⁶) se
devinait sans limite : par `/complete` pour rattacher l'appareil d'un autre à son compte, ou par
`/verify`, anonyme, qui révélait les codes en attente. Chaque code inconnu compte désormais contre
le compte (5 en 10 minutes, durée de vie d'un code) et contre le **domaine entier** (300 en
10 minutes, signés ou non) ; au-delà, 429 avant la recherche. Le budget par domaine est ce qui
arrête une foule de comptes jetables — et `/verify`, qui n'a pas d'autre clé fiable ; son prix,
assumé : une rafale ferme l'appairage du domaine le temps que la fenêtre glisse (300 essais
trouvent un code donné une fois sur 3,5 millions de fenêtres). `/verify` filtre en outre par
domaine (`DeviceCodeRepository.findValidByUserCode(domainId, …)`) : le code d'un autre site y
répondait. `/token` n'est pas freiné (`device_code` de 256 bits) : pas de `slow_down`, voir
`AUD-27`. Tests : `DeviceOAuthThrottleTest` (limite par compte même avec le bon code, codes justes
jamais comptés, budget du domaine sur `/verify` puis `/complete`, budget propre à chaque domaine,
code d'un autre domaine inconnu) — **écrits sans avoir été lancés**. Seuils :
`pedalons.auth.device-code.*`.
