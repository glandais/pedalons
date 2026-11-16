---
id: NOTIF-9
title: "Notifications — livrées, en production depuis le 21 septembre 2026"
status: done
done: 2026-09-21
---

## Livré

### `NOTIF-9` Notifications — livrées, en production depuis le 21 septembre 2026

Repris le 18 septembre 2026 par
[`plans/archive/2026-09-18-notifications.md`](../../plans/archive/2026-09-18-notifications.md), où le push est devenu un
canal d'un pipeline commun (boîte de réception, e-mail, push). Les phases 1 à 5 (dont le rappel J-1)
sont en production depuis le 21 septembre 2026, le Web Push depuis le 29. Ce qui reste est
`NOTIF-1` à `NOTIF-4`, `NOTIF-11` et `NOTIF-12`.

Le ledger du chantier (`plans/2026-09-18-notifications-ledger.md`, phase par phase avec ses
recettes) a été rapatrié ici et supprimé le 29 septembre 2026 ; il reste dans l'historique git. Les
invariants qu'il portait sont déjà dans le plan de conception, dans `mobile/CLAUDE.md` et dans les
commentaires du code (`V39__push_devices.sql`, `PushNotificationSender`, `FcmClient`,
`NotificationPublisher.silently`) ; ce qui n'était écrit que là suit.

| Phase | Livré | Contrat, migration |
|---|---|---|
| 1 — socle backend | Pipeline évènement → notification → livraison, canaux in-app et e-mail, six endpoints | 3.5.0, V37, V38 |
| 2 — web | Cloche, page Notifications, matrice de préférences, ancre des e-mails | — |
| 3 — mobile | Cloche, écran, matrice, deeplink `/notifications` | — |
| 4 — push serveur | `push_devices`, `FcmClient` (FCM HTTP v1, sans dépendance nouvelle), purge des jetons morts | 3.6.0, V39 |
| 4 bis — push mobile | `firebase_messaging` derrière `PushGateway`, autorisation depuis la boîte, tap qui ouvre `data.path` | — |
| 5 | Rappel J-1, modification retardée, inscription, commentaire, invitation, équipes coupées, résumé quotidien, webhook d'équipe | 3.8.0, V40 |
| Web Push | Site installable, push navigateur par le même FCM (plateforme `WEB`) | 5.4.0 |

Deux types sont venus ensuite, hors de ce chantier : `RIDE_GROUP_REMOVED` et `CONTENT_REPORTED`
(`NotificationType` en compte 13).

**Pièges iOS, à ne pas rejouer** (recette sur iPhone du 21 septembre 2026) :

- **Tap perdu sur application tuée.** Un `content-available: 1` réveillait parfois l'app tuée dès
  l'arrivée du push ; `firebase_messaging` retenait alors le message comme « initial »,
  `getInitialMessage()` — appelé à ce réveil — répondait `null`, et au tap le plugin n'émettait pas
  `onMessageOpenedApp`. Correctif double : `FirebasePushGateway` refait un `getInitialMessage()` à
  chaque retour au premier plan sur iOS, et le serveur n'envoie plus `content-available`
  (`UIBackgroundModes: remote-notification` est parti avec lui). Le push s'affiche sans mode
  d'arrière-plan.
- **Ne pas poser `UNUserNotificationCenter.delegate = self` dans `AppDelegate`** : cela a coupé la
  réception des pushes sur l'iPhone. Agrandir le tampon du canal était l'autre fausse piste (le
  message n'atteignait pas Dart du tout).
- **Une build *debug* iOS ne se relance pas** depuis l'écran d'accueil sans débogueur : le cas
  « application tuée » se recette sur une build *release* signée développement.

**Autres décisions de mise en œuvre** :

- `register` est un upsert natif `ON CONFLICT (token) DO UPDATE` : deux `POST /api/push-devices`
  concurrents au lancement (ouverture de session et `onTokenRefresh`) faisaient échouer l'un des
  deux sur le verrou optimiste.
- `google-services.json` et `GoogleService-Info.plist` sont **commités** : identifiants d'app
  publics et clé API restreinte au bundle, les tenir hors dépôt aurait cassé toute build faite
  ailleurs. Le compte de service FCM et la clé APNs `.p8` vivent hors dépôt, dans
  `~/Documents/pedalons/firebase/`.
- L'export RGPD contient les appareils push **sans le jeton** (c'est l'adresse de l'appareil).

**Préalables hors dépôt** :

- Projet Firebase `pedalons-9e595`, **Analytics et Gemini désactivés** : le push n'en a pas besoin,
  et Analytics aurait ouvert une déclaration de collecte de plus dans les deux formulaires de
  confidentialité.
- Clé APNs créée en **Sandbox & Production** — la portée ne se change plus après coup, et une clé
  Sandbox seule ne livre rien en TestFlight — et téléversée dans Firebase sur les deux lignes
  (développement et production).
- Activer une capacité sur l'App ID `fr.pedalons.mobile` **invalide le profil de provisionnement**.
  Le profil de développement a été réémis le 21 septembre 2026 et **expire le 21 septembre 2027** ;
  le profil de distribution est généré par fastlane à l'archivage (`-allowProvisioningUpdates`).

**Web Push** (fusionné dans `develop` le 28 septembre 2026, en production et testé depuis le
29 septembre) : le site s'installe comme une application et reçoit le push par le même FCM
(plateforme `WEB`).

La cloche de l'accueil, la section Notifications du profil et l'écran « Notifications » (non maquetté)
sont livrés depuis la phase 3 du même plan.

L'analyse d'origine, pour mémoire : le seul mécanisme qui ramène un membre sans qu'il ouvre l'app.
Trois déclencheurs : rappel J-1, annulation de sortie, réponse à un commentaire. Ce qui allongeait le
délai réel n'était pas le code : entitlement `aps-environment` et clé APNs `.p8` côté Apple,
`google-services.json` et permission runtime `POST_NOTIFICATIONS` côté Android 13+, mise à jour des
deux formulaires de confidentialité, et une nouvelle soumission aux deux stores. Voir
`mobile/store-metadata/data-safety.md`, qui est la source de vérité des déclarations. Deux pièges qui
cassent en production et pas en test : l'**idempotence** du rappel J-1 (sans marque « rappel
envoyé », un redémarrage renotifie tout le monde) et la purge des jetons périmés (retour
`UNREGISTERED` de FCM), sans quoi la table grossit indéfiniment.
