---
id: API-56
title: "Les formes dépréciées d'`API-45` retirées"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-01
---

## Livré

`API-56` **Les formes dépréciées d'`API-45` retirées** (2026-10-01, **API 10.0.0**, majeure) —
`DELETE /api/push-devices/{token}` (`unregisterPushDeviceByPath`) et `GET
/api/export/download/{token}` (`downloadDataExportByPath`) ne sont plus servies : plus aucun
jeton dans un chemin d'URL. Retirées une fois la nouvelle app mobile déployée et sans export en
attente de téléchargement (confirmé par le mainteneur). Clients web et mobile régénérés ; aucun
appel manuscrit ne les utilisait (le web et le mobile passaient déjà par les formes d'`API-45`,
karoo et garmin-app ne les connaissent pas). Tests : `PushDeviceResourceTest
.unregisteringThroughTheFormerPath_isNotServed` (404/405, l'appareil reste enregistré) et
`UserExportResourceTest.download_throughTheFormerPath_isNotServed` (404), lancés le 1er octobre
avec `UserExportServiceTest` (39 tests verts) ; `mobile/check.sh` (698 tests). **À ne pas
défaire** : ne pas rétablir de jeton dans un chemin, même « déprécié » — le masquage du journal
d'accès ne porte que sur les paramètres de requête.
