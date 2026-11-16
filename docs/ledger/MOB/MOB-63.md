---
id: MOB-63
title: "Fiche App Store et captures refaites sur l'app d'octobre"
status: done
done: 2026-10-09
---

## Livré

`MOB-63` **Fiche App Store et captures refaites sur l'app d'octobre** (9 octobre 2026, contrat
inchangé) — les captures du 25 septembre montraient un fil d'équipe remplacé depuis par le
tableau de bord, l'Agenda et les Publications (`MOB-60`), et ni la description ni les captures ne
disaient rien de la météo. Description FR/EN réécrite (météo au départ et le long du parcours à
l'allure du groupe, météo des étapes, tableau de bord, Agenda, compteurs Karoo et Garmin
nommés, réglages de notification par type), mots-clés `météo,vent` / `weather,wind` à la place de
`groupe,randonnée` / `group,events` — pas de marque tierce dans les mots-clés (règle 2.3.7). Sept
cartes au lieu de six, iPhone et iPad : accueil (iPad : voyage), groupes d'allure, **météo du
parcours**, profil et montées, **tableau de bord**, bibliothèque, calendrier. Trois correctifs en
chemin :
- le mode capture pousse un écran sans URL par-dessus le chemin ouvert (`push` dans le fichier de
  lancement, `screenshotTakePush`, consommé une fois) : la « Météo du parcours » n'est qu'un
  `Navigator.push` depuis le détail ;
- `seed.py` cherchait le conteneur postgres sous son nom compose, qu'une tâche Swarm n'a pas, et
  envoyait des instants que l'API refuse en 400 depuis le contrat 11.0.0 (`API-60`) : conteneur
  trouvé par son label de service comme `scripts/_backup_common.sh`, heures murales de Paris
  (`wall()`). Le rafraîchissement quotidien de la prod (`OPS-28`) passe par le même script : il
  échouait à chaque nuit depuis le déploiement du 11.0.0 et ne repart qu'une fois le checkout
  `~/prod` de l'hôte à jour ;
- `PdlSectionHeader` donnait la moitié de la ligne au titre (un `Flexible` face à un `Spacer`) :
  « Vos prochaines … » tronqué sur l'iPhone le plus large, « Voir tout » décollé du bord droit
  sur iPad. Titre et compteur prennent désormais tout ce que l'action laisse.
`capture.sh` ne cherche plus le simulateur iPad pour une capture iPhone seule. Pas de test
automatisé : relecture des 28 captures. Poussé le jour même : `asc metadata apply` (description et
mots-clés, FR/EN), puis `asc screenshots upload --replace` sur les quatre jeux. **À ne pas défaire** : la troisième carte suppose une
sortie à moins de sept jours — le seed la place au samedi suivant, capturer juste après lui.
