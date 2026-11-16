---
id: OPS-26
title: "Recette de la promotion des sauvegardes"
status: done
done: 2026-10-11
---

## Livré

`OPS-26` **Recette de la promotion des sauvegardes** (2026-10-11, `SEC-32`) — vérifiée a
posteriori sur dix nuits, sur l'hôte de sauvegarde : une ligne `promoting … (hard-linked against
<veille>)` puis `promoted <stamp>` chaque nuit à 01:30 UTC du 2 au 11 octobre, aucune `ERROR` ; le
plancher de 20 h n'a rien bloqué à tort. Le snapshot du 11 est `root:<backup-user>`, répertoires
`0750` et fichiers `0440` sans exception, `COMPLETE` au nom du snapshot. Hardlinks effectifs :
1 189 fichiers sur 1 197 ont plus d'un lien (jusqu'à 14), les 8 autres sont des objets nouveaux
ou les caches internes de MinIO ; chaque snapshot quotidien pèse 6 à 7 Mo en propre (26 Mo le 5,
jour d'ajout de photos), 4,4 Go pour les 30. La purge de 04:30 retire chaque nuit le plus ancien
et en garde 30. `restore.sh --list`, lancé en root depuis le checkout de la prod, liste les
mêmes 30 snapshots (du 18 septembre au 11 octobre), sans `incoming/`. Non lu :
`/var/log/backup/pedalons-backup.log` de la prod ; une promotion n'ayant lieu que sur un
`COMPLETE` écrit en dernier par `backup.sh`, les dix promotions attestent les dix envois. Pas de
test automatisé (recette sur l'hôte).
