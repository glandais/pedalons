---
id: API-57
title: "`AuthToken` ne mappe plus `pending_password_hash`"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-01
---

## Livré

`API-57` **`AuthToken` ne mappe plus `pending_password_hash`** (2026-10-01, livré avec l'API
10.0.0, contrat inchangé, pas de migration) — le champ, inutilisé depuis `SEC-24` (le mot de
passe se choisit à l'activation), est retiré d'`AuthToken`, et `AccountExport.AuthTokenEntry`
ne le mentionne plus (il ne l'exportait déjà pas : la forme de `auth-tokens.json` ne change pas).
La colonne reste, nullable depuis `V15` (aucune contrainte `NOT NULL` ajoutée ensuite) : la
nouvelle release peut insérer sans elle. Sa suppression est `API-58`. Tests :
`AuthResourceTest.register_storesNoPassword` et `verifyEmail_setsThePasswordChosenOnActivation`
(le jeton d'avant `SEC-24` portant un hachage n'est plus représentable : l'aide de test
`createVerificationTokenWithPassword` devient `createSignUpVerificationToken`),
`UserExportServiceTest`, `UserExportResourceTest` — 81 tests verts le 1er octobre. **À ne pas
défaire** : ne pas supprimer la colonne dans la même release que le champ — la 9.3.0, encore en
service pendant le recouvrement start-first, l'écrit à chaque `INSERT` ; et ne pas la rendre
`NOT NULL`.
