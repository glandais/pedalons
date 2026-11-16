---
id: LEGAL-24
title: "Stadia Maps déclaré pour la recherche de lieux, par le serveur et depuis l'appareil"
status: done
done: 2026-10-17
---

## Livré

`LEGAL-24` **Stadia Maps déclaré pour la recherche de lieux, par le serveur et depuis l'appareil**
(2026-10-17, contrat `11.5.3` par ailleurs, `OPS-49` et `WEB-99`) — la politique décrivait
Nominatim, interrogé par notre serveur ; depuis `OPS-49` c'est Stadia Maps, et depuis `WEB-99` la
barre de recherche des cartes l'interroge directement depuis l'appareil, ce qui est une donnée
de plus (l'adresse IP de l'utilisateur et le centre de la carte) à déclarer. En parité FR/EN,
`privacy/privacy-policy.{fr,en}.md`, §4 « Affichage des cartes et recherche d'adresses » :
(a) le paragraphe de la recherche de lieux des formulaires nomme Stadia Maps (texte saisi,
langue, adresse IP de notre serveur ; jamais l'identité ni l'IP de l'utilisateur ; cache 24 h
inchangé) ; (b) un paragraphe neuf, sur le modèle de « Fonds de carte et relief », pour la barre
des cartes à navigation libre : interrogée depuis votre appareil, Stadia Maps reçoit votre adresse
IP, le texte tapé et le centre de la carte, rien tant que vous ne tapez rien, responsable de
traitement indépendant (corrigé le même jour : sous-traitant, `LEGAL-25`) ; la ligne « OpenStreetMap Nominatim » des destinataires disparaît et la
ligne « Stadia Maps » porte les deux rôles (serveur / appareil) avec leurs données séparées ; au
§5, la ligne « Calcul d'itinéraires » devient « Calcul d'itinéraires et recherche de lieux », et
dit que la barre des cartes part de l'appareil comme un fond de carte (hôte EU, article 49,
paragraphe 1, point b, inchangés). (c) `privacy/terms-of-service.{fr,en}.md`, § « Cartes et
données géographiques » : le calcul d'itinéraires et la recherche de lieux sont fournis par
Stadia Maps, sur des données OpenStreetMap et d'autres sources
(https://stadiamaps.com/attribution/). En-têtes déjà datés du 17 octobre 2026. Pas de test
automatisé (texte statique ; `PrivacyPolicyPage.test.tsx` simule le rendu Markdown). L'app
mobile embarque `privacy/` comme asset : le texte n'y paraît qu'à la build suivante ; elle
n'appelle ni le géocodage ni la barre. Pas d'e-mail aux membres : la recherche des formulaires
change de prestataire à données égales ; la barre des cartes est une fonction nouvelle, qui
n'envoie rien tant qu'on n'y tape pas, au même titre qu'un fond de carte. **À ne pas défaire** :
si la barre arrive sur une carte cadrée sur une trace, ou si le serveur se met à envoyer un
`focus.point` ou l'IP du client, ce paragraphe se relit d'abord ; la recherche des formulaires
reste décrite comme passant par notre serveur tant que c'est vrai.
