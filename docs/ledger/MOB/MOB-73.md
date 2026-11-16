---
id: MOB-73
title: "Vérifier l'APK sur un Android sans Google Play Services"
status: open
group: "APK hors Play"
kind: recette
verified: 2026-11-16
---

## Reste à faire

`MOB-73` **Vérifier l'APK sur un Android sans Google Play Services** — l'APK de
`mobile-release.yml` (`MOB-72`, publié dans la release `mobile-latest`) n'a encore tourné sur
aucun appareil sans GMS. Sur un émulateur d'image `default` (sans Google APIs) ou un vrai
appareil (/e/OS, Huawei) : démarrage (Firebase doit échouer en silence, `main.dart`),
connexion par mot de passe et réinitialisation, carte, localisation (`geolocator`, appelé sans
option dans `location_service.dart`, doit basculer sur `LocationManager`), écran des
notifications sans jeton FCM, lien profond `www.pedalons.fr` (empreinte `26:24:…` de
`assetlinks.json`, servie en prod). Les **passkeys** passent par Credential Manager, qui n'a
souvent aucun fournisseur sans GMS : le bouton de connexion est déjà masqué quand
`PasskeyService.isSupported()` répond non (`passkey_service.dart`, `login_page.dart`) ; vérifier qu'il renvoie
bien faux sans fournisseur, et qu'ailleurs un échec donne un message clair plutôt qu'une erreur
brute. À décider ensuite : l'écran des notifications devrait-il dire que le push est
impossible, et faut-il signaler une nouvelle version aux installations par APK (rien ne les
met à jour aujourd'hui). Taille : S pour la recette, inconnue pour les suites.
