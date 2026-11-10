# Maquettes — existant et cibles mobiles (2026-11-10)

Maquettes des écrans sortie, groupe, voyage, étape et parcours : l'existant (web desktop, web étroit, mobile),
puis les **cibles mobiles** issues de l'état des lieux ([SYNTHESE.md](../SYNTHESE.md)).

**Aucune de ces maquettes n'a été contrôlée à l'écran** : elles ont été écrites et relues en balisage seulement.
Les hauteurs d'artboard sont estimées. Les valeurs que les rapports ne donnaient pas (météo, lieux, revêtements,
commentaires, descriptions, noms d'appareils) sont inventées.

## Contenu

| Fichier | Rôle |
|---|---|
| [KIT.md](KIT.md) | Jetons, composants et données d'exemple (§1-7, pour l'existant) ; **règles des cibles mobiles (§8)** : formats, blocs communs, décisions prises écran par écran |
| `project/*-mobile-cible.dc.html` | Les 10 cibles mobiles : 4 sorties, groupe, groupe inscrit, 2 voyages, étape, parcours |
| `project/feuille-gps*.dc.html` | La feuille ouverte par le bouton « GPS », avec et sans appareil connecté (variante Android) |
| `project/*` (les autres) | L'existant, reproduit sans rien améliorer |
| `gen_canvas.py`, `extra.json` | Génèrent `project/canvas.json` (pages et disposition du canevas) et les copies `project/tous-*.dc.html` de la page « Cibles mobiles » |

## Format

Chaque `.dc.html` est un artboard du type d'artifact « Design » (canevas) : styles en ligne, racine fixe de 390 px
pour le mobile. La ligne `<script src="./support.js"></script>` est fournie par le type d'artifact : un fichier
ouvert seul dans un navigateur ne s'affiche pas. `KIT.md` §2 décrit les règles du format.

Pour republier : `python3 gen_canvas.py` depuis ce dossier, puis envoyer `project/` vers l'artifact.

## Ce qui reste ouvert

- Les décisions de `KIT.md` §8 ne sont pas dans le code et n'ont pas d'entrée de ledger.
- Revêtement du parcours d'exemple : quatre catégories sur la fiche parcours, deux sur la sortie et le groupe.
- États non dessinés : inscrit sur la sortie solo et sur l'étape ; feuille « GPS » sur iOS ; écrans sans description.
- Relecture critique non traitée : météo basse sur la sortie solo, deux « km/h » voisins (vitesse et vent) dans les
  cartes, libellés du dénivelé et du nom de groupe qui varient, pas d'export sur le voyage.
- Les maquettes web n'ont reçu aucune de ces décisions (« Vitesse moyenne » remplace « Allure moyenne » aussi sur le web).
