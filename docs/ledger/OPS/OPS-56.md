---
id: OPS-56
title: "Vérifier en prod le plateau du heap après `OPS-55`"
status: open
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-56` **Vérifier en prod le plateau du heap après `OPS-55`** (scindé d'`OPS-55`) — une fois
vcyclist 6.12.0 et `pedalons.elevation.tile-cache-size=20` déployés (réglage retiré depuis par
`API-150`, qui sort les tuiles MNT du heap : plateau à remesurer une fois la prod passée), relever
`jvm_gc_live_data_size_bytes` après quelques recalculs HD : attendu autour de 400 MiB, contre
570 MiB avant (old gen de 820 MiB avec `BACKEND_MEMORY=2G`). Si `BackendHeapFull` ne sonne
plus, envisager de revenir à la limite par défaut. Reste ouvert aussi : le recalcul HD alloue
beaucoup d'objets éphémères (l'old gen a touché 835 MiB en local pendant le recalcul de
« Nantes – Houtkerque », pour 137 MiB vivants ensuite) ; à creuser seulement si un OOM revient.
**Relevé du 1er novembre 2026** (tâche de 21 h, 10 imports GPX ou recalculs HD) : le heap vivant
plafonne à 355–381 MiB, l'histogramme (`~/heap-histo/` sur le serveur) met la hausse sur
182 MB de `double[]`. Mais `ContainerNearMemoryLimit` a sonné de 15 h 20 à 15 h 42 UTC : working
set à 1,86 GiB sur 2 GiB, pour un heap engagé de 822 MiB (des déchets en attente du full GC),
253 MiB de non-heap et **≈ 620 MiB de RSS hors de tout ce que la JVM compte** — un heap plein
(1,2 GiB à 60 %) aurait fini en kill du cgroup, sans dump. Fait le même jour :
`JAVA_MAX_MEM_RATIO=50` dans le `.env` de prod (heap max 1 GiB), et
`JAVA_TOOL_OPTIONS=-XX:NativeMemoryTracking=summary` dans celui du staging (le `.env` est lu par
bash et par Swarm : pas d'espace dans une valeur, d'où `JAVA_TOOL_OPTIONS` plutôt que
`JAVA_OPTS_APPEND`). **Reste** : lire `jcmd 1 VM.native_memory summary` sur le staging après
un import GPX, et le comparer au `VmRSS` du processus — l'écart est ce que ni le heap ni NMT ne
voient (runtime ONNX de Magika, arènes malloc) ; au démarrage, 424 MiB de RSS pour 359 MiB
suivis. **Lu le même jour après un gros import GPX** : 811 MiB de RSS pour 568 MiB suivis ;
l'écart, ≈ 243 MiB, est dans 87 arènes malloc glibc (298 MiB de RSS ; hôte de 12 cœurs, jusqu'à
96 arènes), où alloue aussi le runtime ONNX de Magika. Refait avec `MALLOC_ARENA_MAX=2` : 701 MiB
de RSS pour 626 suivis, 2 arènes et 81 MiB, pic de 1 019 MiB contre 1 181. D'où
`MALLOC_ARENA_MAX=2` dans l'image (`application.properties`, commit `f7b21e5c`), déployée en
prod et en staging le 1er novembre ; le `.env` du staging est revenu à son état d'avant.
**Reste** : si `ContainerNearMemoryLimit` ne sonne plus pendant quelques jours, retirer
`JAVA_MAX_MEM_RATIO=50` du `.env` de la prod (le ratio commun de 60 laisse 820 MiB hors heap
sur 2 GiB, ce qui suffit maintenant).
Taille : XS.
