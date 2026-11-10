# Kit commun — maquettes de l'EXISTANT Pédalons

Tu dessines des artboards `.dc.html` (un fichier = un écran) qui reproduisent **l'existant, sans rien améliorer** :
même ordre de blocs, mêmes libellés, mêmes formats de date, mêmes doublons et défauts que dans les rapports.
N'applique PAS la section « Décisions prises » de `SYNTHESE.md` (c'est l'étape suivante).

## 1. Sources

- Rapports : `docs/plans/2026-11-10-etat-des-lieux-affichage/` (dans le dépôt). Ton prompt nomme les tiens.
  Suis leur section 2 (ordre des blocs), 3 (variantes), 4 (dates) et 5 (wireframes ASCII).
- Rendu exact d'un bloc : lis le code cité `fichier:ligne` dans le rapport quand tu hésites
  (web : `frontend/src/…`, mobile : `mobile/lib/…`, widgets `mobile/lib/core/pdl/`).
- Charte : `docs/BRANDING.md` §3, §4, §5, §7 ; jetons : `docs/pedalons.css`.
- Lecture seule sur le dépôt. N'écris QUE dans le dossier `project/` indiqué par ton prompt. Ne lance ni build, ni test, ni navigateur, ni simulateur. Ne vérifie pas le rendu.

## 2. Format `.dc.html` — règles qui cassent en silence

Squelette obligatoire (copie-le tel quel, change titre, contenu, tailles) :

```html
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>Sortie solo — mobile</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap">
<style>
body{margin:0}
a{color:#3b5bdb}a:hover{color:#364fc7}
</style>
</helmet>
<div style="width: 390px; height: 2400px; box-sizing: border-box; background: #ffffff; color: #000000; font-family: Inter, system-ui, sans-serif; font-size: 14px; line-height: 1.45; display: flex; flex-direction: column; overflow: hidden">
  … contenu …
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":390,"height":2400}}'>
class Component extends DCLogic {
renderVals() {
return {};
}
}
</script>
</body>
</html>
```

- La ligne `<script src="./support.js"></script>` reste EXACTEMENT ainsi. Le bloc `<script type="text/x-dc" data-dc-script …>` est toujours présent.
- Ferme chaque élément non vide ; mets tous les attributs entre guillemets doubles ; `data-props` entre apostrophes simples.
- **Tout le style en `style="…"` inline.** `<helmet><style>` ne contient que les deux lignes ci-dessus. Pas de classes CSS, pas de `<style>` ailleurs.
- Mise en page par flex ou grid + `gap` (grille : `display: grid; grid-template-columns: repeat(N, minmax(0, 1fr))`, ou une liste de pistes explicite pour deux colonnes inégales).
- Texte écrit en dur dans le balisage (pas de `{{trous}}` pour le texte). Pas de JS qui construit du DOM.
- Aucune image distante, aucun `data:` URI, pas d'`<iframe>`. Cartes, profils et avatars = SVG inline ou `<div>` (voir §5).
- Icônes : SVG inline au trait (style Tabler : `fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"`, viewBox 24). **Jamais d'emoji.** SVG décoratif : `aria-hidden="true"`.
- Vrais éléments : `<button type="button">`, `<a href="#">`, `<h1>`… Bouton icône seul : `aria-label`.
- Pas de fausse barre d'état iOS/Android, pas de cadre de téléphone.
- Noms de fichiers : lettres ASCII, chiffres, `-` ; fin `.dc.html` ; ceux imposés par ton prompt.

### Trois gabarits

| Gabarit | Racine | `$preview` |
|---|---|---|
| **mobile** (app Flutter) | fixe `width: 390px; height: Hpx; overflow: hidden` | 390 × H |
| **web-etroit** (site à largeur téléphone) | fixe `width: 390px; height: Hpx; overflow: hidden` | 390 × H |
| **web-desktop** (site ≥ 1024 px, deux colonnes) | fluide : `width: 100%; min-height: Hpx`, conteneur interne `max-width: 1280px; margin: 0 auto; padding: 0 16px` (jamais de largeur en px sur la racine) | 1280 × H |

**H = la hauteur totale de l'écran déroulé** (toute la page, pas seulement le premier écran). Estime-la avec soin en additionnant tes blocs
et arrondis au-dessus (mieux vaut 80 px de fond vide en bas que du contenu coupé). Mets la même valeur dans la racine et dans `$preview`.
Sur mobile, une barre d'action fixe en bas se dessine **en bas de l'artboard** (dernier enfant, `margin-top: auto`), une app bar en haut.
Sur web-desktop, la carte « sticky » se dessine simplement en haut de la colonne droite.

