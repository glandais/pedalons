---
id: WEB-83
title: "Le libellé d'un groupe ne répète plus son préfixe"
status: done
done: 2026-11-12
---

## Livré

`WEB-83` **Le libellé d'un groupe ne répète plus son préfixe** (12 novembre 2026, commit `69daea7e8`, avec `WEB-167` ; contrat d'API inchangé) — « Groupe Groupe intermédiaire » venait de `rides.group.title` posé devant tout nom. `utils/groupTitle.ts` est la seule fonction qui l'appelle encore : « Groupe B » devant un nom d'un ou deux caractères, le nom nu sinon. Appelée par l'en-tête et le partage de `RideGroupPage`, le fil d'Ariane (`useBreadcrumbData.ts`), le titre de page (`routeMeta.ts`) et les cartes. Test : `utils/groupTitle.test.ts` ; `routes-render.e2e.ts` et `routeMeta.test.ts` n'attendent plus le libellé fautif. **À ne pas défaire** : la règle retenue est « nom court » (décision du 12 novembre 2026, KIT §9), pas « le nom commence par Groupe » ; c'est la même que `group_title.dart` dans l'app. Le nom envoyé aux services GPS (`GpsSyncNames.autoName`) pose le nom du groupe nu : voir `API-125`.
