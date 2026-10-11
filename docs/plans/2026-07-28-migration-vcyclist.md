# Migrer le backend de gpx2web vers vcyclist

> **Exécuté le 28 juillet 2026.** Les 4 commits du §9 sont livrés : `ClimbData`/`ClimbPartData` +
> swap DTO/entités, `WindEstimator` + test de référence, le gros commit (pom, `VcyclistProducer`,
> `DemTileFetcher`, `GpxPipeline`, réécriture des 5 services, propagation de `sourceFile`), puis
> tests + docs/config. Contrat d'API inchangé par construction (§2), aucune migration Flyway. Les
> changements de comportement du §11 sont à surveiller après déploiement — repris dans
> `docs/NEXT.md`. Ce document garde son statut de plan de référence, pas archivé pour l'instant
> (décision utilisateur).
>
> **L'arbitrage 2 (`original.gpx` = octets uploadés verbatim) est annulé** au rebase sur `develop`
> du 29 septembre 2026 : ledger `API-44` avait entre-temps décidé qu'aucun fichier stocké ne sort
> sans que `GpxSanitizer` en ait retiré horodatages et capteurs. `computeGpx` nettoie le document en
> tête puis re-sérialise `original.gpx` depuis les paths bruts, fichier source ou pas ; le paramètre
> `sourceFile` et sa propagation (§5) ont disparu, et `GpxSanitizer` et `GpxSanitizationBackfill`
> sont portés sur le modèle vcyclist. Tout ce que ce plan dit de `sourceFile` est donc périmé.
>
> **La version livrée est vcyclist 5.0.0, résolue depuis Maven Central.** Tout ce que le §0 et le §9
> disent d'une 3.0.0 publiée dans `~/.m2` et malléable sans bump est donc périmé : la bibliothèque
> est publiée, le backend en est un consommateur ordinaire, et un manque côté vcyclist se corrige
> désormais par une release amont. Les ruptures 4.0.0 et 5.0.0 portent sur le moteur de simulation
> de puissance et la ligne de course, que le backend n'appelle pas ; la surface consommée ici
> (parsing GPX, élévation, cols, FIT, tuiles) compile telle quelle.
>
> **Passée ensuite à 6.0.1** (rebase sur develop, 11 octobre 2026). La 6.0.0 n'a qu'une rupture, sur
> `Climb` : un paramètre `climbingDistanceM` (longueur des segments de profil qui montent) s'insère
> avant `parts`, et `climbingGrade` le prend pour dénominateur au lieu de la longueur des parts
> montantes — il ne dépasse donc plus jamais `maxDiffRealGradeRatio`. `ClimbData.from` lit
> `getClimbingGrade()` et ne change pas ; seul `ClimbDataTest`, qui construit des `Climb`, suit.
> Le `climbingGrade` stocké diffère à la marge pour les parcours **réimportés**, comme la détection
> des cols. Le reste de la 6.0.0 (lissage d'élévation invariant au rééchantillonnage, antiméridien,
> points de départ alignés) et la 6.0.1 (rédacteurs GPX et FIT, cap et longitudes près de 180°)
> corrigent des cas limites sans changer d'API.

> Écrit le 28 juillet 2026. **Plan actif, non exécuté côté backend.** Le préalable amont `g32` est
> en revanche **fait et publié** : vcyclist `36b869e`, `PLAN-GPX2WEB.md` le marque ✅, et la
> **3.0.0 présente dans `~/.m2`** (publiée après ce commit) exporte déjà la fabrique. Il n'y a donc
> plus de §0 à exécuter et **la version cible est 3.0.0**, pas une 3.1.0 qui n'existe nulle part
> (dernier tag git : `v2.0.0`). Rien n'a encore bougé côté backend.
>
> **vcyclist reste malléable pendant la migration.** Rien n'est poussé sur `develop` amont : si un
> trou d'appelabilité apparaît en cours de route, on le corrige dans
> `/home/glandais/code/perso/vcyclist-all/vcyclist` et on **republie 3.0.0 en local**
> (`./gradlew publishToMavenLocal`) sans changer de numéro — le backend ne bouge pas. La montée de
> version et le push amont se décideront une fois la migration validée.

## Context

Le backend dépend de `io.github.glandais.gpx2web:gpx:1.4.4`, bibliothèque Java/CDI qui parse
les GPX, corrige l'élévation, détecte les cols et rend les vignettes carto. Elle est remplacée
par **vcyclist 3.0.0** (`io.github.glandais:vcyclist-*`, publiée **en local dans `~/.m2`**,
sources dans `/home/glandais/code/perso/vcyclist-all/vcyclist`) — une réécriture Kotlin
Multiplatform, pas un fork.

La 3.0.0 change la donne : ses **phases I et J** (`docs/PLAN-GPX2WEB.md`, fiches g21–g31) ont
été écrites en réponse à *« la première migration réelle d'un projet consommateur (appelant
**Java**) »*. Cinq des sept fiches de la phase I ne comblent pas un trou fonctionnel mais un
trou d'**appelabilité**. Concrètement :

