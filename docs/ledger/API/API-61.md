---
id: API-61
title: "Mettre l'intégration Garmin OAuth 2.0 en conformité"
status: open
group: "Garmin"
verified: 2026-11-16
---

## Reste à faire

`API-61` **Mettre l'intégration Garmin OAuth 2.0 en conformité** — **bloqué** : le programme
Garmin Connect Developer n'admet aucune nouvelle application tant qu'il est en pause (toujours
sans date de réouverture au 16 octobre 2026) ; en attendant, les domaines passent par OAuth
1.0a avec les applications déjà déclarées (`API-62`), qui marchent en prod. À reprendre quand
l'application OAuth 2.0 pourra être créée, d'après la doc Garmin
(Courses API 1.0.1, OAuth2 PKCE, Start Guide 1.2). Ce qu'il reste, tout dans
`infrastructure/gps/GarminClient.java` et `service/gps/GpsService.java` :
- **`externalUserId` toujours null** : la réponse du jeton n'a pas de `user_id` ; il faut
  `GET https://apis.garmin.com/wellness-api/rest/user/id` après l'échange (identifiant
  principal selon Garmin, celui que portent les webhooks).
- **Déconnexion sans prévenir Garmin** : `GpsService.disconnect` (et l'effacement du compte)
  doit appeler `DELETE https://apis.garmin.com/wellness-api/rest/user/registration`, que
  Garmin exige dès qu'une app propose une déconnexion.
- **Codes d'erreur** : la synchronisation automatique (`API-120`) distingue déjà 401 et 412
  (connexion à reconnecter) et 429 (pause selon `Retry-After`) ; l'envoi manuel les confond
  encore (`API-126`). Reste, propre à Garmin : un 401 (jeton révoqué) devrait
  supprimer la connexion plutôt que la laisser « à reconnecter » ; la revue de production
  vérifie la gestion des quotas.
- **Marge de rafraîchissement** : `GpsServiceConnection.isTokenExpired()` prend 300 s, Garmin
  recommande au moins 600 s (jeton de 86 400 s ; refresh token de 90 jours, renouvelé à
  chaque refresh — déjà géré).
- **Taille des parcours** : ~10 000 points au plus, 100 m au plus entre deux, un point tous
  les 100 m recommandé — rien ne le vérifie ni ne rééchantillonne.
- **Webhooks** désinscription et changement de permissions (Start Guide §2.6) : sans eux une
  connexion révoquée côté Garmin reste « connectée » jusqu'au premier 401.
- **`activityType`** toujours `ROAD_CYCLING` (biketeam le tirait du type de carte), et le D+
  de `GarminCourseConverter` saute un point à 0 m exactement (`prevEle != 0` sert de « pas
  d'altitude »).

Les points 401, quotas, taille et `activityType` valent aussi en OAuth 1.0a. Une fois
l'application créée, basculer le domaine se fait dans l'admin (protocole du credential
Garmin) : les connexions OAuth 1.0a sont alors abandonnées à leur prochain envoi et chacun
reconnecte Garmin. Taille : M.
