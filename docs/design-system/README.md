# Design system Pédalons (artefact claude.ai)

Le design system « Pédalons » que `/design` de Claude Code lit avant de dessiner :
https://claude.ai/artifact/JrjsweYBAcFdevAGV7guVD (ledger `BRAND-11`).

C'est une **copie dérivée** de la charte, pas une source : `docs/BRANDING.md`,
`frontend/src/lib/theme.ts`, `mobile/lib/core/theme/pdl_colors.dart`, `contracts/brand-colors.yaml`
et `frontend/src/lib/avatarTint.ts` font foi. Quand l'un d'eux change une valeur reprise ici,
mettre à jour le fichier de `project/` concerné et republier l'artefact.

## Ce qu'il y a dans `project/`

`project/` est l'arborescence de l'artefact, au chemin près (`project/<chemin>` dans l'artefact).

| Fichier | Contenu |
|---|---|
| `design-system.json` | L'index de l'artefact (titre, groupe d'assets « Logos » avec les identifiants des fichiers envoyés) |
| `tokens.json` | Couleurs clair / sombre, typographie, espacements, rayons, ombres, mise en page, points de rupture |
| `README.md`, `lexique.md`, `cartographie.md` | La charte, le lexique et le ton, les cartes et tracés |
| `components/<Composant>/` | Fiche (`README.md`) et aperçu statique (`preview.html`) ; `Cover/` est la couverture |
| `assets/Logos/README.md` | La notice du groupe de logos |

Pas dans le dépôt, parce que ce sont des copies de fichiers qui y sont déjà :

- `project/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf` et `OFL.txt` ← `mobile/assets/fonts/inter/` ;
- les trois logos, envoyés comme assets de l'artefact ← `assets/icon.svg`, `assets/icon-1024.png`,
  `assets/maskable-icon-512x512.png`.

## Republier

Depuis une session Claude Code, demander de republier ce dossier dans l'artefact : seuls les
fichiers modifiés partent, `design-system.json` en dernier, avec son `lastChange` mis à jour. Un
logo changé est un nouvel asset : renvoyer le fichier et reporter son identifiant dans l'index.