## 3. Jetons (mode clair uniquement)

| Rôle | Valeur |
|---|---|
| Fond / surface | `#ffffff` |
| Surface alternée | `#f8f9fa` |
| Bordure | `#ced4da` · discrète `#dee2e6` |
| Texte | `#000000` · atténué `#666d75` |
| Lien | `#3b5bdb` |
| Primaire (indigo) | `#4263eb` · survol `#3b5bdb` · fond doux `#dbe4ff` · très doux `#edf2ff` · texte sur doux `#364fc7` |
| Succès | `#2f9e44` · doux `#d3f9d8` · texte sur doux `#2b8a3e` |
| Alerte | `#f08c00` · doux `#fff3bf` · texte sur doux `#7a4a00` |
| Danger | `#e03131` · doux `#ffe3e3` · texte sur doux `#c92a2a` |
| Neutre doux | `#f1f3f5` · texte `#495057` |
| Voyage (turquoise) | `#099268` · doux `#c3fae8` · texte sur doux `#087f5b` |
| Tracé de parcours | `#228be6` ; multi-parcours : `#566b13`, `#1d32a8`, `#732c7b`, `#bdbd22` |
| Pente (profil) | vert `#40c057`, jaune `#fab005`, orange `#fd7e14`, rouge `#e03131` |

Typo : Inter. Titres 700. h1 web desktop 34 px / mobile 24 px ; h2 26/20 ; h3 22/18 ; h4 (titre de carte) 18/16.
Corps 16 px (web) ; taille de travail 14 px ; métadonnées 12 px. Chiffres mis en avant : 600.
Rayons : 8 px partout ; **cartes mobiles 12 px** ; pilule 1000 px ; feuille mobile 16 px en haut.
Espacements : 4, 8, 10, 12, **16** (padding de carte et marge de section), 20, 32.
Cartes : plates, bordure 1 px `#ced4da`, pas d'ombre. Cibles tactiles ≥ 44 px (boutons web desktop : 36 px).

## 4. Composants — recettes à recopier

**Badge** (seul endroit en capitales) :
```html
<span style="display: inline-flex; align-items: center; height: 18px; padding: 0 8px; border-radius: 1000px; font-size: 10px; font-weight: 700; letter-spacing: 0.25px; text-transform: uppercase; background: #dbe4ff; color: #364fc7">J'y vais</span>
```
Variantes : succès (`#d3f9d8`/`#2b8a3e`), neutre (`#f1f3f5`/`#495057`), danger (`#ffe3e3`/`#c92a2a`), alerte (`#fff3bf`/`#7a4a00`).

**Bouton primaire** (web desktop : `min-height: 36px`) :
```html
<button type="button" style="min-height: 44px; padding: 0 16px; border-radius: 8px; border: none; background: #4263eb; color: #ffffff; font: 500 14px Inter, system-ui, sans-serif">Rejoindre</button>
```
Contour : `background: #ffffff; border: 1px solid #4263eb; color: #3b5bdb`. Neutre : `border: 1px solid #ced4da; color: #000000`.
Bouton icône : 44 × 44 (36 en desktop), fond transparent, `aria-label`.

**Boîte du jour** (à plat ; voyage : fond `#c3fae8`, jour en `#087f5b`) :
```html
<div style="width: 64px; flex-shrink: 0; padding: 8px 0; border-radius: 8px; background: #dbe4ff; display: flex; flex-direction: column; align-items: center; line-height: 1.15">
  <span style="font-size: 13px; font-weight: 600; color: #364fc7">sam.</span>
  <span style="font-size: 26px; font-weight: 700">14</span>
  <span style="font-size: 13px; font-weight: 500">nov.</span>
</div>
```

**Bloc de départ** (surface alternée bordée ; rayon 8 web, 12 mobile) :
```html
<div style="display: flex; gap: 12px; align-items: center; padding: 12px; background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 12px">
  <!-- boîte du jour -->
  <div style="display: flex; flex-direction: column; gap: 4px; min-width: 0">
    <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap">
      <span style="font-size: 22px; font-weight: 700; line-height: 1.2">Départ 09:00</span>
      <!-- pastille « Demain » / « Aujourd'hui » = badge indigo, seulement si c'est le cas -->
    </div>
    <span style="font-size: 14px; color: #666d75">Place de la Mairie, Huelgoat</span>
  </div>
</div>
```
« Départ 09:00 » : 24 px sur web, 22 px sur mobile.

