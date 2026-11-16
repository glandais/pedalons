---
id: OPS-9
title: "Copie à froid des données Valhalla : caduque"
status: done
done: 2026-10-17
---

## Livré

`OPS-9` **Copie à froid des données Valhalla : caduque** (close le 2026-10-17 avec `OPS-48`) —
l'entrée (copier une fois `~/shared/data/valhalla`, ~17 Go, vers l'hôte de sauvegarde, puis à
chaque changement d'extrait OSM) avait été retirée de `LEDGER_NEXT.md` le 11 octobre 2026 sans
arriver ici, alors qu'`OPERATIONS.md` la citait encore. Sans objet depuis que le routage n'est
plus hébergé : la section « Cold backup of the shared stack » est retirée, et la copie qui existe
peut-être sur l'hôte de sauvegarde est à supprimer avec `data/valhalla` (étape 4 de la bascule).
Les données du tileserver (`data/tileserver` : style et config) sont dans git, rien à copier.
