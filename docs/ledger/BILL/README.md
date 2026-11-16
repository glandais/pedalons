# BILL — Monétisation

Contexte des entrées `BILL-n` : la prose qui entourait ces entrées dans les deux anciens fichiers du
ledger. Les entrées elles-mêmes sont à côté, une par fichier ; leur liste est dans
[`LEDGER_NEXT.md`](../../LEDGER_NEXT.md) et [`LEDGER_DONE.md`](../../LEDGER_DONE.md).

## Reste à faire : contexte

Le plan est [`plans/2026-10-17-monetisation.md`](../../plans/2026-10-17-monetisation.md) : qui paie
(l'équipe, jamais le membre), trois paliers (Peloton gratuit ≤ 25 membres, Club 80 €/an HT,
Fédération sur devis), **abonnement annuel seul, facturé et encaissé par Qonto** (facture émise
par l'API, payée par virement, carte plus tard), un moteur d'abonnement écrit chez nous
(renouvellement, relances, grâce), et une seule fonction `TeamEntitlements` qui combine
l'abonnement avec les drapeaux de gouvernance existants (`enableRoutePlanner`,
`addMemberAllowed`…). **Presque rien n'est décidé** : seuls le seuil du gratuit (Q3, 25 membres) et les équipes offertes
(Q7) sont tranchés, avec les limites de l'offre gratuite livrées sous `BILL-10` ; les autres
questions du §11 sont au propriétaire.

## Livré : contexte

Le plan de paiement [`plans/2026-10-17-monetisation.md`](../../plans/2026-10-17-monetisation.md) reste
une proposition (`BILL-1`). Livré avant lui : les limites de l'offre gratuite.
