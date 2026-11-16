---
id: ISSUE-7
title: "Un bug se signale sans description (API 6.1.0)"
status: done
done: 2026-09-29
---

## Livré

`ISSUE-7` **Un bug se signale sans description (API 6.1.0)** (2026-09-29) —
`FeedbackRequest.message` devient facultatif pour un `BUG` : qui tombe sur une erreur ne sait
pas forcément ce qui s'est passé, et le contexte, l'erreur jointe et le journal parlent pour lui.
Une `SUGGESTION` l'exige toujours (`FeedbackService.submit`, 400 `VALIDATION`) ; un message
donné garde ses bornes 10–5000. Colonne `feedback_reports.message` nullable (V48). Sans message,
l'issue est titrée par l'erreur (`TypeError: …`), à défaut par l'écran, et son corps dit « Pas de
description du membre ». Web et app : le champ est marqué facultatif pour un bug, « Envoyer »
s'active champ vide, un champ vide part en `null`. Couvert par
`FeedbackResourceTest.feedback_bugWithoutMessage_isPublishedUnderItsError`,
`…suggestionWithoutMessage_isRejected` et `feedback_sheet_test.dart` (« un bug part sans
message, une suggestion non »).
