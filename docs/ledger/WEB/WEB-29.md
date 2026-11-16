---
id: WEB-29
title: "Les sélecteurs d'image annoncent HEIC/HEIF, et c'est désormais vrai"
status: done
group: "Défauts d'interface"
done: 2026-09-29
---

## Livré

`WEB-29` **Les sélecteurs d'image annoncent HEIC/HEIF, et c'est désormais vrai** (2026-09-29,
sans changement de code) — `MediaEditor.tsx`, `tiptap/ImageUploadControl.tsx` et
`UserProfilePage.tsx` proposaient `accept="image/*,.heic,.heif"` alors que le backend les
refusait. `API-53` les fait accepter (convertis en JPEG au stockage) : la promesse est tenue,
rien à retirer. Ne pas convertir côté client : le backend le fait pour tous les clients.
