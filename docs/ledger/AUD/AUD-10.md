---
id: AUD-10
title: "Aucune procédure de rotation des secrets dans `OPERATIONS.md` (clés JWT, `ENCRYPTION_KEY`, mots de passe…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Thème | Audit | Gravité | Constat |
|---|---|---|---|---|
| `AUD-10` | Docker | I19 | Important | Aucune procédure de rotation des secrets dans `OPERATIONS.md` (clés JWT, `ENCRYPTION_KEY`, mots de passe postgres et MinIO, SMTP, compte de service FCM, clé age). La rotation d'`ENCRYPTION_KEY` doit **rechiffrer** les jetons des services GPS, que la synchronisation automatique (`API-120`) utilise en continu : une clé changée sans rechiffrement les rend illisibles |
