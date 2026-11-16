---
id: LEGAL-25
title: "Stadia Maps relu contre son avenant de traitement des données : sous-traitant, clauses contractuelles types"
status: done
done: 2026-10-17
---

## Livré

`LEGAL-25` **Stadia Maps relu contre son avenant de traitement des données : sous-traitant, clauses
contractuelles types** (2026-10-17, sans changement de contrat d'API) — `LEGAL-23` et `LEGAL-24`
avaient décrit Stadia Maps sans avoir lu son DPA (https://stadiamaps.com/legal/data-processing-addendum/,
version du 18 mars 2026, relue le 17 octobre 2026), qui contredit deux affirmations. Le DPA fait
partie des conditions d'utilisation et s'applique dès le premier appel, sans signature (préambule,
« Acceptance », CGU §4). Stadia Maps y est **sous-traitant** du client responsable de traitement
(§2.1(a)), y compris pour les utilisateurs finaux et leurs adresses IP (annexe I.B), donc aussi
pour la barre de recherche appelée depuis le navigateur ; il ne reste responsable que pour ses
propres finalités : facturation, fraude, sécurité, obligations légales (§2.2). Les transferts hors
UE reposent sur les **clauses contractuelles types, module 2** (§2.3, §6.2(a) ; droit et
juridiction de l'État membre du client) ; le Data Privacy Framework n'y est qu'une possibilité
future (§6.4), et aucune adhésion de Stadia n'a été trouvée. Journaux de requêtes : environ 7 à
14 jours (annexe I.B). L'hôte européen garantit la connexion (Francfort, Paris), pas tout le
traitement : le DPA autorise un traitement partout où Stadia ou ses sous-traitants opèrent
(§6.1), et cinq de ses huit sous-traitants ultérieurs sont américains (dont Grafana et Sentry).
En parité FR/EN, `privacy/privacy-policy.{fr,en}.md` : l'entrée Stadia Maps quitte la liste des
fournisseurs de cartes pour le tableau des sous-traitants techniques (règle de `LEGAL-5` : nous le
choisissons et il lit les données), sous le nom « Stadia Maps, Inc., États-Unis ; point d'entrée
européen api-eu.stadiamaps.com, serveurs à Francfort et à Paris », avec la durée des journaux ; au
§4, la barre de recherche n'est plus « responsable de traitement indépendant » mais sous-traitant
de Pedalons (article 28), et les demandes des personnes nous sont adressées (section 7) ; au §5,
l'article 49, paragraphe 1, point b, cède la place aux clauses contractuelles types, avec la
mention des sous-traitants ultérieurs américains. Pas de test automatisé (texte statique).
**À ne pas défaire** : ne pas revenir à l'article 49 (une dérogation pour transferts
occasionnels, alors qu'une garantie de l'article 46 existe) ; ne pas affirmer d'adhésion au DPF
tant que Stadia ne s'en prévaut pas ; relire le DPA et https://stadiamaps.com/legal/subprocessors/
quand Stadia les modifie (§9.5 : modification unilatérale avec avis ; la page des sous-traitants
laisse au client le soin de la surveiller). La version du 9 novembre 2026 de la politique de
Stadia ne touche que les données du compte client, pas celles des utilisateurs.
