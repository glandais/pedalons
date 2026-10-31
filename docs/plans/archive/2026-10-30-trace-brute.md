# Conserver en base la trace brute d'un parcours — plan

Écrit le 30 octobre 2026. **État : phases A, B, C (serveur, contrat API 13.1.0 et web) et D livrées le 30 octobre
2026.** Ledger `API-147` (dans `LEDGER_DONE.md`).

Le besoin : garder, pendant toute la vie d'un parcours, sa géométrie **telle que sa source l'a
produite** — en 2D, sans altitude, ni rééchantillonnée ni passée au Douglas-Peucker (par exemple le
tracé exact que le routeur renvoie entre deux points). Son premier usage : un meilleur rapprochement
avec OSM, c'est-à-dire le calcul des surfaces (`TraceSurfaceComputer`, Stadia `map_snap`).

L'état décrit ici a été vérifié dans le code le 30 octobre 2026 (`develop`, `2e52fed9`).

---

## 1. Où la trace brute se perd aujourd'hui

`GpxPipeline.processReported` rééchantillonne (5–10 m), corrige et lisse les altitudes, puis
simplifie (`PathSimplifierJvm.simplify(p, 3.0, 3.0)`) : environ un point tous les 90 m. C'est la
seule géométrie qu'écrit `gpx_tracks` (`geometry`, `track_points`).

| Entrée | Brut disponible ? | Où il disparaît |
|---|---|---|
| Envoi d'un fichier GPX, migration biketeam | Oui, en S3 : `original.gpx` (le parse assaini des tracks, `GpxProcessingService.computeGpx`) | Jamais en base |
| Calcul d'itinéraire du planificateur | **Non** | `RouterService.getRoute` passe la forme Valhalla (`leg.shape`) au pipeline avant de répondre : le client ne voit que la ligne simplifiée |
| Import d'un fichier dans l'éditeur | **Non** | `GpxImportService` renvoie les sources via `processWithClimb` (simplifiées) |
| Enregistrement depuis le planificateur (parcours, aperçu) | **Non** | `PlannerStates.validateAndDerive` concatène les `line` des pièces (déjà simplifiées) → `fromPoints` : l'`original.gpx` d'un parcours dessiné est **déjà** simplifié |
| Rattrapage HD (`ElevationRefreshService` → `recomputeHd`) | relit `original.gpx` | ne change pas le 2D source |
| Promotion d'un aperçu de l'outil GPX | copie l'`original.gpx` de l'aperçu | idem |
| Surfaces (`SurfaceRefreshService.readRoute`) | — | envoie `track_points` (~90 m) à Stadia : des sommets espacés se raccrochent mal aux carrefours |

Conséquence : pour un fichier envoyé, le brut existe (en S3) et il suffit de le poser en base ; pour
un parcours dessiné, il faut que le brut **traverse le planificateur** (routeur → client → état →
enregistrement), ce qui touche le contrat et le web — l'app mobile n'a pas de planificateur
(aucun `PlannerState` dans `mobile/lib`, vérifié le 30 octobre 2026) : elle ne fait que recevoir
les champs ajoutés dans son client généré.

## 2. La cible

- **Colonne** `gpx_tracks.raw_geometry geometry(LineString, 4326)`, 2D, nullable, chargée en lazy
  dans un groupe à elle (`@LazyGroup("raw")`, comme `surfaces`) : jamais lue par une liste, jamais
  exposée par l'API. Pas d'index spatial tant qu'aucune requête spatiale ne la lit.
- Côté aperçus : une colonne `gpx_previews.raw_lines` (JSONB, une polyline6 par piste) qui porte le
  `files_revision` qu'elle décrit, comme `surfaces`. Pas un champ de `PreviewTrack` : la version
  précédente lit `tracks` avec un lecteur JSON qui refuse les propriétés inconnues, ce qui casse le
  déploiement roulant.
- **Invariant** : `raw_geometry` décrit la même trace que `geometry` — elle est réécrite à chaque
  enregistrement qui remplace la trace, jamais par ce qui ne change que les altitudes (rattrapage HD)
  ou les métadonnées. Nulle veut dire « pas connue » (ligne antérieure non rattrapée) : tout lecteur
  retombe alors sur `track_points`.
