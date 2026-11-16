---
id: SEC-21
title: "Deux points informationnels de l'audit corrigés"
status: done
done: 2026-09-30
---

## Livré

`SEC-21` **Deux points informationnels de l'audit corrigés** (2026-09-30, scindé de `SEC-14`,
qui garde les images externes) — le `DocumentBuilderFactory` de `GarminCourseConverter` refuse
tout DOCTYPE (donc toute entité externe), sans XInclude ni expansion d'entités : l'entrée est un
GPX que nous écrivons, qui n'en a pas ; et `DeviceVerifyPage` encode le code saisi
(`encodeURIComponent`). Couvert par `flow-device.e2e.ts` (passé) pour le second ; pas de test du
premier (l'envoi vers Garmin n'est pas exercé en e2e).
