---
id: SEC-11
title: "Le jeton d'accès des appareils vit 15 minutes, et leur refresh token tourne : M9"
status: done
done: 2026-09-30
---

## Livré

`SEC-11` **Le jeton d'accès des appareils vit 15 minutes, et leur refresh token tourne : M9**
(2026-09-30, **API 9.1.2**, patch : description de `DeviceTokenResponse.refreshToken` ; pas de migration — celle de `SEC-27` suffit) — le JWT d'un Karoo ou d'une montre
Garmin vivait 60 minutes sans pouvoir être révoqué. Décisions de l'utilisateur : **15 minutes**,
comme le site (`DeviceJwtService`, `pedalons.device.jwt.access-token-expiry-minutes`), et **la
rotation du refresh token des appareils tout de suite**, par le même composant que le site et
l'app (`RefreshTokenRotation`, extrait d'`AuthService` : tolérance d'une minute, rejeu révoqué ;
pour un appareil, un rejeu ou un jeton inconnu répond `TOKEN_INVALID`). L'app Garmin gardait déjà
un `refreshToken` renvoyé ; **Karoo l'ignorait** (`updateAccessToken`) : il enregistre désormais
toute la réponse (`AuthManager.saveTokens`, aux trois appels de refresh). Aucun Karoo n'avait
l'app installée le 30 septembre 2026 : personne à réappairer. Karoo doit être republié
avec ce changement avant tout nouvel appareil ; Garmin n'a rien à changer. M8 et M10, d'abord rangés ici, sont
livrés sous `SEC-25` et `SEC-28`, M7 sous `SEC-27`. Tests : `DeviceRefreshRotationTest`
(rotation, 15 minutes, tolérance, rejeu) — **écrit sans avoir été lancé** ; `flow-device.e2e.ts`
attend désormais un jeton renouvelé. Ne pas rallonger le jeton d'accès d'un appareil tant qu'il
n'est pas révocable.
