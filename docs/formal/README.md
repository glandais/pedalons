# Modèles formels du backend

Modèles TLA+ (vérifiés par TLC) et Lean 4 écrits le 11 octobre 2026 pour chercher des défauts de
concurrence et de logique dans le backend. Ils modélisent le code **tel qu'il était ce jour-là**
(`d9d14c62`), avec les hypothèses de déploiement : une réplique, mais deux backends pendant la
minute d'un déploiement start-first, schedulers actifs des deux côtés, PostgreSQL en READ
COMMITTED. Les dix-sept défauts trouvés ont chacun un test de reproduction, et sont corrigés sous
leur identifiant de ledger (colonne « Ledger »).

Ce sont des modèles d'enquête, pas une spécification tenue à jour : le code a changé depuis
(c'est le but), et rien ne les rejoue en CI. Un modèle sert à nouveau quand on retouche le
mécanisme qu'il décrit — le rejouer, l'adapter au nouveau code, et regarder la variante `Fix`.

## Lancer

```bash
# TLA+ : tla2tools.jar (https://github.com/tlaplus/tlaplus/releases), depuis le dossier du modèle
java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC -workers auto <Module>.tla -config <Fichier>.cfg

# Lean 4 (4.34, sans Mathlib) : les preuves passent si le fichier compile ; les #eval impriment
lean <Fichier>.lean
```

Un `.cfg` décrit une configuration : constantes, invariant vérifié, et le plus souvent un drapeau
qui choisit entre le code tel quel et une variante corrigée (`…Fix`, `…_TRUE`, `Fixed`, `Sorted`).
Une variante d'un même module sous un autre nom de fichier (`jobs/AC_A.tla`, `UE_B.tla`…) est une
copie aux constantes figées, TLC exigeant que le module porte le nom du fichier.

## Ce que chaque modèle établit

| Dossier | Modèle | Propriété | Résultat sur le code d'origine | Ledger |
|---|---|---|---|---|
| `auth` | `OtpVerify.tla` | essais comparés ≤ limite ; un code épuisé ou utilisé le reste | violé (mise à jour perdue) ; `OV_*Fix` tient | `SEC-34` |
| `auth` | `OtpIssue.tla` | ≤ 3 codes par fenêtre ; un seul code vivant | violé ; `OI_Fix` tient | `SEC-35` |
| `auth` | `Throttle.tla` | essais de mot de passe jusqu'au bcrypt ≤ limite | violé ; `TH_Fix` tient | `SEC-36` |
| `auth` | `PasskeyChallenge.tla` | un challenge, une session | violé ; `PC_Fix` tient | `SEC-37` |
| `auth` | `RefreshRotation.tla` | pas de déconnexion sans voleur ; voleur contenu (limite de `SEC-27`) ; une rotation par jeton | réponse perdue ⇒ déconnexion ; les deux autres tiennent | `API-94` |
| `auth` | `DeviceFlow.tla` | une session par code d'appairage, pour le premier approbateur | tient | — |
| `ride-participation` | `RideJoin.tla` | un groupe par sortie et par membre ; capacité ; pas de participation orpheline | les deux premiers violés, `_TRUE` (sortie verrouillée) tient ; le troisième tient | `API-98`, `API-99` |
| `ride-participation` | `LeaveAccess.lean` | le contrôle LEAVE porte sur la sortie dont on supprime la participation | contre-exemple prouvé | `SEC-38` |
| `jobs` | `UserExport.tla` | un export prêt n'est jamais jeté ; tout lien envoyé fonctionne | violés ; `UE_AF` tient | `API-95`, `API-96` |
| `jobs` | `AssetCleanup.tla` | un asset rattaché a son fichier ; un orphelin survivant aussi | violés ; `AC_AF` (suppression après commit) tient | `API-97` |
| `jobs` | `FeedbackWorker.tla` | une issue par signature ; aucune occurrence perdue | violés ; `FW_F` tient | `ISSUE-8`, `ISSUE-9` |
| `jobs` | `AutoPublish.tla` | une notification par publication, publiée seulement à échéance ou à la main | tient | — |
| `notif` | `CoalesceRace.tla` | les inscrits apprennent l'état courant de la sortie | violé, même avec un seul dispatcher ; voir la note | `NOTIF-10` |
| `notif` | `DeliveryQueue.tla` | au plus une livraison sans crash ; rien de perdu ni de bloqué | tient (au-moins-une-fois documenté en cas de crash) | — |
| `notif` | `RetentionBound.lean` | la rétention ne touche jamais un travail vivant ; backoff borné | prouvé | — |
| `weather` | `WeatherCells.tla` (+ `planner.sql`, `store.sql`) | pas de deadlock planificateur/stockage ; pas de fetch concurrent ; le ménage ne supprime rien d'utile | deadlock (reproduit sur PostgreSQL 17 avec les deux scripts) ; le reste tient | `API-100` |
| `biketeam` | `BiketeamJob.tla` | un écrivain par job ; pas de doublon ; pas de purge active ; tout job se termine ; un reset survit à un crash | le dernier violé (`Main`, `MainFail`), `Fixed` tient ; `Stall` montre la limite connue d'un worker plus lent que `stuck-after` | `MIG-15` |
| `pure` | `AdGrid.lean` | le flou d'une annonce et la sonde de proximité ne fuient rien de plus que la cellule ; Java et SQL tombent dans la même cellule | prouvé, et 0 écart sur 773 575 points | — |
| `pure` | `GroupTime.lean` | un groupe garde son départ quand on réenregistre une sortie passée après un changement de fuseau | violé (±24 h), variante corrigée tient | `API-101` |

**Note sur `CoalesceRace`** : dans le modèle, rendre la clé à la réservation (`FIX=1`) puis y ajouter
le verrou de la ligne en attente (`FIX=2`) laisse encore l'invariant violé ; seule `FIX=3` tient. Le
correctif livré sous `NOTIF-10` ressemble à `FIX=2`, mais il réinsère quand la clé a été rendue, et la
relecture n'a trouvé aucun entrelacement perdant sous la sémantique de PostgreSQL. Le modèle n'a pas
été rejoué sur ce correctif exact : c'est le ledger `NOTIF-11`.