| Friction | Fiche | Statut en 3.0.0 |
|---|---|---|
| Arguments par défaut invisibles depuis Java | g27 | Façades `…Jvm` (`@JvmOverloads`) sur toute l'API publique |
| `suspend` → `runBlocking` à la main | g22 | Ponts `…Blocking` / `…Async` (`Executor`, pas `CoroutineDispatcher`) |
| `<rte>`/`<rtept>` ignorés | g24 | Lus **et** écrits, `GpxPathKind`, inclus par défaut |
| `getWind` non porté | g26 + g31 | `dominantHeadwindDirection()` / `dominantHeadwindAzimuthDeg()` |
| FIT mono-`Path`, timestamps décalés de ~57 ans | g25 | Surcharge `List<Path>` + rebase sur `time(0)` |
| Drapeau `extensions` du writer | g23 | `writeExtensions: Boolean = true` |
| Téléchargement et décodage de tuile soudés | g21 | `fetchTileBytes` / `decodeTileBytes` séparés |

Il reste néanmoins une frontière à absorber : les `object` Kotlin remplacent les beans CDI, et
surtout **`Path` est immuable** (`DoubleArray` plats, chaque étape rend un nouveau `Path`) là où
`GPXPath` était muté sur place. Enfin les cols changent d'unités (**ratio** au lieu de %) et de
repère (distances de `ClimbPart` **absolues** au lieu de relatives).

Résultat visé : mêmes sorties API, mêmes lignes en base, dépendance à jour, cache DEM conservé.

### Arbitrages retenus

1. **Climbs JSONB** — on **fige la forme actuelle**. Records maison reprenant à l'identique les
   noms de champs et les unités de gpx2web ⇒ **aucune migration Flyway**, aucune ligne touchée,
   contrat OpenAPI inchangé.
2. ~~**`original.gpx`** — on stocke désormais **les octets uploadés verbatim** ; on ne re-sérialise
   que pour le chemin planificateur (points sans fichier source).~~ **Annulé** (ledger `API-44`,
   voir l'en-tête) : `original.gpx` est la re-sérialisation nettoyée des paths bruts.
3. **Cache DEM** — la fabrique amont g32 **existe déjà** (voir §0), il ne reste qu'un fetcher Java
   trivial côté backend. Le cache prod existant est réutilisé tel quel.
4. **`<rte>`** — la régression envisagée **n'a plus lieu d'être** : g24 les porte et
   `tracksAsPaths()` les inclut par défaut, comme le faisait `GPXFileReader:153`.

---

## 0. Préalable amont : `g32` — **fait, rien à exécuter**

> État vérifié le 28 juillet 2026 : vcyclist `36b869e`
> *« feat(elevation): accept a Java tile fetcher, so a disk cache can plug in (gpx2web task g32) »*,
> fiche `docs/tasks/g32-elevation-jvm-fetcher.md`, `PLAN-GPX2WEB.md` ✅. La 3.0.0 de `~/.m2` a été
> publiée **après** ce commit et `javap` sur `vcyclist-elevation-jvm-3.0.0.jar` montre bien les
> quatre `newElevationProvider`. Le backend n'attend donc rien de l'amont.

Ce que la migration consomme, tel que livré dans
`elevation/src/jvmMain/kotlin/io/github/glandais/elevation/ElevationProviderJvm.kt` :

```kotlin
fun newElevationProvider(fetcher: Function<String, RawTile>): ElevationProvider
fun newElevationProvider(config: ElevationProviderConfig, fetcher: Function<String, RawTile>): ElevationProvider
```

Deux propriétés livrées dont dépend le §3, à ne pas re-dériver :

- **Deux surcharges explicites, pas `@JvmOverloads`** — l'annotation retire les paramètres *de
  fin*, et ici le paramètre à défaut (`config`) vient en premier : elle aurait généré un
  `(config)` perdant le fetcher et entrant en collision avec la fabrique g27.
- **Le fetcher est invoqué sous `withContext(Dispatchers.IO)`**, jamais sur le thread appelant. Il
  a donc le droit de bloquer, mais **doit être thread-safe** : `BatchCalculator` tire jusqu'à 10
  tuiles en parallèle. C'est ce qui rend l'écriture atomique du §3 obligatoire, pas optionnelle.

> Alternative écartée à l'époque, mentionnée pour qu'on ne la réinvente pas : implémenter
> `Function2<String, Continuation<? super RawTile>, Object>` côté backend. Ça marche (une fonction
> suspend qui ne suspend jamais peut rendre sa valeur directement) mais ça repose sur un détail de
> la convention d'appel du compilateur Kotlin, dans le code d'un consommateur qui n'a aucune raison
> de le connaître.

**Si un autre trou d'appelabilité apparaît pendant la migration** : le corriger dans le dépôt
vcyclist local, `./gradlew publishToMavenLocal`, et **rester en 3.0.0**. Pas de bump, pas de push
amont tant que la migration n'est pas validée bout en bout — sinon le backend se met à courir après
un numéro de version pendant qu'on debug. Une fois validé, on décidera d'un coup du contenu de la
release publique.

---

## 1. `backend/pom.xml`

Remplacer `<gpx.version>1.4.4</gpx.version>` (l. 25) par `<vcyclist.version>3.0.0</vcyclist.version>`
— la version publiée dans `~/.m2`, g32 inclus. Ce numéro ne bouge pas de la migration, même si on
republie l'amont en cours de route (voir §0).

Supprimer le bloc `<!-- GPX Processing -->` (l. 128-139) — **l'exclusion `smile-core` disparaît**,
vcyclist n'en dépend pas. Ajouter, avec les **artefacts `-jvm`** (les artefacts racines sont des
`pom` à métadonnées Gradle, illisibles pour Maven seul) :

