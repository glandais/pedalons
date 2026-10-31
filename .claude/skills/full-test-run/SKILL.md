---
name: full-test-run
description: Recette complète des tests de Pédalons — tous les tests unitaires (backend compris), puis les e2e web (Playwright), iOS puis Android (Patrol), en suivant les logs et en corrigeant au fil de l'eau. À utiliser quand on demande de « lancer tous les tests », une recette complète, ou de vérifier tout le dépôt avant une release.
---

# Recette complète des tests

Demander « tous les tests » lève l'interdiction du CLAUDE.md de lancer la suite backend : c'est
une demande explicite. Hors de ce skill, elle tient toujours.

## Règles du déroulé

- **Tout est séquentiel.** La machine a peu de ressources : une seule suite à la fois, jamais
  deux commandes de test en parallèle, même légères.
- **Jamais la suite backend en même temps qu'un e2e** : ses Testcontainers créent/suppriment des
  interfaces veth et Chromium tombe en `net::ERR_NETWORK_CHANGED`.
- **Un seul appareil virtuel à la fois**, iOS et Android confondus. Le téléphone Android physique
  branché ne compte pas, mais on n'y installe jamais de test.
- Chaque suite écrit son log dans `<scratchpad>/logs/<suite>.log` ; lancer les longues en
  arrière-plan (`run_in_background`) et lire le log à la fin, ou sa queue si ça semble bloqué.
- **Corriger au fil de l'eau** : un échec se diagnostique (log, trace Playwright, capture Patrol),
  se corrige dans le code, puis on relance *le test en échec seul* avant de reprendre la suite.
  Distinguer un vrai bug d'un test fragile ; ne jamais désactiver un test pour passer (surtout pas
  les `…QueryCountTest`). Un échec backend : le signaler avec la sortie, ne pas s'acharner.
- Après une correction de code applicatif, **reconstruire l'image e2e concernée** avant de
  retester (les e2e tournent sur les images, pas sur l'arbre de travail).
- **Redémarrer Docker Desktop en entier avant chaque passe e2e** (web, iOS, Android) : voir
  « Redémarrage Docker » au §2.
- Ne pas commiter sans demande ; si on commite, `./format.sh` d'abord et l'entrée de ledger qui va.

## 0. Préparation

```bash
xcrun simctl list devices available | grep Booted   # rien, ou le iPhone 17 Pro Max
adb devices                                         # pas d'émulateur qui tourne
docker ps --format '{{.Names}}' | grep tribly-e2e   # la pile e2e est-elle up ?
```

- Vérifier qu'aucune autre session Claude n'utilise la pile `tribly-e2e` (`ListAgents`) ; si oui,
  la prévenir et attendre son feu vert avant le moindre e2e.
- Patrol iOS exige que la session tourne sous **iTerm** (accès complet au disque, dépôt sur
  `/Volumes/Data`), pas sous herdr : remonter les `ppid` jusqu'à `iTerm2`.

## 1. Tests unitaires (dans cet ordre, un par un)

| Module | Commande (depuis le module) |
|---|---|
| frontend | `pnpm typecheck`, `pnpm lint`, `pnpm e2e:typecheck`, `pnpm test run` |
| backend | `mvn test` (~long : en arrière-plan) |
| mobile | `flutter analyze`, `flutter test` |
| karoo | pas de tests unitaires : `./gradlew --quiet assembleDebug` puis `./gradlew --quiet --stop` |
| garmin-app | `make simulator; sleep 8; make test` (le simulateur doit tourner avant ; verdict = ligne `PASSED`), puis `pkill -f ConnectIQ.app` |

**Suite backend sur optiplex** : quand la recette se fait avec la pile e2e sur optiplex (skill
`pedalons-e2e-optiplex`), `mvn test` y tourne aussi (§6 de ce skill), en arrière-plan pendant les
autres tests unitaires du Mac, et *avant* la construction de la pile là-bas. Le Mac n'a alors plus
besoin de Docker Desktop, et la règle « jamais la suite backend en même temps qu'un e2e » se
transpose à optiplex (charge CPU, plus les veth).

Pas de `timeout` sur macOS (code 127) : ne pas l'utiliser pour borner une commande.

`mobile/check.sh` et `karoo/check.sh` reformatent et régénèrent : ne les lancer que si on veut
aussi ces effets de bord.

## 2. Pile e2e

```bash
docker inspect --format '{{.Config.Image}}' tribly-e2e-backend
docker images | grep tribly-e2e-$(git rev-parse --short=12 HEAD)   # images du HEAD ?
scripts/e2e.sh build frontend   # / backend — seulement si l'image n'est pas celle du HEAD
scripts/e2e.sh up
```

**Redémarrage Docker** — avant chaque passe e2e (web, iOS, Android), quitter Docker Desktop
complètement, le relancer, puis remonter la pile :

```bash
osascript -e 'quit app "Docker"'
while pgrep -qf 'Docker.app/Contents/MacOS'; do sleep 2; done
open -a Docker
until docker info >/dev/null 2>&1; do sleep 2; done
scripts/e2e.sh up
```

## 3. E2E web (Playwright)

D'abord le redémarrage Docker du §2.

```bash
scripts/e2e.sh test --workers=3 > logs/e2e-web.log 2>&1
```

- Peu de workers sur cette machine (`--workers=3`, voire 2).
- Un test seul : `scripts/e2e.sh test <fichier> -g '<titre>'`.
- Après un échec : `pnpm exec playwright show-trace <trace.zip>` (chemin imprimé dans le log),
  ou lire `error-context.md` à côté de la trace.
- Les journaux de la pile : `scripts/e2e.sh logs backend`.
- `scripts/e2e.sh test` écrit dans le log au fil de l'eau avec `--reporter=line` : surveiller
  avec un `Monitor` sur `tail -F … | grep -E '^\s+[0-9]+\) |failed$|passed \('`, réarmé toutes
  les 30 min (la suite complète dure ~45 min à 3 workers, ~2000 tests).
- Comparer avec le nightly CI (`gh run list --workflow e2e.yml`, `gh run view <id> --log-failed`) :
  un échec déjà présent en CI est un vrai défaut ; un échec seulement local vient souvent de
  macOS (le CI tourne sous Linux).
- Piège macOS : Chromium transforme Ctrl+clic en clic droit **quel que soit l'UA émulé** (le
  projet `desktop` se présente en Windows). Un test qui dépend de l'hôte teste
  `process.platform`, pas le `navigator` de la page.
