---
id: LEGAL-19
title: "La mesure d'audience du site déclarée"
status: done
done: 2026-10-15
---

## Livré

`LEGAL-19` **La mesure d'audience du site déclarée** (2026-10-15, texte rédigé, contrat
inchangé ; **pas encore en ligne** : il part avec le déploiement de l'étape 5 du plan, `OPS-41`,
et la date d'en-tête, « 15 octobre 2026 », est à recaler au jour de cette mise en ligne) — plan
[`2026-10-15-web-analytics.md`](../../plans/2026-10-15-web-analytics.md) (§5, étape 4 du §8). La
politique promettait « aucun outil d'analyse ou de suivi » et ne prévoyait aucune opposition :
elle serait devenue fausse le jour où `WEB-90` s'allume. En parité FR/EN
(`privacy/privacy-policy.{fr,en}.md`) : une sous-section « Mesure d'audience du site » au §1
(site seulement, pages vues et non visites, sans cookie ni identifiant, IP non conservée, pays
seul déduit sur nos serveurs, type de page et, pour une page d'équipe, l'identifiant de l'équipe
« celui de son adresse sur pedalons.fr », équipes privées comprises, des compteurs et non une
ligne par page vue, un seul lecteur), la liste du §2, l'intérêt légitime exempté au §3 et la
phrase « aucun outil d'analyse » réécrite, l'outil hébergé par nos soins au §4, 24 mois au §6 (statistiques
agrégées comprises), les requêtes de mesure absentes des journaux serveur, les statistiques non
sauvegardées, l'opposition au §7 (DNT et GPC, seul moyen global ; interrupteur sur le site,
Profil → Confidentialité ou la page Confidentialité, **pour ce navigateur et ce site
uniquement** ; l'application ne mesure rien), la clé `pedalons-analytics-optout` et « remplit
les conditions d'exemption » au §8. Conditions CNIL relues sur cnil.fr le 15 octobre 2026
(délibérations 2020-091 et 2020-092, page des outils de mesure d'audience du 4 juillet 2025 et
son outil d'auto-évaluation) ; la démonstration condition par condition est le tableau du §5.1
du plan, à tenir à jour. Pas de test automatisé (texte) : parité ligne à ligne vérifiée par
`diff <(grep -c '' …)`. **À ne pas défaire** : la politique est en ligne **avant** que le drapeau
soit posé en prod ; annonce sans e-mail, parce que le site n'est pas encore ouvert au public,
**à condition** qu'au déploiement aucun membre réel n'ait accepté la politique actuelle (vérifié
en base, `OPS-41`), sinon l'e-mail du §11 à chaque membre avant l'activation ; toute évolution
du compteur (`WEB-90`) qui enverrait davantage se relit d'abord contre ce texte et le §5.1 du
plan ; l'exemption repose, pour les comptes exacts, sur l'analyse d'anonymat consignée avec
`WEB-90`.

`LEGAL-19` **Suite : la politique en ligne** (2026-10-16, contrat inchangé) — La politique réécrite par `LEGAL-19` (commit `0ea379fd`) est en production : constaté le
16 octobre 2026 à la relecture du ledger, avec la prod sur `ac130fc5` (dont `0ea379fd` est un
ancêtre). `https://www.pedalons.fr/confidentialite` sert « Dernière mise à jour : 15 octobre 2026 »,
et GoatCounter tourne (`pedalons-prod_goatcounter` 1/1, pages vues comptées). La mention « pas
encore en ligne » de l'entrée d'origine est donc dépassée ; la date d'en-tête est restée celle du
15 octobre. Pas de test automatisé (texte) : vérifié en lisant la page servie. Ce qui reste de la
mise en service — confirmer par écrit la précondition du §5.3 du plan (aucun membre réel n'avait
accepté la politique précédente), consigner les vérifications de l'étape 6, relire les chiffres au
bout d'un mois — est sous `OPS-41`. À ne pas défaire : toute évolution du compteur (`WEB-90`) se
relit d'abord contre ce texte et le §5.1 du plan.
