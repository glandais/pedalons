---
id: OPS-27
title: "Check Healthchecks de la promotion des sauvegardes"
status: done
done: 2026-10-11
---

## Livré

`OPS-27` **Check Healthchecks de la promotion des sauvegardes** (2026-10-11, `SEC-32`) —
`backup-promote.sh` savait pinguer, mais `/etc/default/pedalons-backup-promote` n'existait pas :
une nuit sans promotion, ou une promotion refusée, ne prévenait personne, le check de `backup.sh`
restant vert. Check quotidien créé (période 1 jour, grâce 2 h), son URL mise dans ce fichier sur
l'hôte de sauvegarde (`root:root`, `0600`), ping manuel depuis l'hôte → `OK`, check au vert ; le
script relancé à la main avec ce fichier sort en 0 sans ping (rien à promouvoir). La promotion
tourne vers 01:30 UTC ; le premier ping d'une vraie promotion est celui du 12 octobre. Pas de
test automatisé (recette sur l'hôte).
