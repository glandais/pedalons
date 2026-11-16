---
id: OPS-10
title: "Cache gpx2web revu : partageable entre backends"
status: done
done: 2026-09-30
---

## Livré

`OPS-10` **Cache gpx2web revu : partageable entre backends** (2026-09-30) — lu dans gpx2web
1.5.2 (la version du dépôt) : `HttpTileFetcher` (tuiles d'élévation Mapterhorn) et
`TileMapProducer.downloadTile` (tuiles de carte) téléchargent chacun dans un fichier temporaire
**unique** du même répertoire (`Files.createTempFile`), ne le gardent que sur un 2xx et le
renomment en place (`ATOMIC_MOVE`, `REPLACE_EXISTING`) ; une tuile en cache illisible est effacée
et retéléchargée. Deux backends sur le même répertoire ne voient donc jamais de fichier partiel,
et le verrou interne à la JVM (`TileLruCache`, `synchronized`) n'évite qu'un double
téléchargement. Deux backends d'un même environnement partagent d'ailleurs déjà le répertoire
pendant un déploiement start-first. L'interdiction de `.env.example` et d'`OPERATIONS.md` est
levée ; **le cache reste par environnement**, partager entre environnements serait un choix
d'exploitation, pas fait. Condition à garder : un seul système de fichiers (le renommage n'est
atomique que là), et ne pas redescendre sous gpx2web 1.5.2. Pas de test (revue de code).
**Porté sur vcyclist** (migration gpx2web → vcyclist) : les tuiles d'élévation sont écrites dans
un fichier temporaire du répertoire cible puis renommées (`ATOMIC_MOVE`), et seulement une fois
décodées (`DemTileFetcher`, qui garde le layout de cache de gpx2web) ; les tuiles de carte le sont
aussi depuis vcyclist 5.1.0, qui supprime et retélécharge une entrée de cache illisible. Le rendu
des vignettes est en `MissingTilePolicy.FAIL` (`VcyclistProducer`) : une tuile introuvable fait
échouer la vignette, jamais un fond troué. vcyclist 5.1.1 range chaque tuile sous sa source
entière (hôte, port, chemin du style) : jusqu'en 5.1.0, la clé n'était que l'hôte, et les styles
clair et sombre partageaient leurs tuiles — ce que `MapThumbnailRendererTest` a révélé en suite
complète. La condition devient : ne pas redescendre sous vcyclist 5.1.1. Tests :
`DemTileFetcherTest`, `MapThumbnailRendererTest`.
