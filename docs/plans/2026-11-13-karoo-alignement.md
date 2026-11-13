# Aligner l'app Karoo sur l'app mobile — formats, mots, fuseau, étapes de voyage (2026-11-13)

L'app et le site suivent depuis le 12 novembre les mêmes règles de cartes et de listes
([`KIT.md`](2026-11-10-etat-des-lieux-affichage/maquettes/KIT.md) §9 et §10). L'extension Karoo n'a pas été passée à
l'audit : ses lignes écrivent « 14/11/2026 09:30 », « ↑600m », « 1 routes », et elle ignore les voyages. Ce plan
l'aligne, sans toucher à la structure de ses écrans. L'app Garmin reste de côté.

Ledger : `API-191` (affichage), `API-168` (étapes de voyage), `API-193` (recette).

## Décisions (13 novembre 2026)

| Question | Décision |
|---|---|
| Quels voyages | Les **étapes des voyages où l'on participe**, dans « Prochaines sorties », mêlées aux groupes par heure de départ. Pas d'entrée « Voyages » à parcourir. C'est la règle « GPS » des cartes (KIT §9). |
| Contrat | Le même appel `GET /api/device/routes`, avec `stages=true` que seul le Karoo envoie. Sans lui la réponse est celle d'avant, à l'octet : le budget de taille de Garmin n'est pas touché. |
| Jusqu'où aligner | **Formats, mots et fuseau.** L'ordre des informations d'une ligne et les écrans ne bougent pas. |
| Fuseau | L'heure d'un départ se lit **dans le fuseau de la sortie**, comme dans l'app ; d'ailleurs, la ligne « heure de Tokyo (ven. 01:00 chez vous) » la suit. Revient sur « les appareils rendent à leur heure locale » d'`API-78` et `API-84` pour le Karoo seul. Le contrat ne change pas : `startDateTime` reste un instant absolu, `timezone` était déjà envoyé. |
| Heure 12 h / 24 h | **La langue décide**, pas le réglage du Karoo (BRANDING §8.3, décision du 10 novembre) : c'est ce que disent les cas partagés. |

## Ce qui change à l'écran

| Sujet | Avant | Après |
|---|---|---|
| Départ | « 14/11/2026 09:30 », fuseau du Karoo | « sam. 14 nov. · 09:30 », « Aujourd'hui · 09:30 », « Demain · 09:30 », l'année hors de l'année en cours ; fuseau de la sortie |
| Distance | « 42,0 km » (espace ordinaire) | « 42,0 km » (espace insécable) |
| Dénivelé | « ↑1240m » | « 1 240 m D+ » |
| Compteurs | « 1 sorties », « 1 routes » | accordés (`plurals`) |
| Nom de groupe | « B » | « Groupe B » pour un nom de 1 ou 2 caractères |
| Étape de voyage | absente | une ligne : nom de l'étape, nom du voyage, départ, « départ → arrivée », distance et dénivelé, état chez Hammerhead |

## Lots

1. **Backend** (`API-168`, contrat `14.10.0`) — `DeviceRoutesResponse.registeredStages`, absent sans `stages=true` ;
   `DeviceRegisteredStageDto` ; `TripParticipationRepository.findUpcomingRegisteredStages`, même sélection que
   l'envoi automatique (`findGpsSyncStageTargets`) et même fenêtre que les groupes (de 12 h avant à 7 jours après,
   20 lignes au plus). Tests dans `DeviceRoutesResourceTest`.
2. **Formats du Karoo** (`API-191`) — `ui/Formatters.kt` réécrit sur les règles communes ; `FormatCasesTest` lit
   `contracts/format-cases.json` (`distance`, `elevation`, `shortDateTime`) ; `ui/ZoneLabel.kt`, portage de
   `mobile/lib/core/utils/zone_label.dart`.
3. **Mots du Karoo** (`API-191`) — `plurals`, « Groupe B » (`ui/GroupTitle.kt`).
4. **Étapes sur le Karoo** (`API-168`) — modèle, `?stages=true`, ligne d'étape dans « Prochaines sorties ».
5. **Captures** — les 70 références sont réenregistrées exprès (changement visuel voulu), plus les cas d'étape.
6. **Documents** — KIT §9 (« Ce qui vaut pour le Karoo »), `contracts/format-cases.md`, `karoo/CLAUDE.md`, ledger.

## État

| Lot | État |
|---|---|
| 1. Backend | Codé le 13 novembre 2026, contrat `14.10.0` régénéré. `DeviceRegisteredStagesResourceTest` écrit, compile, **non lancé** (`API-193`) |
| 2 à 4. Karoo | Codés le 13 novembre 2026 ; `bash karoo/check.sh` vert (385 tests, captures comprises) |
| 5. Captures | 36 des 70 références réenregistrées, 4 nouvelles (`registered_with_stages`, `registered_other_zone`, en et fr) ; regardées par échantillon |
| 6. Documents | KIT §9, `contracts/format-cases.md`, `karoo/CLAUDE.md`, ledger |
| Recette sur un Karoo | À faire : `API-193` |

## Écarts voulus, propres au Karoo

- **« Sync vers Karoo »**, pas « GPS » : sur l'appareil il n'y a qu'une destination, pas de feuille à ouvrir.
- **Ni avatars, ni badges, ni météo, ni personnes inscrites** : l'écran sert à charger un parcours avant de rouler.
- **Pas de filtre, de recherche ni de création** (règles de listes RL2 à RL13) : quatre touches, pas de clavier.
- **Thème sombre seul**, couleurs propres (lisibilité au soleil).
- **Fenêtre de 7 jours** : une étape plus lointaine d'un long voyage n'apparaît pas encore.

## Ce qui reste hors du plan

- Les défauts de comportement figés par le découpage (`API-186` à `API-189`) et le bouton Retour qui recouvre la
  dernière ligne d'une liste.
- Garmin : formats (`API-159`) et étapes (`API-192`).
- La prochaine sortie dès l'accueil et l'ordre des informations d'une ligne (option « structure », non retenue).
