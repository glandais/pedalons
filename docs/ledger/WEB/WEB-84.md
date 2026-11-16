---
id: WEB-84
title: "Les messages d'erreur de connexion et d'inscription ne passent plus par une clé construite de tout l'enum"
status: done
group: "Agenda et Publications"
done: 2026-10-14
---

## Livré

`WEB-84` **Les messages d'erreur de connexion et d'inscription ne passent plus par une clé
construite de tout l'enum** (14 octobre 2026, sans changement de contrat). i18next-cli 1.75 résout
désormais une constante `as const` importée, donc l'enum `ErrorCode` d'Orval :
`` t(`auth.errors.${code}`, { defaultValue: … }) `` de `LoginForm.tsx` lui faisait réclamer 103
clés `auth.errors.*` (CI rouge sur `i18n:check`, PR dependabot #363), et `pnpm format` les aurait
écrites — en français avec la clé pour valeur, ce qui aurait masqué le repli `errors.api.*`.
`AUTH_ERROR_KEYS` liste les cinq codes que le formulaire formule à sa façon (clés typées, que le
typecheck vérifie à nouveau) ; tout autre code prend `errors.api.<code>`, puis le message
générique. Tests : `pnpm i18n:check`, `pnpm format:check`, `pnpm typecheck`, `npx vitest run`.
**À ne pas défaire** : pas de clé construite d'un enum Orval avec `defaultValue` vers une clé qui
n'existe que pour quelques valeurs — l'extracteur voit maintenant l'enum entier ;
`removeUnusedKeys` reste `false` (`WEB-62`) : l'extracteur ne suit toujours pas tous les cas.