**Carte / panneau** : `border: 1px solid #ced4da; border-radius: 8px (12 mobile); padding: 16px; background: #ffffff`.

**Bandeau d'heure de groupe** (variante « heures différentes ») : `background: #edf2ff; border-radius: 8px; padding: 8px 12px`, contenant icône horloge indigo + « Départ 09:30 » en 16 px/700.

**Tuile de chiffre** : libellé 12 px `#666d75` au-dessus, valeur 16 px/600 dessous ; rangée en grid 2, 3 ou 4 colonnes.

**Avatar** : `width: 32px; height: 32px; border-radius: 1000px; background: <couleur>; color: #ffffff; font-size: 12px; font-weight: 700; display: grid; place-items: center` avec les initiales. Grappe : `margin-left: -8px` + `border: 2px solid #ffffff`.

**Barre de places** : piste `height: 6px; border-radius: 1000px; background: #e9ecef`, remplissage `#4263eb`.

**Contrôle segmenté** (Pente | Revêtement | Météo) : conteneur `display: inline-flex; padding: 3px; background: #f1f3f5; border-radius: 8px`, segment actif `background: #ffffff; border-radius: 6px; box-shadow: 0 1px 2px rgba(0,0,0,0.1); font-weight: 500`, chaque segment un `<button>` `padding: 6px 12px; font-size: 14px`.

**App bar mobile** : `height: 56px; display: flex; align-items: center; padding: 0 4px; gap: 4px`, flèche retour à gauche, actions (icônes 44 × 44) à droite, bordure basse `#dee2e6`.

**Barre d'action mobile** (fixe en bas) : `margin-top: auto; padding: 12px 16px; border-top: 1px solid #dee2e6; background: #ffffff; display: flex; align-items: center; gap: 12px`.

**En-tête du site** (web) : barre `height: 56px; border-bottom: 1px solid #dee2e6`, à gauche le nom « Pédalons » en 20 px/700 précédé d'un carré bleu `#228be6` 28 px rayon 6 px (substitut du logo), à droite un avatar. En web-etroit : icône menu à gauche.

## 5. Carte et profil (substituts dessinés)

**Carte** : un `<div>` de la taille voulue, `position: relative; overflow: hidden; background: #e8f0e4`, contenant un SVG `width="100%" height="100%" preserveAspectRatio="none"` `aria-hidden="true"` avec :
quelques aplats doux (bois `#d5e5cc`, eau `#cfe3f5`), 3-4 routes fines `#ffffff` (stroke-width 3-5), puis **le tracé** : un `path` `stroke="#228be6" stroke-width="4" fill="none"`
(plusieurs tracés de couleurs différentes pour le multi-parcours), un point de départ vert `#2f9e44` et d'arrivée rouge `#e03131` (cercles r=6 à contour blanc).
Par-dessus, en `position: absolute` : les contrôles réels de l'écran (boutons zoom, plein écran, fond de carte, barre d'échelle « 2 km », crédit « © OpenStreetMap ») tels que le rapport les décrit.
Hauteurs : celles du rapport (mobile sortie/groupe : 421 px ; étape : 240 px ; voyage : 280 px ; web étroit : ~52svh ≈ 440 px ; desktop sticky : ~640 px).

**Profil altimétrique** : SVG `viewBox="0 0 400 110" preserveAspectRatio="none"`, une aire fermée (`path` avec `fill`) découpée en 4-6 tronçons colorés selon la pente
(vert → jaune → orange → rouge), ligne de crête `#495057` 1,5 px, et sous le SVG une rangée d'axe 11 px `#666d75` (« 0 km », « 46 km », « 92 km »).
Hauteur : celle du rapport (110, 140 ou 160 px). Sur le web desktop, le profil est **posé sur le bas de la carte** quand le rapport le dit.

**Météo** : icônes au trait (soleil, nuage, pluie, vent = flèche) ; tableau heure par heure en grid ; verdicts = 4 tuiles.

## 6. Données d'exemple (les mêmes partout)

Date du jour : **mar. 10 nov. 2026**. Fuseau du lecteur = fuseau des sorties (pas de mention de fuseau).

