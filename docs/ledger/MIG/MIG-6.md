---
id: MIG-6
title: "Données exportées mais non importées"
status: open
group: "Mise en production"
verified: 2026-11-16
---

## Reste à faire

`MIG-6` **Données exportées mais non importées** : la ville et le pays de l'équipe arrivent
dans l'instantané (`BiketeamSnapshot`) sans être utilisés (plan §13, décision 14) ; à
décider. Le fuseau de l'équipe (`API-60`), lui, est repris tel quel de biketeam depuis le
7 octobre 2026 (`BiketeamMigrationService`) : la ville et le pays n'ont plus cet usage. Les
tags de parcours, qui en faisaient partie, sont importés depuis le 1er octobre 2026
(`MIG-14`).
