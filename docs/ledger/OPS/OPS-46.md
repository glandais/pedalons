---
id: OPS-46
title: "(Optionnel) Alerte sur la taille du cache de tuiles du backend"
status: open
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-46` **(Optionnel) Alerte sur la taille du cache de tuiles du backend** — le
cache d'élévation IGN (`~/prod/data/cache/ign-lidar-hd-mnt/` et `ign-lidar-hd-mns/`) pesait
6,8 Go le 16 octobre 2026, trois semaines après `API-104`, et n'a ni plafond ni éviction ; la
veille manuelle d'`OPS-31` n'a rien trouvé d'alarmant (disque à 15 %), mais personne ne
regardera la prochaine fois. Une alerte Prometheus sur la taille du répertoire (ou un plafond
dans le code du cache) remplacerait cette veille. Depuis la phase E d'`API-150`, le backend
ne lit ni n'écrit plus ce cache, et le cache IGN d'osm-route-details est plafonné à 20 Go : une
fois la prod passée et les répertoires supprimés (`docs/OPERATIONS.md`), cette entrée va dans
« Délibérément dehors ». Taille : XS à S.
