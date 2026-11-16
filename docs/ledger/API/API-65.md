---
id: API-65
title: "Délier un appareil le coupe aussitôt, et un Karoo s'affiche « Karoo »"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-03
---

## Livré

`API-65` **Délier un appareil le coupe aussitôt, et un Karoo s'affiche « Karoo »** (2026-10-03,
**API 10.5.2**, patch : description de `unpairDevice` ; migration `V59__auth_session_device_client_karoo.sql`)
— après « Délier », l'appareil marchait encore jusqu'à 15 minutes (son JWT n'était pas révocable,
`API-64` l'avait accepté), et un Karoo apparaissait « Autre ».
- **Jeton lié à l'appairage** : le JWT d'un appareil porte la claim `sid` (l'id de l'`AuthSession`
  de l'appairage), à l'émission comme au refresh ; `DeviceSessionFilter` (filtre JAX-RS global,
  `Priorities.AUTHENTICATION`) répond 401 dès que cette session est révoquée ou expirée — délier,
  ou « Déconnecter tous les appareils ». Une requête indexée par appel d'appareil ; les jetons du
  site et de l'app n'ont pas de `sid` et ne sont pas touchés, ceux émis avant le déploiement non
  plus (15 min au plus). 401 et non 403 : Karoo et Garmin y lisent « réappairer ».
- **Karoo** : `DeviceCodeRequest.clientId` avait une valeur par défaut `"karoo"`, que
  kotlinx.serialization n'écrit pas (`encodeDefaults = false`) : le backend recevait `{}` et
  appairait sous `device`. Plus de valeur par défaut ; V59 renomme les appairages `device` en
  `karoo` (Garmin a toujours envoyé `garmin`). Il faut republier l'app Karoo, sinon les nouveaux
  appairages restent « Autre ».
- **Tests** : `PairedDevicesTest.unpair_refusesThatDevicesAccessToken_atOnce`,
  `unpair_refusesTheAccessTokenOfARefresh` (écrits sans avoir été lancés). **À ne pas défaire** :
  ne pas retirer `sid` du jeton d'appareil ni le contrôle du filtre ; ne pas remettre de valeur par
  défaut à un champ Kotlin sérialisé que le backend doit recevoir.
