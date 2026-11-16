---
id: SEC-33
title: "Un saut de ligne dans un nom ne fait plus échouer un courriel"
status: done
done: 2026-10-01
---

## Livré

`SEC-33` **Un saut de ligne dans un nom ne fait plus échouer un courriel** (2026-10-01, contrat
inchangé, relevé en vérifiant V7 sous `SEC-16`) — le client SMTP (Vert.x Mail) refuse un sujet qui
contient CR ou LF, ce qui exclut toute injection d'en-tête mais faisait lever l'envoi : les sujets
interpolent `senderName`, `adName`, `inviterName`, `teamName` et le `subject` des notifications,
et l'API accepte ces noms avec un saut de ligne (ni `@AcceptableText` ni `@Size` ne l'interdisent).
`EmailService.sendEmail` remplace désormais toute suite de sauts de ligne (`\R+`, donc aussi
`U+0085`, `U+2028`) par une espace avant d'envoyer. Choix : au rendu du sujet, seul point commun
à tous les courriels, plutôt qu'une validation de chaque champ de nom — un nom existant ou importé
est couvert aussi, et le corps du message garde ses sauts de ligne. Test :
`EmailServiceTest.lineBreaksInANameBecomeSpacesInTheSubject`, lancé le 1er octobre 2026 (la
classe passe) ; sans le correctif il échoue sur l'erreur même du client (« Single-line text contains
the LF char », puis « Mail not sent »).