- Équipe : **Vélo Club des Monts**. Lecteur : **Camille Durand**, membre, inscrite quand l'écran montre un état inscrit.
- Personnes : Léa Martin, Karim Benali, Camille Durand, Noé Perrin, Inès Roche, Sacha Morel, Jeanne Colin, Malo Guérin.
- **Sortie** : « Boucle des Monts d'Arrée » — sam. 14 nov. 2026, Départ 09:00, lieu de départ « Place de la Mairie, Huelgoat », statut Publiée.
  - Groupe **A** : 28 km/h, 92 km, 1 240 m D+, 8/12 personnes, capitaine Léa Martin.
  - Groupe **B** : 25 km/h, 78 km, 980 m D+, 11/12 personnes, sans capitaine.
  - Groupe **C** : 22 km/h, 61 km, 720 m D+, 12/12 (Complet), sans capitaine.
  - Solo : un seul groupe A. Heures différentes : A 09:00, B 09:30, C 10:00 ; Camille est dans le B.
  - Arrivée estimée du groupe A : 12:17.
- **Voyage** : « Traversée du Morvan » — ven. 20 → dim. 22 nov., 3 étapes, 12 personnes inscrites.
  - Étape 1 « Autun → Château-Chinon », ven. 20 nov. · 08:30, 74 km, 1 380 m D+.
  - Étape 2 « Château-Chinon → Saulieu », sam. 21 nov. · 09:00, 68 km, 1 120 m D+.
  - Étape 3 « Saulieu → Avallon », dim. 22 nov. · 09:00, 59 km, 840 m D+.
  - Voyage d'une étape : « Aller-retour au mont Beuvray », sam. 21 nov. · 08:30, 96 km, 1 650 m D+.
- **Parcours** : « Boucle des Monts d'Arrée », 92,4 km, 1 240 m D+, route, créé le 3 novembre 2026 par Léa Martin ; tags « vallonné », « Finistère » ;
  cols : Roc'h Trévezel (4,2 km à 5,1 %), Mont Saint-Michel de Brasparts (2,8 km à 6,2 %) ; points : Fontaine de Huelgoat (eau, km 0,4), Boulangerie de Brasparts (km 41).
- Météo : 9 °C au départ, vent d'ouest 18 km/h, 20 % de pluie, lever 08:12, coucher 17:31.
- Commentaires : 2 (« il y a 2 heures », « il y a 3 jours »).

**Écris les nombres et les dates exactement comme le rapport dit que l'écran les rend**, défauts compris
(par exemple « 92.4 km » avec un point sur le web si le rapport le signale, axes du profil en anglais sur le web).
Français épicène pour tout texte que tu inventes (« personnes inscrites », « capitaine »), sans point médian.

## 7. Ce que tu rends

Pour chaque artboard : écris le fichier dans le dossier `project/` indiqué, puis dans ta réponse finale donne **une ligne par fichier** :
`nom-du-fichier.dc.html | gabarit | largeur | hauteur | titre court en français`
suivie, si besoin, de 5 lignes maximum sur ce que tu n'as pas pu reproduire fidèlement et pourquoi.

## 8. Règles de format des CIBLES mobiles (passe du 2026-11-10)