- `io.github.glandais:vcyclist-engine-jvm` — `api` `gpx-jvm` + `elevation-jvm` + `fit-jvm`, donc
  `Path`, I/O GPX, élévation, FIT et cols arrivent transitivement
- `io.github.glandais:vcyclist-map` — JVM pur, **pas** de suffixe `-jvm`, et **pas** une
  dépendance de `:engine` : à déclarer explicitement

Ne **pas** déclarer :

- `kotlin-stdlib` — déjà `compile` transitif (2.4.10). C'est lui qui fournit
  `kotlin.jvm.functions.Function2` et `kotlin.coroutines.Continuation`, dont on n'aura plus besoin.
- `kotlinx-coroutines-core-jvm` — `runtime` transitif (1.11.0), et **c'est suffisant** : les ponts
  `…Blocking`/`…Async` prennent un `java.util.concurrent.Executor` précisément pour garder les
  coroutines hors des signatures publiques. Le backend ne nomme jamais un type coroutines.
- `quarkus.index-dependency.*` — après §2, aucun type vcyclist n'est visible de Jandex (ni champ
  JPA/JSONB, ni DTO JAX-RS), et la bibliothèque ne porte aucune annotation.

`imageio-webp` (TwelveMonkeys) arrive en `runtime` via `vcyclist-elevation-jvm` — suffisant, notre
code ne touche que `javax.imageio.ImageIO` indirectement, via `TileFetcherJvm.decodeTileBytesBlocking`.

---

## 2. Records maison pour les cols — gel du contrat

Nouveaux `fr.pedalons.domain.route.ClimbData` / `ClimbPartData` (records `Serializable`), **champ
pour champ identiques** à `io.github.glandais.gpx.climb.Climb`/`ClimbPart` de gpx2web :

- `ClimbData(startDist, startEle, endDist, endEle, dist, elevation, positiveElevation, negativeElevation, grade, climbingGrade, List<ClimbPartData> parts)` — `grade`/`climbingGrade` en **%**
- `ClimbPartData(startDist, startEle, endDist, endEle, dist, ele, grade)` — distances **relatives**
  au début du col, `grade` en **%**

Les `Climbs`/`ClimbParts` de gpx2web sont des sous-classes d'`ArrayList` : elles sérialisent en
tableaux JSON nus, donc `List<ClimbData>` relit les documents existants tels quels.

**Un seul mapper convertit les unités** — `ClimbData.from(io.github.glandais.engine.climb.Climb)` :

- `getAverageGrade() * 100` et `getClimbingGrade() * 100` (ratio → %)
- par part : `getStartDistanceM() - climbStartDist` et `getEndDistanceM() - climbStartDist`
  (absolu → relatif), `getGrade() * 100`

Les `val` calculés Kotlin s'exposent en `getLengthM()`, `getElevationGainM()`, etc.

Consommateurs — **corps inchangés**, seuls imports et types bougent : `ClimbDto.java`,
`ClimbPartDto.java`, `TrackDto.java` (l. 11 + signature de `of`), `domain/route/GpxTrack.java`
(l. 46-47 → `List<ClimbData>`), `domain/gpx/GpxPreview.java`. `categorizeClimb` garde son
`avgGrade > 8.0`, `ClimbPartDto.from` garde son décalage `climbStartDist + part.startDist()`.
La sortie est identique par construction.

Pas de DDL, pas de Flyway, pas de bump de `pedalons.api.version`.

---

## 3. Couche d'adaptation (`fr.pedalons.infrastructure.gpx`)

`io.github.glandais.engine.path.Path` entre en collision avec `java.nio.file.Path`, et
`io.github.glandais.engine.gpx.GpxTrack`/`GpxWaypoint` avec les entités maison du même nom. On
isole donc le pipeline dans des classes qui n'importent jamais `java.nio.file`.

### `GpxPipeline` (`@ApplicationScoped`, `fr.pedalons.service.route`)

```java
Path p = PointPerDistance.INSTANCE.computeOnePointPerDistance(source, 0.5, 10.0);
try {
  p = ElevationStepJvm.fixElevationBlocking(p, elevationProvider);
  p = ElevationStepJvm.smoothElevation(p, 150.0);
} catch (Exception e) { LOG.warnf(e, "…, using original elevations"); }
return PathSimplifierJvm.simplify(p, 3.0, 3.0);
```

Chaque constante est **vérifiée contre la source gpx2web**, pas devinée :

