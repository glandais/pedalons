---
id: SEC-3
title: "Le jeton d'accès mobile ne part plus que vers l'API : H4"
status: done
done: 2026-09-30
---

## Livré

`SEC-3` **Le jeton d'accès mobile ne part plus que vers l'API : H4** (2026-09-30, contrat
inchangé) — l'app mobile posait son `Authorization: Bearer` sur toute image qu'elle chargeait,
quel que soit son hôte, et une image de markdown pointe où son auteur le veut. Désormais le jeton
ne part que vers l'**origine** de l'API — même schéma, même hôte, même port que `API_BASE_URL`
(`mobile/lib/api/credential_scope.dart`, `carriesCredentials` et `authHeadersFor`) : les trois
chargeurs d'`authenticated_image.dart` et l'intercepteur Dio (`AuthInterceptor`) passent par elle,
et un 401 venu d'un autre hôte ne déclenche plus de rafraîchissement, dont le nouvel essai aurait
porté le jeton neuf là-bas. **Décisions** (choisies par l'utilisateur) : une image externe
s'affiche quand même, sans jeton, comme sur le web ; l'hôte seul ne suffit pas, un `http://` vers
le même hôte ferait circuler le jeton en clair. Ne jamais reposer l'en-tête à la main hors de ces
deux fonctions. Tests : `test/api/credential_scope_test.dart`. Livré avant la republication
mobile qu'impose `SEC-2`.
