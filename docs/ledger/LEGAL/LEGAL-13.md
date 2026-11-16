---
id: LEGAL-13
title: "Gouvernance : âge déclaré, violation de données, responsable unique"
status: done
done: 2026-09-29
---

## Livré

`LEGAL-13` **Gouvernance : âge déclaré, violation de données, responsable unique** (2026-09-29)
— quatre décisions ([opportunités](../../plans/2026-07-25-privacy-improvement-opportunities.md) #15 à
#17 et #19). **Âge** : la case d'inscription dit désormais « J'ai au moins 16 ans et j'accepte… »
(`auth.register.acceptTerms` au web, `auth.terms.accept` au mobile) ; la déclaration est horodatée
par le `termsAcceptedAt` existant, sans champ ni changement de contrat. Le §10 de la politique le
dit, ainsi que le §3 des CGU, et précise qu'on ne vérifie rien et qu'on ne demande pas la date de
naissance : la demander serait une collecte de plus. **Violation** : le §9 s'engage à notifier la
CNIL sous 72 h et les personnes concernées si le risque est élevé (art. 33 et 34, dus de toute
façon). **Responsable** : le §12 dit qu'il est le même sur tous les sites hébergés, y compris le
domaine propre d'un club, et que les clubs ne sont pas responsables du traitement. **Admins
plateforme** : texte du §4 inchangé (un seul admin, le responsable lui-même), pas de journal
(`LEGAL-16`) ; responsable par domaine écarté (`LEGAL-17`). Test : `flow-account.e2e.ts` (libellé
de la case et message d'erreur). Les comptes créés avant n'ont pas déclaré leur âge : c'est
admis, la politique ne prétend pas le contraire.
