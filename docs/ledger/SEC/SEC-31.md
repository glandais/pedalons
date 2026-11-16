---
id: SEC-31
title: "CSP complète du site, d'abord en Report-Only : V4 (suite)"
status: done
done: 2026-10-15
---

## Livré

`SEC-31` **CSP complète du site, d'abord en Report-Only : V4 (suite)** (2026-10-15, contrat
inchangé, prend effet au prochain `deploy.sh`) — `SEC-30` n'avait posé que `frame-ancestors`,
`base-uri`, `object-src`, `form-action` : rien ne contraignait scripts, styles ni origines. La
politique est désormais construite par `frontend/server.js` (`frontend/server/csp.js`), et non plus
par un label Traefik : un nonce de 128 bits tiré à chaque page, et les hôtes de carte de la config de la
requête. Les deux états SSR ne sont plus des scripts : `__REACT_QUERY_STATE__` et `__AUTH_STATE__`
sont devenus des blocs `<script type="application/json">` (`#ssr-query-state`, `#ssr-auth-state`,
`server/ssrState.js`, `<`, `>` et `&` échappés), lus par `src/lib/ssrState.ts` (seulement en enfant
direct de `<body>`). Le nonce va sur le script de thème d'`index.html` (pas un hash : une retouche
du fichier ne le casse pas en silence) et sur le script d'hydratation de React Router
(`StaticRouterProvider nonce`), un quatrième script inline que l'entrée ne nommait pas. Politique :
`default-src 'self'; script-src 'self' 'nonce-…'; style-src 'self' 'unsafe-inline'; img-src 'self'
data: blob: https:; font-src 'self' data:; connect-src 'self' <hôtes>; worker-src 'self';
manifest-src 'self'; frame-src 'none'` plus les quatre de `SEC-30`, `report-uri /csp-report` et
`report-to csp`. `connect-src` suit `/api/config` : styles et variantes sombres, hôtes de tuiles des
fonds raster que le backend enveloppe (`/api/map/styles/{id}.json`, relus par `server.js`, gardés
dix minutes), TileJSON du relief, Firebase quand le web push est configuré, et
`CSP_CONNECT_SRC_EXTRA` pour un style tiers qui sortirait de son hôte. Un style raster dont la
relecture échoue garde ses hôtes de la dernière lecture réussie ; une page rendue sans config (appel
SSR en échec) reprend la dernière liste d'hôtes construite par le processus, et s'il n'en a encore
vu aucune, cette page-là ne part qu'en Report-Only, même sous `enforce`. Zod tourne `jitless`
(`src/lib/zodConfig.ts`), sans quoi chaque formulaire rapportait sa sonde `Function("")`.
`CSP_MODE` (défaut `report-only`) : la politique complète part en `Content-Security-Policy-Report-Only`
à côté des quatre directives appliquées ; `enforce` l'applique — c'est `SEC-40`. Les rapports
arrivent sur `POST /csp-report` (route de `server.js`, pas d'API) : 16 Kio au plus, 120 lignes par
minute pour tous les envoyeurs, une ligne JSON par violation, URLs sans requête ni fragment, sans
extrait de script. Couvert par `frontend/server/csp.test.js`, `ssrState.test.js` et
`cspReport.test.js` ; vérifié sur un `server.js` de production local branché sur staging (en-têtes,
nonce différent à chaque page, quatre scripts dont deux blocs JSON, rapport journalisé). **À ne pas
défaire** : pas de `contentSecurityPolicy` dans le label `site-headers` — Traefik écrase celle de
`server.js` — et toujours aucune CSP sur le routeur de l'API (`SEC-1`, visionneuse PDF) ; pas de
nonce ni de hash dans `style-src`, qui ferait ignorer `'unsafe-inline'` aux navigateurs et casserait
les attributs `style` de Mantine ; pas de `'strict-dynamic'`, qui ferait ignorer `'self'` et
demanderait le nonce sur l'entrée Vite et chaque `modulepreload` ; pas de `'unsafe-eval'`. Aucune
politique complète en dev (préambule React Refresh inline, websocket HMR).
