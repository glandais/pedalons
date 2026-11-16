---
id: AUD-3
title: "La suite e2e tourne en CI"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-3` | CI/CD | — | — | **La suite e2e tourne en CI** (2026-09-30) — `.github/workflows/e2e.yml`, **la nuit sur develop** (02:17 UTC) **et à la main** (`workflow_dispatch`), jamais sur les PR : trop longue pour les bloquer, et un test intermittent (« signing up with an address that has an account » est déjà tombé sous charge) n'y bloque personne à tort. Runner GitHub hébergé (`ubuntu-latest`, gratuit sur un dépôt public, jetable : aucun accès à l'infra ni à la base locale) ; pas de runner auto-hébergé, qui exécuterait le code d'une PR externe chez nous. Le job construit les deux images (`scripts/e2e.sh build all`) et démarre la pile `tribly-e2e` par `scripts/e2e.sh up`, base vide, suite complète sur les deux projets, une relance par test (`retries` sous `CI`) ; rapport, traces et journaux de la pile en artefact sur échec (14 jours). **Aucun secret** : `.env.e2e` est jetable et commité, la paire JWT générée dans le job. **Aucun mail ne sort** : une première étape échoue si `.env.e2e` ne pointe pas le mailer sur `mailpit` ou si l'overlay ne donne plus `.env.e2e` seul au backend. Sans valhalla (17 Go de tuiles), `E2E_NO_ROUTING` fait écarter `gpx-planner.e2e.ts` par `playwright.config.ts` ; le fond de carte est déjà simulé par les tests. `.e2e/` est créé et cédé à l'UID 1000 avant `up` : le backend tourne en `PUID` 1000, pas l'utilisateur du runner. **Vu tourner** (relecture du 16 octobre 2026) : environ 1 h par nuit, sous le `timeout-minutes: 120` ; un échec isolé le 15 octobre est à lire comme un test intermittent. Pendant mobile : `MOB-37` |
