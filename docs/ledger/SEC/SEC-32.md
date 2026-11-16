---
id: SEC-32
title: "Les snapshots de sauvegarde hors d'atteinte de la production : V5"
status: done
done: 2026-09-30
---

## Livré

`SEC-32` **Les snapshots de sauvegarde hors d'atteinte de la production : V5** (2026-09-30,
contrat inchangé) — vérifié sur l'hôte de sauvegarde : la clé de la prod (`rrsync <root>`, sans
`-no-del`) écrivait les snapshots datés eux-mêmes, qui appartenaient au compte de sauvegarde ; un
root de prod compromis pouvait les effacer ou les réécrire, et un fichier réécrit en place l'était
dans tous les snapshots qui le partagent par hardlink. Choix de l'utilisateur : **dépôt et
promotion par root**. `backup.sh` ne pousse plus que dans `<root>/incoming/`, miroir mis à jour en
place (`COMPLETE`, qui porte désormais le nom du snapshot, retiré d'abord et écrit en dernier) ;
`backup-promote.sh`, dans la crontab root de l'hôte de sauvegarde toutes les 15 minutes, copie
`incoming/` en snapshot daté, hardlinké contre le précédent, `root:<compte>` en `0750`/`0440`,
vérifié par `SHA256SUMS`, renommé en place d'un bloc. La même clé lit toujours les snapshots
(restauration inchangée) mais ne peut plus ni les écrire, ni les effacer, ni les renommer, ni en
changer les droits, ni les hardlinker (`fs.protected_hardlinks`). **Au plus une promotion par
20 heures**, un nom postérieur au dernier snapshot et pas dans le futur : le nom vient de la prod
et la purge garde un nombre, si bien que sans plancher une prod compromise pousserait trente
snapshots en une nuit et ferait purger tous les vrais. Écarté : `fs.protected_hardlinks=0` avec un
verrouillage après coup (moins de code, mais une protection du noyau affaiblie sur un hôte à
plusieurs comptes) et `-no-del` seul (n'empêche pas la réécriture). Coût : une copie de plus du
magasin d'objets (`incoming/`, ~1,7 Go). **À ne pas défaire** : rien dans `<root>` hors
d'`incoming/` n'appartient au compte de sauvegarde ; ne pas lever le plancher de 20 heures ni
faire tourner la promotion depuis un fichier que la prod peut écrire. Vérifié sur l'hôte de
sauvegarde, dans un répertoire jetable, avec `rrsync` réel sous le compte de sauvegarde et les
fonctions de `_backup_common.sh` : deux promotions et le hardlink d'un objet inchangé, la liste et
la relecture de `restore.sh`, les refus (réécriture, `--inplace`, `--delete`, nouveau répertoire à
la racine), les noms forgés (`../../etc`, futur, antérieur), un dump altéré, la purge. Pas de test
automatisé (scripts d'exploitation).
