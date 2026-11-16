---
id: MOB-25
title: "Annonces : carte de localisation et contact du vendeur"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-25` **Annonces : carte de localisation et contact du vendeur** (29 septembre 2026) — la
carte d'une annonce localisée montre son lieu, la légende « Localisation approximative », un
secteur sur une carte qui ne dessine aucun point (ni repère, ni départ, ni arrivée, ni
surcouche), centrée sur la cellule floutée à moins d'un kilomètre du point saisi et jamais
dessus ; une annonce sans lieu n'a ni en-tête « Localisation », ni carte, ni secteur. Le contact :
9, 2 001 et dix espaces laissent « Envoyer » désactivé, 10 et 2 000 l'activent ; un envoi réussi
ferme la feuille et remplace le bouton par la confirmation, un seul mail relayé porte le
brouillon, `Reply-To` l'acheteur, `From` jamais l'acheteur, aucune des deux adresses dans le
corps, et l'annonce lue par l'API ne porte pas l'adresse du vendeur ; `AD_CONTACT_OPTED_OUT`
(vendeur non contactable) ferme la feuille, pose le bandeau à la place du bouton et n'envoie
rien ; le 11ᵉ message de l'heure (`RATE_LIMITED`, `Retry-After` 3 600) dit « Réessayez dans
1 heure », garde le brouillon, passe le bouton à « Réessayer » et la page garde « Contacter le
vendeur » — `ad_location_map_test.dart`, `ad_contact_test.dart`,
`ad_contact_opted_out_test.dart`, `ad_contact_rate_limited_test.dart`. *Non couvert :
`DELIVERY_FAILED` (500) — mailpit accepte tout, la stack réelle ne sait pas faire échouer le
relais sans un crochet de test (le web le simule par `page.route`) ; le rendu en pixels du
secteur (le web mesure la teinte du canvas, ici seul l'arbre de widgets est vérifié).*
