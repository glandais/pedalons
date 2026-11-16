---
id: WEB-73
title: "Les clés de traduction sont typées"
status: done
group: "Outillage"
done: 2026-10-12
---

## Livré

`WEB-73` **Les clés de traduction sont typées** (2026-10-12, sans changement de contrat) —
`t()` n'était pas typé : une clé absente s'affichait brute, et le `satisfies` des clés
construites ne contrôlait que le type de la variable. `frontend/src/i18n/i18next.d.ts` déclare
`CustomTypeOptions` sur `fr/common.json` (`keySeparator: false`, les clés étant plates) : tout
appel `t()` est vérifié par `pnpm typecheck`, clé littérale comme clé construite d'une valeur
typée — TypeScript résout les enums Orval, que l'extracteur d'i18next-cli ne sait pas lire
(`WEB-62`). `TranslationKey` (`src/lib/i18nUtils.ts`) type les clés rangées pour plus tard
(`labelKey` de `profileNav.ts` et `notificationFamilies.ts`, `i18nKey` des fils d'Ariane de
`routes.types.ts`) et `tRegister` la rend. `rendezvousMention` et `formatPublicationSpan`
prennent une `TFunction` ; leur test lit une vraie instance i18next (`createServerI18n`) au lieu
d'un bouchon qui réimitait l'interpolation. `src/i18n/catalogues.test.ts` tient l'anglais aux
mêmes clés que le français, que le typage ne couvre pas, et chaque catalogue aux seules formes
plurielles de sa langue (plus `_zero`, propre à i18next) : il a fait retirer 16 clés `_many` de
`en/common.json`, que l'anglais ne lit jamais. Typecheck de 3,6 s à 5,8 s. Tests :
`catalogues.test.ts`, `rendezvous.test.ts`, `npx vitest run` (411), `pnpm typecheck`, `pnpm lint`.
À ne pas défaire : **une clé rangée dans une variable ou un champ est une `TranslationKey`,
jamais une `string`** ; ne pas élargir `CustomTypeOptions` ni caster vers `Parameters<typeof t>[0]`
pour faire passer un appel. Un `defaultValue` coupe le contrôle de l'appel : il reste réservé aux
vrais replis (six appels, dont `LoginForm`, qui tente `auth.errors.<code>` puis
`errors.api.<code>`).
