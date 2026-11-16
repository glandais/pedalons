---
id: LEGAL-18
title: "L'IGN crédité pour les altitudes"
status: done
done: 2026-10-14
---

## Livré

`LEGAL-18` **L'IGN crédité pour les altitudes** (2026-10-14, contrat inchangé) — depuis `API-104`,
les profils, D+ et montées viennent du LiDAR HD de l'IGN, sous Licence Ouverte Etalab 2.0, qui
exige de nommer la source ; seules les cartes créditaient leurs fonds. Le profil altimétrique
porte désormais « Altitudes : IGN LiDAR HD, Mapterhorn » : au web en surimpression discrète en
haut à droite de `ElevationChart` (clé `map.elevationCredit`), au mobile sous les graduations de
`PdlElevationProfile`, par un paramètre `credit` déjà localisé (`core/pdl` ne traduit rien ; clé
`routes.elevationCredit`), passé par les quatre écrans qui le dessinent. Les CGU (§ données de
tiers) nomment « IGN — LiDAR HD, Licence Ouverte Etalab 2.0 » avec, pour date, celle de la
lecture à l'import de chaque parcours — le LiDAR HD est publié en continu, tuile par tuile, sans
millésime unique ; la politique de confidentialité ajoute l'usage côté serveur de
`data.geopf.fr` (coordonnées de tuiles d'~1 km, adresse IP du serveur), en parité FR/EN. Pas de
test automatisé : texte statique. **À ne pas défaire** : un profil altimétrique, sur quelque
écran que ce soit, affiche ce crédit ; une nouvelle source d'altitude s'y ajoute.
