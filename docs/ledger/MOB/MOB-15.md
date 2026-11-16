---
id: MOB-15
title: "Profil (33)"
status: open
group: "Recette sur une application qui tourne"
kind: recette
verified: 2026-11-16
---

## Reste à faire

`MOB-15` **Profil (33)** — la recette sur appareil du profil refondu (`MOB-48` : vue
d'ensemble puis sous-pages `/profil/<sujet>`), seule entrée qui la décrit ; `MOB-62` n'en
garde que les finitions. **Vue d'ensemble** : ligne Mon compte, tirer pour rafraîchir,
ouverture de chaque sous-page et retour ; la cible de 44 px de `PdlChip` vaut pour toutes les
puces de filtre de l'app. **Préférences** : les quatre réglages (unités, fuseau horaire,
thème, langue) s'appliquent **immédiatement, sans bouton**, et la ligne d'état de la vue
d'ensemble suit au retour ; un échec revient à la valeur précédente. **Confidentialité** :
« Être contacté par les membres », même règle ; Utilisateurs bloqués s'ouvre en
Profil › Confidentialité › Bloqués, y compris par lien profond, et le retour ramène à
Confidentialité. **Connexion et sécurité** : ajouter une seconde clé d'accès **n'écrase plus
les autres**, « Déconnecter tous les appareils » est câblé. **Notifications** : une ligne par
type, une puce par canal déclaré par le serveur — à recetter dans les deux états, aucun canal
configurable (le défaut en dev ; la ligne d'état dit alors que tout reste dans l'app) et push
actif (le cas en prod). La cloche reste sur l'Accueil (`MOB-50`). Les mêmes parcours sont
automatisés dans Patrol, verts depuis le 6 octobre 2026 (`MOB-49`).
