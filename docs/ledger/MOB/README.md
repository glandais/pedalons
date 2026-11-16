# MOB — Application mobile

Contexte des entrées `MOB-n` : la prose qui entourait ces entrées dans les deux anciens fichiers du
ledger. Les entrées elles-mêmes sont à côté, une par fichier ; leur liste est dans
[`LEDGER_NEXT.md`](../../LEDGER_NEXT.md) et [`LEDGER_DONE.md`](../../LEDGER_DONE.md).

## Reste à faire : contexte

### Recette sur une application qui tourne

Rien de ce qui suit n'est couvert par les tests automatisés — soit parce que c'est du rendu, soit
parce que ça dépend d'un vrai fournisseur (mail, tuiles, GPS), soit parce que c'est un comportement
de première ouverture. `flutter analyze` est propre, les tests mobiles (`mobile/check.sh`) passent :
ce qui suit est ce qu'ils ne peuvent pas dire.

À faire une fois **en clair** et une fois **en sombre** (le mode sombre est *dérivé*, aucune maquette
ne le fournit : c'est là que les erreurs de contraste apparaissent), sur un compte membre de
`n-peloton` *et* sur `gaby` (l'échantillon d'états vides). Les volumes diffèrent selon la base : la
base locale migrée compte 1 999 membres, 2 585 parcours et ~665 sorties sur `n-peloton` (7 membres
sur `gaby`) ; en prod, au 16 octobre 2026, `n-peloton` compte 2 696 parcours et 557 sorties mais
5 membres seulement — la migration biketeam (11-15 octobre) n'a pas apporté ses membres — et `gaby`
1 membre et 106 parcours.

**Passe partielle du 27 juillet 2026** : audit de code complet sur les douze écrans, plus un passage
en direct sur simulateur (thème sombre, compte `n-peloton` — un seul compte suffit, il est admin des
deux équipes `n-peloton` et `gaby`). Un défaut trouvé et corrigé (`MOB-21`, le `GROUP_FULL` ne
nommait pas le groupe). Restent à faire en conditions réelles, non couvrables par la lecture de
code : bascule de fuseau horaire sur l'appareil, ouverture d'un deeplink app tuée, mesure de fps
(parcours et liste de 200), rendu du text scaling ×1,3/×2,0, et la capture d'écran de preuve pour le
jeton ICS. Thème clair et compte `gaby` pas repassés en revue depuis.

**Recette du 4 octobre 2026** (prod, équipe `gaby-test1`, jeu de données « Recette — … », clair et
sombre) : seize entrées livrées, trois défauts mineurs (`MOB-44` à `MOB-46`, corrigés le même jour).
Restaient celles qu'il faut un gros volume pour juger (`MOB-5`, `MOB-13`, `MOB-20`), `MOB-15` pas
faite, et le 500 du contact vendeur (`MOB-47`). Depuis l'import de `n-peloton` en prod, `MOB-5` et
`MOB-20` se recettent en prod ; `MOB-13` reste sur la base locale migrée.


### Couverture e2e Patrol — ce que les tests ne couvrent pas encore

`mobile/patrol_test/` couvre les P0 de l'audit de couverture e2e (`WEB-26`) transposés à l'app et
les scénarios livrés depuis (77 fichiers de test au 16 novembre 2026 ; la liste à jour est dans
`mobile/patrol_test/README.md`, « Coverage »). Ce que chacun laisse de côté est dit dans son entrée
livrée. Hors périmètre, parce que l'app ne l'a pas : la connexion par code e-mailé (`requestOtp` / `verifyOtp` d'`auth_provider.dart`
n'ont aucun appelant d'écran).


## Livré : contexte

### Recette sur une application qui tourne — 4 octobre 2026

Passe manuelle sur la prod, compte administrateur, en clair et en sombre, dans l'équipe `gaby-test1`
garnie pour l'occasion d'un jeu de données « Recette — … » créé par l'API : sorties à trois groupes
(dont un mené par un autre membre et un à une place), du jour, sans meneur, passée et annulée ; un
col synthétique et treize parcours d'étape ; un voyage de 13 étapes et deux voyages « Fuseaux » ;
une publication à liens et tableau, une autre faite de pièces jointes seules (image 1920 × 1080 et
PDF de 12 Mo) ; trois annonces ; une page d'équipe et un « à propos » à pièce jointe seule. Pas de
test automatisé : ce qui suit est ce que les tests ne savent pas dire. Trois défauts mineurs
relevés, `MOB-44` à `MOB-46`. Restent ouvertes `MOB-5`, `MOB-13`, `MOB-15`, `MOB-20` et `MOB-47` (le 500 de `MOB-12`).

### Défauts trouvés par la recette du 4 octobre 2026

Corrigés le 4 octobre 2026, contrat inchangé. Les deux défauts de navigation n'en font qu'un.

### Erreurs remontées automatiquement — 6 octobre 2026

Issues du dépôt `pedalons-feedback`, corrigées le 6 octobre 2026, contrat inchangé.

### Couverture e2e Patrol

Écrits le 29 septembre 2026 par-dessus les P0 de l'audit de couverture e2e (`WEB-26`), un test
Patrol par scénario sous `mobile/patrol_test/` (tableau « Coverage » de son README). Ils ont trouvé
sept défauts de l'app, tous corrigés le même jour et nommés dans les entrées qui les ont trouvés,
plus un huitième hors scénario : un appui au-dessus d'une `PdlSheet` ne la refermait pas (la feuille
couvrait la barrière modale, dd207d81). Ce que chaque entrée laisse de côté est dit en « Non
couvert » ; les tests ne tournent qu'en local (`MOB-37`).