- Nombres : espace insécable entre valeur et unité, fine insécable pour les milliers ; distance au dixième (« 92,4 km »), arrondie sur les axes et les passages ; durée « 3 h 18 ».
- Tailles de texte : 12 (méta), 14 (corps, actions, sous-libellés en 600), 16 (h3, valeurs), 20 (h2), 22 (heure de départ) ; 10 pour les badges ; 13 dans la boîte du jour seulement.
- Texte secondaire : `#666d75` partout ; `#495057` réservé aux segments inactifs, au « +N » et aux icônes.
- Rythme : 24 px au-dessus d'un h2, 20 px au-dessus d'un h3.
- Vent : la flèche porte la direction, le texte ne l'écrit jamais (« Vent 18 km/h ») ; le point cardinal reste pour le lecteur d'écran. Règle déjà dans l'app (`formatWind(compass: false)`).
- Horodatage de prévision : « Prévision du mar. 10 nov. · 08:30 ».
- Libellé : « Vitesse moyenne » (plus « Allure moyenne ») — à changer aussi sur le web.
- Carte 44 % de l'écran (421 px) et profil 110 px sur tous les écrans mobiles.
- Titre de la liste des passages : « Météo le long du parcours » (plus « Heure par heure »). Points intermédiaires sans libellé « En route » ; seuls « Départ » et « Arrivée » sont nommés.
- Carte d'étape (voyage) : pas de nom de parcours sous le titre de l'étape.
- Blocs communs à recopier tels quels : lien d'équipe (sortie solo), boutons de carte et carte « Météo au départ » (groupe), commentaires (`fmt.py` : `comments_section`). Avatars : LM `#e8590c`, KB `#1971c2`, NP `#2f9e44`, IR `#ae3ec9`.
- En-tête de liste : titre h2 à gauche, compte à droite en 12 px gris (« 2 points », « 2 commentaires »). Titre de carte 16/700, titre de ligne 14/600. Pas de police à chasse fixe.
- Dates : départ d'une carte « ven. 20 nov. · 08:30 » ; « Créé le 3 novembre 2026 » (sans jour de la semaine, comme le web).
- Tuiles : la valeur ne répète pas le libellé (« Étapes 3 », « Dénivelé cumulé 3 340 m »).
- Étape : app bar « Étape 2 sur 3 » + nom du voyage (comme groupe + sortie) ; ni lien vers le voyage ni badges dans le corps (ils sont sur le voyage).
- Voyage : pas de légende des étapes sous la carte ; la couleur est sur chaque carte d'étape.
- Sortie à plusieurs groupes : pas de légende A/B/C sous la carte ; le groupe affiché se choisit par sa carte de groupe.
- « Points du parcours » : seulement quand l'écran montre un seul parcours ; absent des sorties à plusieurs parcours.
- Carte d'étape (voyage) : pas de vignette de carte ; lignes de chiffres et de météo à 14 px gris.
- Ligne de chiffres d'une carte (groupe ou étape) : distance · dénivelé « D+ » · vitesse, 14 px gris, icônes 14 px.
- Ligne météo d'une carte (groupe ou étape) : plage de températures · vent (flèche) · « Pluie N % », 14 px gris ; pas de badges Face/Dos dans la carte.
- Description (si non vide) : juste après le bloc Parcours (carte, profil, revêtement, actions) — avant Personnes inscrites (solo), Météo (sans groupe), Groupes (plusieurs groupes), Étapes (voyage), Points du parcours (parcours).
- Voyage d'une étape : même écran que le voyage à plusieurs étapes, sans section Météo (décision du 2026-11-10, remplace la disposition dédiée).
- Tuiles de chiffres, toujours dans cet ordre : ligne 1 Distance | Dénivelé ; ligne 2 Durée | Vitesse (groupe, étape, sortie solo) ou Étapes (voyage). Une seule ligne s'il n'y a ni durée ni vitesse.
- Segments de l'interrupteur sous la carte : 38 px de haut (44 px avec le cadre). Grappe d'avatars : sans la personne capitaine, déjà nommée au-dessus.
- Sortie à heures différentes, personne inscrite : son heure en gros (« Départ 09:30 »), dessous « Groupe B · premier départ 09:00 » ; « Météo au départ » à son heure.
- Lieux de départ et d'arrivée : liens noirs soulignés qui ouvrent l'itinéraire ; le voyage affiche le lieu de sa première étape dans le bloc de départ.
- Sortie à plusieurs groupes, personne inscrite : bloc de chiffres de son groupe sous le bloc de départ, titré « Votre groupe : B ».
- Cartes de groupe : GPX / FIT / Envoyer vers un appareil seulement sur la carte de son groupe.
- Sortie sans groupe : phrase « Sortie sans groupe, inscription impossible » dans le bloc de départ ; ni bouton ni personnes inscrites.
- Inscription dans une sortie à groupes : « Rejoindre » si je ne suis nulle part, « Changer pour A » sur les autres cartes si je suis déjà inscrit ; sur ma carte, badge « J'y vais » en haut et lien « Quitter le groupe » en bas (jamais à côté du chevron).
- Page groupe, inscrit : coche sur la pastille de mon groupe, badge « J'y vais » à la place de « Rejoindre », « Quitter le groupe » en bas de « Personnes inscrites » (maquette `groupe-inscrit-mobile-cible`).
- Export du parcours : un seul bouton « GPS » (contour, icône appareil) partout, à la place de GPX / FIT / Envoyer vers un appareil. Il ouvre la feuille GPS (`feuille-gps.dc.html`) : « Vers un appareil » (une ligne par service connecté), « Fichier GPX », « Fichier FIT, pour compteur » (Android : enregistrer / envoyer vers une autre app ; iOS : une ligne « Partager »). Sans service connecté : entrée « Connecter un compteur » en bas (`feuille-gps-sans-appareil.dc.html`).
