---
id: SEC-30
title: "En-têtes de sécurité HTTP : V4"
status: done
done: 2026-09-30
---

## Livré

`SEC-30` **En-têtes de sécurité HTTP : V4** (2026-09-30, contrat inchangé, prend effet au prochain
`deploy.sh`) — vérifié le même jour sur la prod : ni HSTS, ni CSP, ni `X-Frame-Options`, ni `nosniff`
sur les pages et l'API, et `X-Powered-By: Express`. Posés par Traefik (`docker-compose.yml`), un
middleware `headers` par routeur, **chacun défini sur son propre service** (`api-headers` sur le
backend, `site-headers` sur le frontend) : un middleware partagé, défini sur l'un et utilisé par
l'autre, faisait tomber le site avec le backend (« middleware does not exist » vu au redémarrage).
HSTS un an (`forceSTSHeader` : Caddy parle HTTP à Traefik, qui ne l'enverrait sinon qu'en TLS ;
sans `includeSubDomains`), `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy:
strict-origin-when-cross-origin`, `Permissions-Policy` (caméra, micro, paiement, USB fermés ;
géolocalisation au site). Le site seul reçoit une CSP, limitée aux directives qui ne contraignent
aucun script : `frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'self'`
(rien n'embarque le site en iframe, aucun formulaire ne poste ailleurs) ; la contrainte des scripts
est `SEC-31`. `server.js` ne dit plus `X-Powered-By`. **À ne pas défaire** : pas de CSP sur le
routeur de l'API — elle écraserait la CSP bac à sable des téléchargements (`UploadedContentHeaders`,
`SEC-1`) et empêcherait la visionneuse PDF de démarrer. Vérifié sur la pile locale, puis en prod
et en staging le 1er octobre 2026 après déploiement : les en-têtes sur `/` et `/api/version`, plus
de `X-Powered-By`, et la CSP bac à sable d'un téléchargement réel arrive intacte. Pas de test
automatisé (configuration du proxy).
