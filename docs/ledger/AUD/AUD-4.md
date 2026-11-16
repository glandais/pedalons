---
id: AUD-4
title: "Même Node en CI que dans l'image"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-4` | CI/CD | I9 | Important | **Même Node en CI que dans l'image** (2026-09-30) — la CI installait Node 24, l'image du frontend tourne sur `node:26.9.0-alpine`. Le Dockerfile fait référence : `frontend/.nvmrc` porte `26.9.0`, et `ci.yml` le lit (`node-version-file`) au lieu d'une version en dur ; le Dockerfile rappelle de changer les deux ensemble (ses deux `FROM`). Pas de champ `engines` : il n'est lu nulle part en CI ni dans l'image, et ne ferait qu'avertir en poste de travail ; `packageManager` (`pnpm@11.20.0`) était déjà la seule source de pnpm, pour la CI (`pnpm/action-setup`) comme pour l'image (corepack). Pas de test : la CI elle-même, au prochain passage |