- **Taille** : une forme Valhalla de 200 km compte de l'ordre de 10 à 25 000 sommets, soit
  160 à 400 Ko en 2D ; un GPX enregistré à la seconde peut aller plus loin (borné par
  `MAX_GPX_SIZE_BYTES`). TOAST compresse peu une géométrie (16 octets par point en 2D).
  **Mesuré en prod le 30 octobre 2026** (lecture seule) : 6 078 pistes, 6 078 parcours dont 5
  dessinés ; `gpx_tracks` 263 Mo (TOAST 250 Mo : `geometry` 66 Mo, `track_points` 162 Mo) ; 708
  points simplifiés par piste en moyenne (max 22 203), 63 km. Brut estimé par le rapport des
  tailles `original.gpx` / `filtered.gpx` (344 / 329 Mo, médiane 0,86, p90 1,58) : ~4,5 M points,
  **~70 Mo de plus** (+27 %), ~19 000 points pour la plus grosse piste. Les originaux migrés de
  biketeam sont donc déjà quasi simplifiés : la phase D leur rend peu, et ~10 % seulement passent
  le seuil de densité 1,5 qui redemande leurs surfaces. Le gain vient des fichiers envoyés et des
  parcours dessinés après la phase C.

## 3. Les phases

### A. Stockage, et les fichiers envoyés (S)

