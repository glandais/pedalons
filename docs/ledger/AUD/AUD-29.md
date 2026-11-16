---
id: AUD-29
title: "Le polling du device flow s'arrête à la **première erreur réseau** : toute erreur qui n'est ni « en attente »…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Thème | Audit | Gravité | Constat |
|---|---|---|---|---|
| `AUD-29` | Appareils | §9.2 | — | Le polling du device flow s'arrête à la **première erreur réseau** : toute erreur qui n'est ni « en attente » ni « expiré » le coupe, sur Karoo (`auth/DeviceCodeLogin.kt`, `run`) comme sur Garmin (`PedalonsApp.onPollResponse`). Un flow interrompu ne reprend pas : Karoo ne garde rien, Garmin enregistre le `device_code` (`AuthManager.saveDeviceCode`) mais `getDeviceCode()` n'a aucun appelant. À faire : relancer le polling après une erreur passagère, implémenter la reprise ou retirer le stockage ; comportement sur appareil à valider à la main |
