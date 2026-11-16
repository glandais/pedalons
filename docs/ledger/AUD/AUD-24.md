---
id: AUD-24
title: "Pas de `slow_down` (RFC 8628 — le backend n'en émet aucun à ce jour, voir `AUD-27`)…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Thème | Audit | Gravité | Constat |
|---|---|---|---|---|
| `AUD-24` | Karoo | K9 | Important | Pas de `slow_down` (RFC 8628 — le backend n'en émet aucun à ce jour, voir `AUD-27`) : `auth/DeviceCodeLogin.kt` termine la connexion en erreur sur tout code 400 autre que `AUTHORIZATION_PENDING` et `TOKEN_EXPIRED`, et un `interval` de 0 interroge en boucle serrée (aucun test ne le couvre). K7 est livré sous `AUD-34`, K13 sous `AUD-32` ; K10 est écarté sous `AUD-33` |
