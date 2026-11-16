---
id: SEC-13
title: "Durcissement des workflows GitHub Actions — permissions minimales posées sur les quatre workflows d'alors…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Priorité (audit) | Audit | Sévérité | Constat |
|---|---|---|---|---|
| `SEC-13` | — | L11 | Faible | Durcissement des workflows GitHub Actions — permissions minimales posées sur les quatre workflows d'alors (`09c65ecd`, `e8fbc3be`, `8bf6fa9f` ; `karoo-release.yml` limite son seul job à `contents: write`), et sur le cinquième, `mobile-release.yml` (`80122a0d`, même limite) ; reste l'épinglage des actions par SHA, à commencer par les actions tierces des deux workflows qui décodent le keystore : `karoo-release.yml` et `mobile-release.yml` (`subosito/flutter-action`, `softprops/action-gh-release`). Le suivi `github-actions` de Dependabot tiendra les SHA à jour |
