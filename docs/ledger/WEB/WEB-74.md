---
id: WEB-74
title: "Les codes d'erreur de l'API traduits comme des `ErrorCode`"
status: done
group: "Outillage"
done: 2026-10-12
---

## Livré

`WEB-74` **Les codes d'erreur de l'API traduits comme des `ErrorCode`** (2026-10-12, sans
changement de contrat) — `apiErrorCode` (`src/lib/apiError.ts`), le toast d'`axiosInstance`,
`BiketeamMigrationPage` (dont `TERMINAL_CODES`, désormais un `Set<ErrorCode>`) et
`AcceptInvitationPage` manipulaient le code comme une `string` (`'errors.api.' + code`) ; les
casts `as Parameters<typeof t>[0]` de `LoginForm` sont retirés. Typés, ils ont fait trouver sept
codes du contrat sans traduction, ajoutés en français et en anglais :
`BIKETEAM_JOB_NOT_FOUND`, `DECRYPTION_FAILED`, `ENCRYPTION_FAILED` (« Erreur interne du
serveur », comme `INTERNAL_ERROR`), `FILE_DETECTION_FAILED`, `FILE_TYPE_REJECTED`,
`GPS_TOKEN_EXCHANGE_FAILED`, `ROUTE_PLANNER_DISABLED`. Couvert par `pnpm typecheck` : un code
ajouté à l'enum `ErrorCode` sans clé `errors.api.<code>` dans `fr/common.json` le fait échouer.
À ne pas défaire : le code d'erreur reste un `ErrorCode` de bout en bout, jamais une `string`.
