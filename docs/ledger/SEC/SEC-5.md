---
id: SEC-5
title: "Les clés JWT de prod et de staging ne viennent pas de l'historique public : V1 non confirmé"
status: done
done: 2026-09-30
---

## Livré

`SEC-5` **Les clés JWT de prod et de staging ne viennent pas de l'historique public : V1 non
confirmé** (2026-09-30, rien de changé dans le code) — deux paires de clés RSA ont été commitées
puis retirées, et restent lisibles dans l'historique du dépôt public : celle de
`backend/src/main/resources/` (`c0ac99fe`) et celle de dev (`7978afb1`) ; un parcours de tous les
`.pem` de l'historique, toutes branches, n'en trouve pas d'autre. Si la prod en avait été une
copie, n'importe qui aurait pu forger un jeton d'administrateur. Vérifié sur l'hôte en comparant
l'empreinte SHA-256 de la forme DER de chaque clé publique (tirée aussi de la clé privée, pour
vérifier la paire) : les clés de prod et de staging sont générées sur l'hôte par
`data/keys/generate-keys.sh`, distinctes l'une de l'autre et des deux clés publiées, et ce sont
bien celles que lisent les backends (`/mnt/keys/publicKey.pem` identique dans le conteneur et sur
l'hôte). Aucun `.pem` n'est plus suivi par git. **À ne pas défaire** : les deux clés publiées sont
compromises pour toujours — ne jamais les réemployer, pas même pour un environnement de test
exposé ; une nouvelle clé se génère, elle ne se copie pas d'un environnement à l'autre. Pas de
test automatisé (fait de l'hôte, hors dépôt).
