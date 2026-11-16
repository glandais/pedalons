---
id: SEC-2
title: "Un appareil n'est appairé que sur un « Autoriser » explicite : H3"
status: done
done: 2026-09-30
---

## Livré

`SEC-2` **Un appareil n'est appairé que sur un « Autoriser » explicite : H3** (2026-09-30,
**API 8.0.0**, contrat cassant) — la page d'appairage (`/karoo`, `/garmin`), sur le web comme
dans l'app, autorisait l'appareil d'elle-même dès qu'un utilisateur connecté l'ouvrait avec un
code valide. Elle affiche désormais une carte de confirmation (RFC 8628 §5.4) : l'appareil
(« un Karoo », « un appareil Garmin »), le compte, le code en grand, depuis quand il a été demandé,
un avertissement (« si quelqu'un vous a envoyé ce lien, refusez »), et deux boutons. Côté serveur,
`CompleteRequest` exige `confirmed: true` (`@NotNull @AssertTrue`) : un client ancien qui
approuvait seul reçoit 400 au lieu d'appairer. `VerifyResponse` gagne `clientId` et
`requestedAt`. Nouveau `POST /api/device/oauth/deny` : le code **expire** (plutôt que d'être
supprimé), si bien que l'appareil qui interroge `/token` entend `TOKEN_EXPIRED`, que Karoo et
Garmin traitent déjà en recommençant — ni la requête ni la réponse de `/device` et `/token`
n'ont changé, les deux apps d'appareil n'ont pas à être republiées ; `/deny` compte les codes
inconnus comme `/complete` (`SEC-4`). Décisions de l'utilisateur à garder : garde **à la fois**
dans l'interface et sur le serveur ; le code du lien reste pré-rempli, confirmé par un bouton
(pas de ressaisie, qui ôterait son intérêt au QR code). **Contrat cassant : le mobile doit être
republié en même temps que le backend.** Tests : `DeviceOAuthConfirmationTest` (sans
confirmation ou `false` refusé et rien d'appairé, confirmé appairé, `verify` nomme l'appareil et
l'heure, refus qui fait expirer le code pour tous, code inconnu, refus anonyme) — **écrits sans
avoir été lancés** ; `DeviceOAuthThrottleTest` adapté ; e2e `flow-device.e2e.ts` (confirmation
attendue après connexion, aucun `/complete` avant le clic, nouveau test du refus) et Patrol
(`device_link_test`, `device_link_signed_out_test`, `device_manual_code_test`, étape
`authorize()`) — verts au 16 octobre 2026.
