---
id: LEGAL-23
title: "Stadia Maps déclaré pour le calcul d'itinéraires"
status: done
done: 2026-10-17
---

## Livré

`LEGAL-23` **Stadia Maps déclaré pour le calcul d'itinéraires** (2026-10-17, contrat `11.5.2`
par ailleurs, `OPS-48`) — la politique disait « le calcul d'itinéraires [est] auto-hébergé » ;
depuis `OPS-48`, les points placés dans le planificateur, le profil choisi et l'adresse IP de notre
serveur partent chez Stadia Maps (États-Unis). En parité FR/EN, `privacy/privacy-policy.{fr,en}.md` :
un paragraphe au §4 « Affichage des cartes et recherche d'adresses » sur le même modèle que
Nominatim et Open-Meteo (interrogé par notre serveur, jamais votre identité, votre compte ni
votre adresse IP ; un calcul n'est pas conservé chez nous au-delà de la réponse), une ligne
« Stadia Maps (api-eu.stadiamaps.com, serveurs dans l'Union européenne, société établie aux
États-Unis) » dans la liste des destinataires, la phrase sur
l'auto-hébergement réduite au traitement des images et au rendu des cartes, et une ligne
« Calcul d'itinéraires » au §5 (article 49, paragraphe 1, point b : nécessaire au calcul demandé —
remplacé par les clauses contractuelles types le même jour, `LEGAL-25` ;
aucune adhésion au Data Privacy Framework n'est affirmée, faute de l'avoir vérifiée) ; en-tête
daté du 17 octobre 2026. `privacy/terms-of-service.{fr,en}.md`, § « Cartes et données
géographiques » : le calcul d'itinéraires est attribué à Stadia Maps, sur données OpenStreetMap
(ODbL), même date. Pas de test automatisé (texte statique ; `PrivacyPolicyPage.test.tsx` simule le
rendu Markdown). L'app mobile embarque `privacy/` comme asset : le texte n'y paraît qu'à la build
suivante. Pas d'e-mail aux membres : même donnée, même finalité, un prestataire de plus. **À ne
pas défaire** : tout changement de ce que le backend envoie au routeur (nouveau champ, identité,
IP du client) se relit d'abord contre ce paragraphe.
