---
id: AUD-1
title: "Déploiement automatique (CD) depuis GitHub"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `AUD-1` | **Déploiement automatique (CD) depuis GitHub** (audit de février, I3, « Critique ») | Non (16 octobre 2026, relecture du ledger) : le déploiement reste lancé à la main par `scripts/deploy.sh` | Le « Critique » de février visait des images poussées à la main sans retour arrière : `AUD-2` a apporté le tag par commit et le rollback Swarm, `AUD-3` la suite e2e nocturne. Les cinq workflows (`ci.yml`, `codeql.yml`, `e2e.yml`, `karoo-release.yml`, `mobile-release.yml`) ne déploient rien, à dessein : les hôtes sont en Swarm mono-nœud sans registry, et un déploiement depuis la CI demanderait soit un runner auto-hébergé, écarté par `AUD-3` parce qu'il exécuterait le code d'une PR externe chez nous, soit une clé SSH de l'hôte dans les secrets GitHub. À rouvrir avec un registry et un second nœud, ou si les déploiements deviennent assez fréquents pour qu'un oubli coûte |