- `0.5, 10.0` — `GPXPerDistance:25` jette les points à moins de **0,5 m**, `:28` densifie au-delà
  de `minDist`. `10.0, 10.0` supprimerait bien plus de points et raccourcirait toutes les routes.
- **`smoothElevation(p, 150.0)` est obligatoire** : `GPXElevationFixer.fixElevation` faisait
  `setEleOnPath` **puis** `smoothService.smoothEle(path, 150)`. `ElevationStep.fixElevation` ne
  fait que la première moitié. L'oublier change le D+ de toutes les routes.
- `simplify(p, 3.0, 3.0)` — `GPXFilter.TOLERANCE = 3.0` et `ele * 3` dans `geoToEcef`.

Détection : `ClimbDetectorJvm.detect(p)` (la façade g27 rend `ClimbOptions.DEFAULT` implicite),
puis `.stream().map(ClimbData::from).toList()`.

`ElevationStepJvm.fixElevationBlocking` est un `runBlocking { … }` **nu** — pas
`runBlocking(Dispatchers.IO)` : le saut sur `Dispatchers.IO` est dans l'adaptateur de fetcher de
g32, pas ici. Le thread appelant est donc bien parqué pendant toute la récupération d'élévation.
C'est sans conséquence parce que `GpxPipeline` tourne sous `@Transactional(NOT_SUPPORTED)` dans
`processGpxData` : aucune connexion DB n'est retenue pendant le blocage, propriété préservée.

### `VcyclistProducer` (`@ApplicationScoped`)

Produit les deux seuls objets à état, en `@Produces @Singleton`, en lisant
`@ConfigProperty("pedalons.data.cache")` :

```java
MapFactoriesJvm.tileMapProducer(cacheFolder)                              // fetcher HTTP par défaut
ElevationProviderJvm.newElevationProvider(
    ElevationProviderJvm.elevationProviderConfig(),                       // 12 / 100 / mapterhorn / 512
    new DemTileFetcher(cacheFolder))                                      // g32
```

Les 7 `@Inject` de bibliothèque de `GpxProcessingService` (l. 70-84), les 2 de `RouterService`
(l. 46-48) et celui de `ThumbnailService` (l. 48) disparaissent — ce sont des `object`.