- Une sonde ponctuelle (écouteurs d'événements en `page.evaluate`, `console.log('PROBE …')`
  relayé par `page.on('console')`) tranche vite ; la retirer ensuite.

## 4. E2E iOS (Patrol)

D'abord le redémarrage Docker du §2.

Simulateur : **iPhone 17 Pro Max**, iOS 26.5, UDID `05EC0174-83A8-4D6D-B334-BB93E84C8D46`.

```bash
cd mobile
PATROL_DEVICE=05EC0174-83A8-4D6D-B334-BB93E84C8D46 bash e2e.sh > logs/e2e-ios.log 2>&1
```

- Un test seul : `… bash e2e.sh -t patrol_test/<x>_test.dart`.
- Suivre le log (iOS comme Android) : un grep sur `❌` remonte de faux échecs — une vérification
  d'absence (`scrollTo` d'une clé qui ne doit pas exister) imprime un ❌ d'étape dans un test qui
  passe. Retirer les codes ANSI, puis ne garder que les lignes qui *commencent* par ❌ et le bilan :
  `tail -F logs/e2e-ios.log | sed -u 's/\x1b\[[0-9;]*[A-Za-z]//g' | grep -E --line-buffered '^❌|Total:|Successful:|Failed:'`.
- `Total: 0` + code 65 après ~16 min = accès disque (voir §0), pas un bug de test.
- Patrol désinstalle `fr.pedalons.mobile` à la fin : normal.
- Fin : `xcrun simctl shutdown 05EC0174-83A8-4D6D-B334-BB93E84C8D46`.

## 5. E2E Android (Patrol)

Seulement une fois le simulateur iOS éteint, et après le redémarrage Docker du §2.

```bash
~/Library/Android/sdk/emulator/emulator -avd pedalons_e2e -no-snapshot-save -no-window &
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 wait-for-device
cd mobile
E2E_PLATFORM=android PATROL_DEVICE=emulator-5554 bash e2e.sh > logs/e2e-android.log 2>&1
```

- Toujours `PATROL_DEVICE=emulator-5554` : jamais le téléphone physique.
- ANR « Digital Wellbeing » / « System UI » qui couvre l'app : AVD sous-dimensionné (4 cœurs
  requis), tuer le run, relancer le test seul.
- Fin : `adb -s emulator-5554 emu kill`.

## 6. Bilan

Un tableau suite → résultat (passés/échoués), les corrections faites (fichiers), et ce qui reste
rouge avec la sortie d'erreur. Rien n'est « vert » sans le log qui le montre.
