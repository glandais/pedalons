---
id: LEGAL-1
title: "Import biketeam et « pas de données de tiers » : sans objet"
status: done
done: 2026-09-29
---

## Livré

`LEGAL-1` **Import biketeam et « pas de données de tiers » : sans objet** (2026-09-29) — la
question (responsable du traitement, base légale, information des membres importés) portait sur
les comptes créés par l'import par dump. Il n'en reste aucun : staging et prod n'ont ni compte à
adresse factice `strava_`/`facebook_`/`google_` ni compte non vérifié, et `biketeam_migration_map`
n'y a aucune ligne `USER` (bases reparties de zéro depuis l'import, qui a été retiré par
`d93fd3af`). La migration en direct n'importe aucune personne ; la politique (§1 « Équipes venues
de Biketeam », §2) ne décrit plus que ce transfert d'équipe. Si une restauration antérieure ou
une nouvelle forme d'import ramenait des comptes de membres, la question se rouvre sous un nouvel
identifiant.
