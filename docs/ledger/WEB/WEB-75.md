---
id: WEB-75
title: "Hauteur de pluie écrite selon la langue"
status: done
done: 2026-11-12
---

## Livré

`WEB-75` **Hauteur de pluie écrite selon la langue** (12 novembre 2026, commit `088876724`, avec `WEB-167` et `API-102` ; contrat d'API inchangé) — la météo de départ écrivait « 2.3 mm » en français par un `toFixed(1)`. `DepartureWeather.tsx` passe par `useUnits().precipitation`, donc `formatPrecipitation` (`utils/unitFormat.ts`, `Intl.NumberFormat` sur la langue de l'interface). Test : `unitFormat.test.ts`.
