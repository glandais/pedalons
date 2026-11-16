---
id: MOB-58
title: "Les pages du site s'ouvrent dans le navigateur de l'appareil"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-11
---

## Livré

`MOB-58` **Les pages du site s'ouvrent dans le navigateur de l'appareil** (11 octobre 2026,
contrat inchangé). `openWebPage` (`mobile/lib/core/utils/link_launcher.dart`) ouvrait les pages
sans écran dans l'app (tableau de bord d'organisateur, notification de signalement, page
Fonctionnalités) dans un `LaunchMode.inAppBrowserView`, qui ne partage la session ni de l'app ni
du navigateur : le membre se reconnectait à chaque fois. Elles s'ouvrent désormais dans le
navigateur de l'appareil, qui garde sa propre connexion d'une page et d'une fois sur l'autre.
Le domaine étant celui des liens d'app, dont les jokers captent toute l'équipe (`MOB-59`), le
système aurait rendu ces adresses à l'app : sous Android, `MainActivity.kt` expose le canal
`fr.pedalons.mobile/browser` qui **nomme** le navigateur (celui par défaut, sinon le premier
installé qui n'est pas l'app) ; sous iOS, `scripts/generate-routes.mjs` place en tête de l'AASA
une entrée `NOT …` par page du site sans écran dans l'app qu'un joker capterait, et échoue si
une exclusion couvrait le chemin d'un deeplink. Tests : `link_launcher_test.dart`,
`login_discover_features_test.dart` (par `debugLinkOpener`) ; le canal natif et l'AASA se
vérifient sur un appareil. **À ne pas défaire** : jamais d'`ACTION_VIEW` implicite ni
d'`openLink` pour une page du site (l'app se la renverrait) ; une page `web: true` sans écran
mobile n'est jamais revendiquée par l'AASA. Délibérément pas fait : le jeton d'échange court
émis par l'API pour ouvrir le site déjà connecté (changement de contrat) — le navigateur ne
demande la connexion qu'une fois.
