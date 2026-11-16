---
id: API-64
title: "Les appareils appairés, listés et déliés un par un"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-03
---

## Livré

`API-64` **Les appareils appairés, listés et déliés un par un** (2026-10-03, **API 10.5.0**,
mineure, migration `V58__auth_session_device_client.sql`, colonne nullable ; **10.5.1**, patch :
descriptions « Karoo, Garmin ») — un Karoo ou un Garmin appairé par code (RFC 8628) n'apparaissait nulle part : l'appairage ne laissait
qu'une `AuthSession` anonyme (`userAgent = "karoo Device"`), et seul « Déconnecter tous les
appareils » pouvait le délier, en fermant aussi le navigateur et l'app.
- **Backend** : `AuthSession.deviceClient` (le `clientId` de l'appairage, null pour le site et
  l'app), renseigné par `DeviceAuthService.createTokenResponse` ; la migration le reprend des
  sessions existantes depuis `user_agent`. `GET /api/users/me/devices` (`PairedDeviceDto` : `id`,
  `type` `KAROO`/`GARMIN`/`OTHER` — le device flow accepte tout `clientId` —, `pairedAt`,
  `lastUsedAt` tenu par la rotation du refresh), sessions vivantes seulement, plus récentes
  d'abord ; `DELETE /api/users/me/devices/{deviceId}` révoque cette session
  (`PairedDeviceService`). Le jeton d'accès de l'appareil, un JWT, reste valide jusqu'à son
  expiration (15 min), comme après un logout-all.
- **Clients** : sous les services GPS du profil, « Appareils appairés » — logo (Hammerhead pour
  un Karoo, Garmin pour un Garmin), « Appairé le … · utilisé il y a … », une croix « Délier »
  nommant l'appareil derrière une confirmation, et sans appareil un renvoi vers `/applications`.
  Le type s'affiche « Garmin », jamais « montre Garmin » : l'appareil appairé est le plus souvent un
  compteur Edge.
  Web `PairedDevicesManager`, mobile `PairedDevicesCard` (`paired_devices_section.dart`).
- **Tests** : `PairedDevicesTest` (liste sans les sessions web ni celles d'un autre, ordre,
  `lastUsedAt` après un refresh, déliaison d'un seul appareil dont le refresh échoue en
  `TOKEN_INVALID`, 404 pour l'appareil d'un autre, une session web ou un second appel) ; vitest
  `PairedDevicesManager.test.tsx` ; widget `paired_devices_card_test.dart` ; e2e
  `flow-device.e2e.ts` (« the profile lists each paired device… », « a device of someone
  else… ») ; Patrol `profile_paired_devices_test.dart`. **À ne pas défaire** : identifier un
  appareil par `device_client`, jamais en analysant `user_agent` ; un seul 404 pour tout ce qui
  n'est pas un appareil vivant de l'appelant (rien ne dit qu'une session existe) ; délier ne
  touche qu'une session.

`API-64` **QR code d'appairage sur l'app Garmin** (2026-10-03, sans changement de contrat) —
l'écran de connexion (`garmin-app/source/LoginView.mc`) affiche, comme le Karoo, un QR de
`verificationUriComplete` au-dessus du code, sur tous les Edge du manifest. Il affichait une URL
écrite en dur (`pedalons.fr/garmin`), fausse sur tout autre domaine : c'est maintenant l'hôte de
`verificationUri`, celle que renvoie le backend. Toybox n'a pas d'API de code-barres :
`QrCode.mc` encode en Monkey C, réduit à l'utile — mode octet, niveau L, versions 3 et 4 (un
seul bloc Reed-Solomon, au-delà de 78 octets l'écran retombe sur l'URL et le code) et **masque 0
toujours**. Tests : `QrCodeTest.mc` (`make test`, simulateur lancé), comparé module par module à
`python-qrcode` sur quatre URL aux bornes des deux versions, vecteurs produits par
`garmin-app/scripts/qr-vectors.py`, qui vérifie aussi qu'ils se décodent (OpenCV). Le rendu et
le scan sur l'écran d'un Edge n'ont pas été vérifiés. **À ne pas défaire** : ne pas ajouter
l'évaluation des huit masques (n'importe quel masque se lit, et c'est le calcul qui exposerait au
watchdog Connect IQ) ; garder le code en clair sous le QR, la page web demande de le comparer
avant d'appairer (`SEC-2`) ; ne pas prendre segno comme référence, il bourre autrement et produit
un autre QR, valide lui aussi.
