---
id: MOB-37
title: "Les tests Patrol ne tournent qu'en local"
status: open
group: "Couverture e2e Patrol — ce que les tests ne couvrent pas encore"
verified: 2026-11-16
---

## Reste à faire

`MOB-37` **Les tests Patrol ne tournent qu'en local** — aucun workflow de `.github/` ne les
lance : `ci.yml` ne passe que les tests unitaires. Il faudrait un runner macOS (simulateur) ou un
émulateur Android, plus la stack e2e (`scripts/e2e.sh up`) dans le job. La piste la moins chère
est un émulateur Android sur `ubuntu-latest`, à côté de la stack : le pendant web (`AUD-3`,
`e2e.yml`) y tourne chaque nuit en environ 1 h, stack comprise, et `mobile-release.yml`
construit déjà l'APK sur GitHub Actions.
