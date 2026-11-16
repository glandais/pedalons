---
id: SEC-27
title: "Le refresh token est renouvelé à chaque usage : M7"
status: done
done: 2026-09-30
---

## Livré

`SEC-27` **Le refresh token est renouvelé à chaque usage : M7** (2026-09-30, **API 9.1.1**, patch — `AuthResponse.refreshToken` rempli par `POST /api/auth/refresh` pour le
flux à en-tête ; migration `V53__auth_session_rotation` ; détaché de `SEC-11`) — un refresh token
volé ouvrait la session 30 jours. Décision de l'utilisateur : **rotation avec une tolérance** —
chaque refresh émet un nouveau jeton ; l'ancien, gardé en `previous_refresh_token_hash`, obtient
encore un access token **sans nouvelle rotation** pendant 60 s (`…rotation-grace-seconds`) : les
autres onglets, le rendu SSR, l'app qui reprend, partis avec le même jeton ; présenté après, c'est
une copie rejouée, et **la session est révoquée** (pour le voleur comme pour le titulaire, dans sa
propre transaction). La rotation est un `update` conditionnel (`AuthSessionRepository.rotate`) :
de deux refresh simultanés, un seul la gagne, l'autre tombe dans la tolérance. Un jeton plus vieux
de deux rotations est inconnu (403, sans révocation). La déconnexion accepte aussi le jeton
précédent. Web : le nouveau jeton ne va que dans le cookie `HttpOnly`, jamais dans le corps ;
**le SSR relaie le `Set-Cookie` de son refresh** dans toute réponse de document, redirection et
erreur 500 comprises (`resolveSsrSession` → `RenderSink` → `server.js`), faute de quoi le cookie
du navigateur deviendrait un rejeu. Mobile : le jeton revient dans `refreshToken`, que l'app
enregistrait déjà (`auth_interceptor.dart`, `auth_provider.dart`) : pas de code mobile, mais **le
comportement de `/auth/refresh` change et entre dans le train mobile** ; le Patrol `MOB-38`
(jeton d'accès expiré) couvre ce cycle et **doit être relancé à la recette**. V53 ajoute aussi les
index de `refresh_token_hash`, qui n'en avait pas. Colonnes nulles : pendant un déploiement,
l'ancienne version ne fait pas tourner les jetons ; un jeton précédent présenté à elle échoue (403)
et renvoie à la connexion. **Les appareils** tournent aussi, depuis `SEC-11`, par le même
`RefreshTokenRotation`. Suite e2e réécrite pour le modèle « une session, un
détenteur » (`frontend/e2e/README.md`, « How sessions work ») : plus de session enregistrée et
partagée ; mot de passe pour les rôles, admin compris ; session propre à chaque contexte et à
chaque `signIn` ; jeton renouvelé réécrit dans le cookie ou l'objet qui le détient. Tests :
`AuthServiceTest` (rotation, tolérance, rejeu après tolérance, jeton de deux rotations,
déconnexion avec le jeton précédent), `AuthResourceTest` (cookie renouvelé et absent du corps,
en-tête), `ssrSession.test.ts`, `auth.e2e.ts` (document qui renouvelle le cookie, refresh
simultanés) — les tests backend **écrits sans avoir été lancés**. Ne pas mettre le jeton dans le
corps d'une réponse à cookie, ni rendre une réponse SSR sans le `Set-Cookie` de son refresh.
