---
id: WEB-15
title: "Modale « Contacter le vendeur »"
status: done
group: "La recette web, automatisée"
---

## Livré

`WEB-15` Modale « Contacter le vendeur » : les quatre issues, brouillon conservé sur 429 et
500, un seul message (le contact coupe le toast global, `skipErrorToast`), `Alert` persistante
sur la page pour le succès et `AD_CONTACT_OPTED_OUT`, bouton absent sur sa propre annonce, 9 et
2 001 caractères refusés sans appel réseau ; le mail relayé porte l'auteur en `Reply-To` et
ne l'imprime jamais. — `ad-contact.e2e.ts`. *Le 500 est simulé : mailpit accepte tout, la
pile ne sait pas faire échouer un envoi. Les clés `en` ont été vérifiées à la lecture, la
suite tourne en `fr`.*
