---
id: AUD-30
title: "Aucune limite **CPU** dans les compose (la mémoire est bornée : `AUD-7`). À poser une fois les charges…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Thème | Audit | Gravité | Constat |
|---|---|---|---|---|
| `AUD-30` | Docker | I14 | Mineur | Aucune limite **CPU** dans les compose (la mémoire est bornée : `AUD-7`). À poser une fois les charges mesurées : une limite trop basse sur le backend rallonge le démarrage (Flyway, Magika) au-delà du `start_period`, et le JVM dimensionne ses threads de GC sur elle |
