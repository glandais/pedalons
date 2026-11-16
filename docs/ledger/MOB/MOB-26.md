---
id: MOB-26
title: "Clés d'accès"
status: open
group: "Couverture e2e Patrol — ce que les tests ne couvrent pas encore"
verified: 2026-11-16
---

## Reste à faire

`MOB-26` **Clés d'accès** — une clé ajoutée depuis le profil (`passkeys_section.dart`) connecte
depuis `login_page.dart` ; une clé supprimée ne connecte plus (`flow-account.e2e.ts`). Demande
un authentificateur sur le simulateur ou l'émulateur.
**Bloqué sur la stack e2e** (évalué le 29 septembre 2026) : le RP ID y est `localhost` en HTTP,
alors qu'iOS n'accepte une clé que pour un domaine associé (`webcredentials:`, fichier
`apple-app-site-association` servi en HTTPS de confiance) et que `Runner.entitlements` ne
déclare que `www.pedalons.fr` ; la correspondance Face ID du simulateur ne se pilote pas depuis
Patrol ; Android bute de même sur `assetlinks.json`. Il faudrait un nom d'hôte HTTPS pour la
stack (certificat mkcert ajouté au simulateur), `PEDALONS_WEBAUTHN_RP_ID` et
`--dart-define=WEBAUTHN_RP_ID` réglés dessus, une variante d'entitlements de debug
(`?mode=developer`) et un pas « visage reconnu » lancé par l'hôte.