- Migration `V81` : la colonne nullable (déploiement roulant : l'ancienne version l'ignore, la
  nouvelle tolère qu'elle soit nulle).
- `ComputedTrack` porte la ligne brute : les `RawTracks.paths()` réduits au 2D. `processGpxData`
  l'écrit dans le `GpxTrack` neuf ; `applyRecompute` n'y touche pas.
- Aperçus : `raw_lines` écrit à la création et à la mise à jour, déplacé sur la nouvelle révision
  par le rattrapage HD. La promotion relance `computeGpx` sur l'`original.gpx` de l'aperçu : le
  parcours obtient son brut sans recopie.
- Couvre dès cette phase l'envoi de fichier, biketeam et l'outil GPX. Les parcours dessinés
  stockent ce qu'ils reçoivent (la ligne simplifiée) jusqu'à la phase C.

### B. Les surfaces sur le brut (M)

- `SurfaceRefreshService.readRoute` / `readPreview` lisent le brut quand il existe
  (`GpxTrackRepository` : une projection de plus, sans charger les autres colonnes lazy).
- `TraceSurfaceComputer` découpe en tranches (`MAX_REQUEST_M`, `MAX_POINTS`). Seule la copie
  envoyée est éclaircie (`spacingFor` : 5 m au moins, et assez pour qu'une tranche de distance
  tienne sous `MAX_POINTS`, ~12,6 m au-delà d'une tranche) : un GPX à 1 Hz coûte autant de
  requêtes que ses `track_points`, et `SurfaceBackfill.weight` (`distance / CORE_M`) reste juste.
- Les bornes trouvées sur le brut sont replacées sur `track_points` par `TrackAxisMapping` : un
  parcours du brut par pas de 20 m au plus, chaque arrêt cherché en avant sur le segment le plus
  proche. **Pas** de remise à l'échelle sur la longueur totale : le brut d'une trace enregistrée
  est plus long de plusieurs dizaines de mètres, l'erreur s'accumulerait et ferait sauter une borne
  sur l'autre jambe d'un aller-retour. (`UnpavedSpans.project`, contrairement à ce que supposait ce
  plan, remet à l'échelle : rien à réutiliser.) Le document stocké reste exprimé sur
  `track_points`, que lisent les clients.
- Les `offNetwork` (pièces DIRECT de l'état) se calent sur la même distance.

### C. Le brut à travers le planificateur (M-L, contrat + web)

- `RouterResponse` gagne `shape` : polyline6 2D de la forme Valhalla concaténée, telle quelle.
  La ligne affichée reste celle d'aujourd'hui.
- `PlannerPiece` gagne `shape` (ROUTED : la forme du routeur, points intérieurs comme `line`).
  DIRECT n'en a pas besoin (une droite entre deux jonctions *est* son brut). IMPORTED : la source
  gagne `shape` (le brut du fichier, renvoyé par `GpxImportService`) et la pièce se découpe sur le
  brut en projetant ses deux jonctions dessus — les indices `from`/`to` désignent la ligne
  simplifiée, pas le brut.
- Le client web **porte** `shape` sans jamais le lire ni le modifier : un recalcul d'une pièce le
  remplace. Chaque opération qui change une pièce routée sans appeler le routeur (coupure par une
  jonction insérée, fusion, suppression d'une jonction, inversion du sens, aller-retour, annuler /
  rétablir, reprise d'un état enregistré, import) doit soit transformer `shape` exactement
  (l'inverser) soit le laisser tomber pour cette pièce : un brut perdu ne coûte que de la
  précision, un brut faux corrompt la trace enregistrée. Les sources gardent le brut de l'import.
- `PlannerStates` gagne `deriveRaw` : la concaténation des `shape` (à défaut, des `line`), bornée
  comme le reste (`MAX_PLANNER_STATE_CHARS` à relever, à mesurer). `fromPoints` reçoit le brut :
  `original.gpx` d'un parcours dessiné devient enfin le brut, et le pipeline le simplifie pour
  l'affichage comme pour un fichier.
- Un état sans `shape` (clients antérieurs, états enregistrés avant) reste valide : il retombe sur
  `line`, donc sur la trace simplifiée. Version de contrat : mineure (champs optionnels).
- Mobile : pas de planificateur, donc rien à porter ; son client généré gagne les champs
  optionnels. Rien ne doit exiger `shape` : les états enregistrés avant n'en ont pas.
- **Côté serveur, livré le 30 octobre 2026** (API 13.1.0), avec ces précisions :
  - `RouterResponse.shape` : la forme Valhalla de toutes les jambes, concaténée telle que décodée,
    ses deux bouts compris. Le client peut la recopier telle quelle dans `PlannerPiece.shape` :
    un premier ou un dernier point à moins de 1 m de sa jonction est retiré à la dérivation.
  - `GpxImportTrack.shape` : la piste assainie du fichier (`RawTracks`), 2D, absente de toutes les
    pistes si elles dépassent ensemble `MAX_PLANNER_POINTS` points ; toujours absente de la réponse
    d'altitude d'une ligne, qui partage ce type.
  - Pas de `deriveRaw` à part : `validateAndDerive` (donc l'enregistrement d'un parcours et les
    aperçus de l'outil GPX) dérive du brut pièce par pièce. `directRuns`, qui sert aux
    `offNetwork` des surfaces, reste sur les `line` : ses distances sont remises à l'échelle de la
    trace stockée, simplifiée du brut comme les `line` l'ont été, alors que le brut est plus long
    de sa gigue et de ses arrêts, inégalement le long du parcours. Une pièce IMPORTED se découpe sur le brut de sa source par `TrackAxisMapping`
    (le parcours en avant de la phase B, appliqué de la ligne simplifiée vers le brut), ce qui
    garde le bon brin d'un aller-retour. Ce parcours coûte à la longueur, pas au nombre de points :
    les sources parcourues (ligne et brut ensemble) sont bornées à `MAX_TRACK_DISTANCE_METERS`
    avant de le lancer, une source au-delà garde sa `line`. Les `unpaved` d'une pièce routée indexent toujours les
    arêtes de `line`, que le serveur ne fait que valider.
  - Le brut n'est jamais cru sur parole (`RawShapes.consistent`) : une forme dont un bout est à
    plus de 50 m de sa jonction, ou dont la longueur s'écarte de celle de `line` de plus de 20 %
    plus 200 m, est ignorée (la pièce retombe sur `line`), journalisée en debug ; pour une source,
    le même contrôle contre sa `line` entière.
  - Bornes : `shape` compte dans `MAX_PLANNER_STATE_CHARS` (2 000 000 caractères, **non relevé** :
    un parcours de 200 km routé fait 10 à 25 000 points bruts, 100 à 200 Ko) ; les formes
    décodées partagent un budget de `MAX_PLANNER_SHAPE_POINTS` (100 000 points) au-delà duquel
    elles sont ignorées, pas refusées ; la trace dérivée est bornée à `MAX_PLANNER_DERIVED_POINTS`
    (200 000), au-delà de quoi une pièce garde sa `line`. Seuls une forme mal formée, une forme
    d'un seul point sur une source, ou un `shape` sur une pièce DIRECT ou IMPORTED, font un
    `PLANNER_STATE_INVALID`.
- **Côté web, livré le 30 octobre 2026**, avec ces précisions :
  - Le brut d'une jambe routée est porté par son point d'arrivée (`RoutePoint.legShape`, comme
    `legAscend`), avec les deux bouts de la jambe au moment de la réponse. Chaque geste qui écrit
    `legAscend` l'écrit aussi : `add`, `insert` (déplacement et insertion compris : les deux
    jambes sont recalculées), `remove`, `appendImport` le prennent de la réponse du routeur ; une
    ligne droite, un saut de moins de 5 m et `restoreSourceSpan` l'effacent. Annuler / rétablir
    rejouent des copies où il reste cohérent ; la reprise d'un état le repose sur sa pièce.
  - Pas d'inversion ni d'aller-retour dans le planificateur web : rien à transformer, seulement à
    porter ou à laisser tomber.
  - À l'enregistrement, `pieceShape` ne l'envoie que si la pièce ROUTED est exactement une jambe
    et que ses deux jonctions n'ont pas bougé de plus de 5 m depuis la réponse (le routeur
    recolle de quelques mètres le bout partagé avec la jambe suivante) ; sinon la pièce part sans.
  - Une source dont une pièce IMPORTED est découpée part **entière** avec son brut (le serveur
    contrôle le brut contre toute la `line`) ; les autres sont rognées sans brut, comme avant.
  - Taille : si l'état dépasse `MAX_PLANNER_STATE_CHARS`, les bruts les plus longs tombent jusqu'à
    ce qu'il tienne (une source repasse alors rognée) ; si les sources entières dépassent
    `MAX_PLANNER_POINTS`, leurs bruts tombent ; au pire, l'état part sans aucun brut. Le brut ne
    bloque jamais un enregistrement.

### D. Rattrapage de l'existant (M)

- Job planifié idempotent, sur le modèle de `SurfaceBackfill` (verrou consultatif, plafond horaire,
  les plus récents d'abord) : pour chaque piste à `raw_geometry` nulle, relire l'`original.gpx`
  courant, en extraire les tracks comme `rawTracks` (même assainissement, mêmes pistes de moins de
  deux points écartées) et écrire leur 2D si le nombre de pistes concorde ; sinon journaliser et
  marquer pour ne pas reboucler.
- Écrire en vérifiant que l'`original.gpx` lu est toujours le courant (`findCurrentFileId`), comme
  le fait le calcul des surfaces.
- Puis redemander les surfaces des parcours rattrapés (file `backfill` existante), sous le même
  plafond de dépense Stadia.
- **Livré le 30 octobre 2026** (`RawTrackBackfill`, `V82`) avec ces écarts : pas de plafond horaire
  propre (aucun appel facturé) mais un lot par passe (`pedalons.raw-backfill.batch`, 50), sous un
  verrou consultatif de session pris sans attendre sur une connexion à part (les lectures S3 restent
  hors transaction) ; les abandons (original absent ou illisible, nombre de pistes différent,
  erreur) vont dans la table `raw_track_backfill_skip` plutôt qu'une colonne de `gpx_tracks` — une
  panne du bucket ou de la base n'abandonne rien, elle clôt la passe ; les surfaces ne sont
  redemandées que si le brut compte au moins 1,5 fois les `track_points` (un parcours dessiné n'y
  gagnerait rien) : le verdict est noté dans `raw_track_resurface` quel que soit l'interrupteur, et
  `SurfaceBackfill` en fait des demandes `backfill` en dernier, sous son plafond et sa fenêtre de dix
  minutes, seulement avec `pedalons.raw-backfill.resurface`, éteint par défaut — allumable après
  coup, et une demande déjà en vol pour le parcours fait attendre la ligne au lieu de la perdre.
- **Limite assumée** : un parcours dessiné avant la phase C n'a jamais eu son brut ; son
  `original.gpx` est la ligne simplifiée, et c'est elle que le rattrapage pose. Le recalculer par le
  routeur depuis les jonctions de son état coûterait un appel facturé par pièce et pourrait donner
  un autre itinéraire (OSM a changé) : écarté.

## 4. Ordre et taille

A, puis B (le gain sur les surfaces des fichiers envoyés arrive là), puis D, puis C (le plus long,
et le seul qui touche un client, le web). Chaque phase se livre seule.

## 5. Ce qui reste à trancher

- Le brut d'un GPX envoyé garde-t-il **tous** ses points (doublons, arrêts) ? Proposition : oui,
  hormis les points consécutifs identiques, que l'assainissement retire déjà ou non — à vérifier.
- Exposer un jour `raw_geometry` (export, tuiles plus fines) : hors de ce plan.
