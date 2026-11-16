---
id: AUD-28
title: "Code mort retiré de l'app Garmin"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-28` | Garmin | G11, G12 | Mineur | **Code mort retiré de l'app Garmin** (2026-09-30) — les quinze `System.println` commentés (`ApiClient.mc`, `AuthManager.mc`, `PedalonsApp.mc`) sont supprimés, et la chaîne `Back` des deux `strings.xml`, qu'aucun `Rez.Strings` ni layout ne lit (grep). `AM` et `PM` sont **gardées** alors qu'elles ne servent pas encore : `FormatUtils.mc` code `"AM"`/`"PM"` en dur, et la correction de G5 (`AUD-26`) consiste justement à lire ces deux ressources ; les retirer l'obligerait à les recréer. Ne pas les supprimer tant que `AUD-26` est ouvert. Pas de test : l'app n'en a pas ; `make build` (edge1040) passe |
