---
id: API-62
title: "Garmin par OAuth 1.0a, au choix du domaine"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-02
---

## Livré

`API-62` **Garmin par OAuth 1.0a, au choix du domaine** (2026-10-02, **API 10.3.0**, mineure,
migration `V56__garmin_oauth1.sql`, colonnes nullables ou à défaut seulement) — le programme
OAuth 2.0 de Garmin est en pause et n'admet pas notre application (`API-61`) ; seules les
applications déclarées avant, en OAuth 1.0a, fonctionnent. Le code OAuth 2.0 est **conservé**.
- **Credential** : `DomainGpsCredential.oauthVersion` (`GpsOAuthVersion`, `OAUTH2` par défaut,
  toutes les lignes existantes le restent). En `OAUTH1`, `clientId` est la consumer key et le
  secret la consumer secret. L'admin le règle (`oauthVersion` sur `CreateGpsCredentialRequest`,
  `null` = `OAUTH2` ; sur `UpdateGpsCredentialRequest`, `null` = inchangé ; renvoyé par
  `AdminGpsCredentialDto`) ; `OAUTH1` est refusé hors Garmin (`GPS_OAUTH_VERSION_NOT_SUPPORTED`)
  et sans secret (`GPS_CLIENT_SECRET_REQUIRED`). Sur le site, un sélecteur « Protocole »
  n'apparaît que pour Garmin, avec l'avertissement qu'en changer oblige chacun à reconnecter.
- **Flux** (`GarminOAuth1Client`, mêmes endpoints que biketeam) : request token
  (`connectapi.garmin.com/oauth-service/oauth/request_token`, `oauth_callback` = le callback
  habituel `/api/gps/callback/garmin`), consentement sur `connect.garmin.com/oauthConfirm`, access
  token contre `oauth_verifier`. Le request token **tient lieu de state** : c'est lui que Garmin
  renvoie, il est stocké dans `gps_oauth_states.state` avec son secret chiffré
  (`request_token_secret_encrypted`), à usage unique et vérifié contre le service et le domaine
  comme un state OAuth 2.0. Le callback accepte `oauth_token`/`oauth_verifier` en plus de
  `code`/`state` ; un `oauth_token` sans verifier est un refus (`gps_error=access_denied`).
- **Connexion** : le secret de l'access token est chiffré dans
  `gps_service_connections.access_token_secret_encrypted` ; sa présence fait d'une connexion une
  connexion OAuth 1.0a (`GpsServiceConnection.oauthVersion()`), sans expiration ni refresh.
- **Envoi** : même requête `POST …/training-api/courses/v1/course` pour les deux protocoles
  (`GarminClient.uploadCourse`), signée HMAC-SHA1 (`OAuth1Signer`, écrit à la main, sans
  dépendance) au lieu d'un `Bearer`. **Le JSON était faux pour les deux** : `lat`/`lon`/`altitude`
  sont devenus `latitude`/`longitude`/`elevation`, et `coordinateSystem: "WGS84"` est envoyé,
  conformément à la Courses API et au format de biketeam.
- **Changement de protocole** : une connexion faite sous l'autre protocole n'empêche pas de se
  reconnecter (la nouvelle remplace l'ancienne), et elle est supprimée à son prochain envoi, qui
  répond `success: false` sans lever d'exception pour que la suppression soit validée.

Tests (verts au 16 octobre 2026) : `OAuth1SignerTest` (vecteur publié de Twitter, vérifié à part :
`hCtSmYh+iHYCEqBWrE7C7hYmtUk=`), `GpsServiceOAuth1Test` (Garmin mocké : URL de consentement,
stockage du jeton et du secret, usage unique, request token inconnu, request token refusé par le
callback OAuth 2.0, envoi signé avec les bons jetons, connexion OAuth 2.0 abandonnée à l'envoi ou
remplacée à la reconnexion), `AdminGpsCredentialResourceTest` (défaut `OAUTH2`, refus hors Garmin
et sans secret, bascule et conservation à la mise à jour). L'échange réel avec Garmin n'est pas
testé. **À ne pas défaire** : ne pas mettre la consumer secret dans le code ni dans une app ;
garder le request token comme clé du state (Garmin ne renvoie pas de `state`) ; garder le code
OAuth 2.0 jusqu'à `API-61`.