**`infrastructure/cache/CacheFolderProviderImpl.java` est supprimé** (le SPI n'existe plus) ;
`pedalons.data.cache` n'est plus lu que par `VcyclistProducer`. `application.properties` inchangé
(`:220`, `:246`, `:332`, `tileserver.url`).

### `DemTileFetcher implements Function<String, RawTile>`

Grâce à g21 (séparation) et g32 (fabrique), c'est du Java ordinaire :

```java
public RawTile apply(String url) {
  File f = cacheFile(url);                       // {cache}/mapterhorn/{z}/{x}/{y}.webp
  byte[] bytes = (f.isFile() && f.length() > 0)
      ? Files.readAllBytes(f.toPath())
      : TileFetcherJvm.fetchTileBytesBlocking(url);
  RawTile tile = TileFetcherJvm.decodeTileBytesBlocking(bytes, url);
  if (!f.isFile()) storeAtomically(f, bytes);    // seulement après décodage réussi
  return tile;
}
```

Trois propriétés voulues :

1. **Même layout que gpx2web** (`{cache}/mapterhorn/{z}/{x}/{y}.webp`) — `z`/`x`/`y` extraits des
   trois derniers segments de l'URL. Le cache prod existant est réutilisé sans refill, et
   `MIGRATE_BIKETEAM.md:9` reste vrai pour l'élévation.
2. **Corrige le défaut documenté dans `README.md:202`** : gpx2web streamait la réponse directement
   dans le fichier final (`BodyHandlers.ofFile`), donc un crash cachait un fichier tronqué pour
   toujours. Ici : `Files.createTempFile` dans le même répertoire puis
   `Files.move(tmp, target, ATOMIC_MOVE, REPLACE_EXISTING)`, et **on décode avant de stocker** —
   une page d'erreur ne devient jamais une tuile.
3. Le LRU mémoire de `TileManager` (`cacheSize = 100`) reste devant le cache disque — c'est la
   superposition souhaitée.

---

## 4. `WindEstimator` — brancher `dominantHeadwindDirection`

g26 porte `GPXDataComputer.getWind` en `Path.dominantHeadwindDirection()` /
`List<Path>.dominantHeadwindDirection()` (`engine/…/path/PathWind.kt`, module `:engine`, pas de
façade `…Jvm` ⇒ depuis Java : `PathWindKt.dominantHeadwindDirection(paths)`).

**Attention au repère.** Le retour est un `Vector3D` unitaire en repère **est-nord local**
(`x` = est, `y` = **nord**, `z` = 0), ou `null` (moins de 4 points — le seuil `size > 3` de
gpx2web — ou aller-retour symétrique dont la moyenne s'annule). gpx2web projetait en pixels Web
Mercator zoom 12 où **`y` pointe vers le sud** (`Point.project()` → `MagicPower2MapSpace.INSTANCE_256`).
C'est exactement pour ça que `findDirectionFromVector` porte son `y1 = Math.sin(angle) * -1`.

Donc `GpxProcessingService.findDirectionFromVector` **garde son corps verbatim** et on lui passe
le vecteur ramené dans l'ancien repère :

```java
Vector3D v = PathWindKt.dominantHeadwindDirection(processed);
WindDirection wd = v == null ? null : findDirectionFromVector(v.getX(), -v.getY());
```

Deux pièges à ne pas « corriger » :

- Le `.sorted(…).findFirst()` retient le score le **plus bas**. Ça ressemble à un bug, c'est le
  comportement livré ; l'inverser retournerait la direction de vent de toutes les routes.
- `dominantHeadwindAzimuthDeg()` (g31) donnerait un azimut compas directement exploitable et
  supprimerait ce code — mais c'est un changement de comportement, pas une migration. À noter
  dans `docs/NEXT.md`, pas à faire ici.

Le cas `null` doit être traité explicitement : `WindDirection` est déjà `@Nullable` dans
`TrackMetadata`, donc c'est une simple garde.

---

## 5. Réécriture de `GpxProcessingService`

Type d'échange : `GPX` → `io.github.glandais.engine.gpx.GpxDocument`.

**`parseGpx(java.nio.file.Path)`** : `Files.readString(path, UTF_8)` puis
`GpxParserJvm.parse(xml)` (la façade g27 rend `repairOnFailure = true` implicite). Le parser ne
prend qu'une `String` : prévoir un repli ISO-8859-1 sur `MalformedInputException`, les GPX hérités
de biketeam le sont souvent, et l'ancien parser sur `InputStream` l'encaissait.

**`fromPoints`** : `GpxModelJvm.trackPoint(lat, lng)` → `GpxModelJvm.track(points, name)` →
`GpxModelJvm.document(tracks, name)`.

**`computeGpx(GpxDocument doc, @Nullable java.nio.file.Path sourceFile)`** — et ce second paramètre
**ne s'arrête pas à cette signature** : aucun appelant actuel n'a le fichier source en scope, il
faut le faire descendre depuis les points d'entrée. C'est la vraie surface de l'arbitrage 2, à
faire d'un bloc dans le commit 3 :

| Signature | Aujourd'hui | Après |
|---|---|---|
| `GpxProcessingService.processGpxData` (`:276`) | `(Route, GPX)` | `(Route, GpxDocument, @Nullable Path sourceFile)` |
| `GpxPreviewService.create` (`:116`) | `(GPX, String)` | `(GpxDocument, String, @Nullable Path sourceFile)` |
| `GpxPreviewService.update` (`:190`) | — | passe son `gpxPath` déjà présent (`:199`) |
| `RouteService` (`:286`, `:354`) | `processGpxData(route, gpx)` | `processGpxData(route, gpx, gpxPath)` |

Le `gpxPath` est déjà un **paramètre de méthode** aux quatre endroits (`RouteService:255` et
`:322`, `GpxPreviewService:107` et `:190`) — c'est du passage de paramètre, pas de la remontée
d'état. Les
deux chemins `fromPoints` passent `null` et retombent sur la re-sérialisation. `create(Path, String)`
(`:107`) devient le seul endroit qui sait ouvrir un fichier : il parse **et** transmet le chemin.

Bénéfice de bord, gratuit : la promotion preview → route (`GpxPreviewService.createRoute:302`)
re-télécharge déjà l'`original.gpx` du preview et le passe à `RouteService.createRoute` — la route
héritera donc des **mêmes octets** que le preview dont elle est issue, au lieu d'une seconde
re-sérialisation. À vérifier en recette (§10.7).

Étapes :

1. `List<Path> raw = GpxToPathKt.tracksAsPaths(doc, EnumSet.allOf(GpxPathKind.class))` — un `Path`
   par `<trk>` **et par `<rte>`**, comme `GPXFileReader:153`. Pas de façade `…Jvm` pour cette
   fonction, donc le `Set` est explicite. `raw.isEmpty()` → `ErrorCode.GPX_EMPTY`.
   **Ne pas se laisser retourner par le KDoc de `segmentsAsPaths`**, qui se présente comme « la
   forme que gpx2web produit nativement » : `GPXFileReader.processElement` ne crée un `GPXPath` que
   sur `<trk>`/`<rte>` et y concatène tous les `<trkpt>`, segments confondus. C'est bien
   `tracksAsPaths` l'équivalent ; `segmentsAsPaths` découperait les routes multi-segments.
2. **`original.gpx`** : si `sourceFile != null` on **copie les octets uploadés verbatim**
   (arbitrage 2) ; sinon (chemin planificateur) `GpxWriterJvm.write(raw, name, trackNames)`, qui
   rend une **`String`** qu'on écrit soi-même.
3. Pipeline : `processed.add(pipeline.process(raw.get(i), trackNames.get(i)))` — chaque étape rend
   un nouveau `Path`, rien n'est muté.
4. **`filtered.gpx`** : `GpxWriterJvm.write(processed, name, trackNames, doc.getWaypoints())`.
5. **`fit`** : §6.
6. Par track : `toLineString`, `toTrackPoints`, `extractMetadata`, `pipeline.climbs`.
7. Vent : §4, sur `processed`.

**L'ordonnancement cesse d'être une règle à retenir** : `original` vient de la source ou de `raw`,
`filtered` de `processed`. Le javadoc l. 167-170 (« The GPX object is mutated in place… ») doit
être réécrit, et le test homonyme renommé (§8).

Le booléen `filtered` de `writeGPX(gpx, file, boolean)` était en fait le drapeau *extensions*
(`GPXFileWriter.java:75`) ; il correspond désormais à `writeExtensions` (g23), qu'on laisse à son
défaut `true` dans les deux cas. Les deux fichiers diffèrent toujours (rééchantillonnage +
élévation + simplification).

**`ComputedGpx` gagne `File fitFile`** et le supprime dans `close()`. C'est forcé par la
migration : aujourd'hui `processGpxData:306` et `GpxPreviewService.uploadFit:467` écrivent le FIT
depuis le `gpx` *muté*, donc depuis la géométrie filtrée ; avec des `Path` immuables le
`GpxDocument` brut ne porte plus la sortie du pipeline. `ComputedTrack.climbs` → `List<ClimbData>` ;
**ne pas** y ajouter de champ `Path` (ça re-fuiterait le type bibliothèque dans `GpxPreviewService`).

**Accesseurs par point** : `p.getSize()`, `p.latitudeDeg(i)`, `p.longitudeDeg(i)` (le stockage est
en radians, ces helpers convertissent), `p.elevation(i)`, `p.distance(i)` ; agrégats
`p.getTotalDistance()`, `p.getElevationGain()`, `p.getElevationLoss()` (déjà ≤ 0, même signe que
`getTotalElevationNegative()` — la colonne et l'assertion `elevationLoss <= 0` du test restent
valides). Waypoints : `w.getLatitudeDeg()` / `w.getLongitudeDeg()`.
Ne pas utiliser `forEachPoint {}` (fonction `inline`, inappelable depuis Java) — boucle `for`.

---

## 6. Export FIT

g25 apporte la surcharge `List<Path>` et **rebase les timestamps sur `time(0)` de chaque path**,
ce qui supprime le piège majeur de la 2.0.0 (`startTime + time(i)` datait un path issu d'un GPX,
qui porte des ms epoch, ~57 ans dans le futur). Donc :

```java
byte[] bytes = PathToFitJvm.toFitBytes(processed, name, startTime);   // sport + interPathGapMs par défaut
```

`startTime` reste **obligatoire** (« FIT n'a pas d'horloge relative, il faut bien que quelqu'un
tranche »). Choix à reproduire à l'identique : `t0 = processed.get(0).time(0)` puis
`Instant.Companion.fromEpochMilliseconds((long) t0)`. Pour une route sans temps `t0 == 0` →
`1970-01-01T00:00:00Z`, ce que gpx2web produisait déjà (`p.setInstant(null, Instant.EPOCH)`,
`GpxProcessingService:118`). **Ne plus rebaser soi-même** : g25 le fait, et le faire deux fois
écraserait les horodatages.

`interPathGapMs = 0` (défaut) enchaîne les paths, comme la boucle sur `gpx.paths()` de
`FitFileWriter`. Nouvelles préconditions à respecter : liste non vide, aucun `Path` vide, **temps
monotone** (sinon `IllegalArgumentException`) — filtrer les paths de taille 0 avant l'appel.

---

## 7. Autres services

**`RouterService`** — `toGpxPath` devient `toPath` : construire des `LatLonElevation(lat, lon, ele)`
(`io.github.glandais.elevation`), puis `Path.Companion.fromCoordinates(coords)` **suivi de
`computeDerivedData()`** (la factory ne l'appelle pas, et `PointPerDistance` lit `distance(i)`).
Ensuite **appeler `gpxPipeline.process(path, "route")`** plutôt que de redupliquer les trois étapes
des l. 84-97 : c'est exactement la même séquence 10 m / élévation / DP-3, et la mutualisation
empêche les deux de diverger. `toLineString3D` lit `longitudeDeg`/`latitudeDeg`/`elevation` ;
métriques `getTotalDistance()` / `getElevationGain()`. Pas de collision `java.nio.file.Path` ici.

**`ThumbnailService`** — `buildPaths` rend `List<io.github.glandais.engine.path.Path>` via
`Path.Companion.fromCoordinates` + `computeDerivedData()`, et devient **`public static`** pour que
`GpxProcessingService.generateThumbnailAsset` la réutilise. Les wrappers
`new GPX("thumbnail", paths, List.of())` (l. 124, 145) disparaissent : `createTileMap` prend
directement `List<Path>`. Les deux appels deviennent

```java
tileMapProducer.createTileMap(file, paths, tileUrl, 0.1, null, 512, 512, null, ROUTE_COLORS);
```

Exactement **un** de `maxSize` / (`width`+`height`) / `zoom` doit être non-null ; l'ancienne
signature `(…, 0.1, 512, 512)` était la variante width+height. Se tromper lève une
`IllegalArgumentException` — et comme la vignette est best-effort, elle serait avalée
silencieusement. `ROUTE_COLORS` est déjà un `List<java.awt.Color>`, inchangé.

**`GpxProcessingService.generateThumbnailAsset`** — reconstruire les paths depuis
`computed.tracks()` avec `ThumbnailService.buildPaths(…)` au lieu du `new GPX(...)` de la l. 311.

**`GpxPreviewService`** — `GPX` → `GpxDocument`, `gpx.name()` → `gpx.getName()` (non-null, défaut
`"noname"` : traiter aussi `"noname"` comme déclencheur du fallback) ; l'injection `FitFileWriter`
et la méthode privée `uploadFit` disparaissent au profit de
`upload(publicId, FIT, computed.fitFile(), FIT_CONTENT_TYPE)`. **Plus le paramètre `sourceFile`**
sur `create` et sur le chemin update (§5) : `create(Path, String)` (`:107`) transmet son propre
`gpxPath`, `update` (`:190`) le sien, les chemins `fromPoints` passent `null`.

**`RouteService`** — swap d'import l. 41 et des deux déclarations locales (l. 278, 334), **et les
deux appels `processGpxData(route, gpx)` (`:286`, `:354`) reçoivent le `gpxPath`** déjà paramètre
de `createRoute` (`:255`) et `updateRoute` (`:322`). C'est le seul changement de fond ici ; le reste
est mécanique.

---

## 8. Tests et documentation

**Tests existants**

- `test/util/TestDataService.java` — `new Climbs()` → `List.<ClimbData>of()` (**4** occurrences :
  l. 448, 482, 515, 556).
- `test/service/route/GpxProcessingServiceTest.java` — `GPX` → `GpxDocument`, assertions
  conservées. **Renommer**
  `computeGpx_shouldSerializeOriginalBeforeAndFilteredAfterTheMutatingPipeline` (le pipeline ne
  mute plus rien) et étendre `computeGpx_shouldDeleteTempFilesOnClose` au `fitFile()`.

**Tests à ajouter** — ce sont les seuls endroits sans filet :

- `ClimbDataTest` : désérialiser une chaîne JSON copiée telle quelle d'une ligne
  `gpx_tracks.climbs` de prod et vérifier la sortie de `ClimbDto.from`. C'est ce qui verrouille
  l'arbitrage 1.
- `ClimbData.from(Climb)` : le `×100` et le rebase absolu → relatif.
- `WindEstimatorTest` : valeurs de référence capturées depuis gpx2web **avant** le swap, pour
  verrouiller le `-v.getY()` du §4.
- `DemTileFetcherTest` : hit disque sans requête sortante, et rien de stocké quand le décodage échoue.

> `backend/CLAUDE.md` : **ne jamais lancer les tests backend soi-même** — fournir les commandes.

**Docs / config** (`gpx2web` → `vcyclist`) : `backend/README.md:12`, `.env.example:38,42`,
`docker-compose.yml:53`, `.gitignore:74`, `MIGRATE_BIKETEAM.md:9`.
`README.md:202` est à **réécrire, pas renommer** : le défaut write-then-rename est corrigé par
`DemTileFetcher`, ne pas répéter une faille qui n'existe plus.

---

## 9. Découpage en commits

**Amont (dépôt vcyclist)** — rien à faire, g32 est livré et 3.0.0 est publiée (§0). Si un correctif
amont s'avère nécessaire : commit dans vcyclist + `publishToMavenLocal`, toujours en 3.0.0, et
**noter le correctif ici** — sinon la prochaine `publishToMavenLocal` depuis un dépôt propre
retirerait silencieusement du backend une fonction dont il dépend.

> **Correctif amont livré : `g33`**, après coup, sur la branche vcyclist `feat/g33-jvm-facade-gaps`
> (commit `633a667`, fiche `docs/tasks/g33-jvm-facade-gaps.md`). **Non poussé.** Le backend en
> dépend désormais : `PathWindJvm`, `GpxToPathJvm`, `PathJvm.fromCoordinates`, les surcharges
> millisecondes de `PathToFitJvm`, et `Path.withoutTime()`. Deux conséquences opérationnelles :
>
> - `Path.fromCoordinates` **appelle maintenant `computeDerivedData()`** — le backend ne le fait
>   plus lui-même, aux trois endroits concernés. Repartir d'un vcyclist sans g33 ne casserait pas
>   la compilation ici, ça effondrerait les traces silencieusement.
> - **Republier avec `./gradlew -Pversion=3.0.0 publishToMavenLocal`**, pas `publishToMavenLocal`
>   nu : `gradle.properties` porte encore `2.0.0` (la dernière release), donc la commande simple
>   publierait une 2.0.0 et laisserait la 3.0.0 dont dépend ce backend telle quelle.
>
> Le contenu de la release publique reste à décider une fois la migration validée bout en bout.

**Backend :**

1. `ClimbData`/`ClimbPartData` + swap DTO/entités, **encore mappés depuis le `Climb` gpx2web**.
   Prouve que le contrat est gelé pendant que l'ancienne lib est en place (diff OpenAPI vide).
2. `WindEstimator` + test de référence, **à côté** de `GPXDataComputer`. Verrouille le repère.
3. Le gros commit : pom, `VcyclistProducer`, `DemTileFetcher`, `GpxPipeline`, réécriture des
   5 services, **propagation de `sourceFile` sur les 4 signatures du tableau §5**, suppression de
   `CacheFolderProviderImpl`. Ne se coupe pas en deux (ne compile pas à moitié).
4. Tests + docs/config.

`./format.sh backend` avant chaque commit, sortie incluse dans le commit.

---

## 10. Vérification

```bash
# 0. la 3.0.0 locale porte bien g32 (à refaire après toute republication amont)
javap -classpath ~/.m2/repository/io/github/glandais/vcyclist-elevation-jvm/3.0.0/vcyclist-elevation-jvm-3.0.0.jar \
  io.github.glandais.elevation.ElevationProviderJvm | grep 'newElevationProvider.*Function'

# 1. la dépendance résout et le contrat ne bouge pas
cd backend && mvn -q package -DskipTests
git diff --exit-code contracts/openapi.yaml     # doit être vide (sinon §2 est faux)
mvn dependency:tree | grep -E 'vcyclist|kotlin'  # coroutines doit rester en runtime

# 2. tests backend — À LANCER PAR L'UTILISATEUR
mvn test -Dtest='GpxProcessingServiceTest,ClimbDataTest,WindEstimatorTest,DemTileFetcherTest'
```

**Bout en bout, sur la stack locale** (`./build.sh` + `docker compose` racine, 127.0.0.1:8090) :

1. Uploader un GPX d'activité réel via la page outils GPX : `original.gpx` et `filtered.gpx` sans
   aucun `<time>` ni `<extensions>` (ledger `API-44`), `filtered.gpx` plus léger, vignette rendue,
   `.fit` importable et daté de l'epoch FIT (1989-12-31) — ni la date de la sortie, ni 2106 (le
   débordement d'un départ à l'epoch Unix), ni le piège des 57 ans.
2. Uploader un GPX **`<rte>` uniquement** — doit fonctionner (g24), là où la 2.0.0 aurait renvoyé
   `GPX_EMPTY`.
3. Comparer distance / D+ / D− / cols / direction de vent avec la même route importée avant
   migration : les cols peuvent bouger un peu (§11), le vent **ne doit pas**.
4. Vérifier que `${DATA_CACHE_PATH}/mapterhorn/{z}/{x}/{y}.webp` se remplit, et qu'un second import
   de la même zone ne fait aucune requête sortante.
5. Rouvrir une route **existante** (non réimportée) : ses cols doivent s'afficher inchangés — c'est
   l'arbitrage 1 en conditions réelles.
6. Créer une route via le planificateur (chemin `fromPoints`, sans fichier source).
7. **Promouvoir un preview en route** (`GpxPreviewService.createRoute`) : l'`original.gpx` de la
   route doit porter la même géométrie que celui du preview — c'en est la re-sérialisation, plus
   une copie depuis l'annulation de l'arbitrage 2.

---

## 11. Changements de comportement à annoncer

1. **Détection de cols légèrement différente** sur certaines routes : `ClimbOptions.maxAnalysisPoints = 3000`
   décime l'analyse sur les longues traces (gpx2web n'avait pas de borne) et le découpage
   Douglas-Peucker est une implémentation équivalente mais pas identique. **Seules les routes
   nouvellement importées changent** — l'existant est intact (§2).
2. **Direction de vent : écart possible d'un secteur** sur des routes limites.
   `dominantHeadwindDirection` projette en équirectangulaire local (`Δlon·cos(lat₀)`, `Δlat`) là où
   gpx2web projetait en Mercator, dont l'échelle en `y` varie avec la latitude. Les directions
   concordent (le test `PathWindTest` amont recoupe l'azimut contre une implémentation Mercator
   littérale) mais les composantes normalisées point à point diffèrent légèrement. D'où le test de
   référence du §8.
3. **Cache de tuiles carto refait une fois** : le layout passe à `{host}/{z}/{x}/{y}.png`. Les
   tuiles d'**élévation** sont conservées. Les anciennes tuiles carto deviennent des octets morts
   à supprimer à la main.
4. **Octets FIT différents** : vcyclist écrit un `LapMesg` + une paire `EventMesg` `TIMER START/STOP`
   par path, et un `FitLap` plus riche (altitude min/max, vitesse max, positions début/fin).
   Fonctionnellement OK sur Garmin/Strava, mais tout test golden-file sur `.fit` échouera.
5. **Récupération d'élévation concurrente** (10 tuiles en parallèle via `Dispatchers.IO`) là où
   gpx2web était `synchronized` et strictement séquentiel. Plus rapide, mais ×10 sur le débit vers
   `tiles.mapterhorn.com` à cache froid — à surveiller après déploiement.
6. **`kotlin-stdlib` + coroutines** arrivent dans l'image (~2 Mo) et deviennent un nouvel axe de
   mise à jour.
7. **Gain** : les GPX `<rte>`-only, jusqu'ici traités par gpx2web puis menacés par la 2.0.0,
   continuent de fonctionner (g24).
