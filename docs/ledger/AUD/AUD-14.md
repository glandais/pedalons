---
id: AUD-14
title: "`@Transactional` retiré des resources"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-14` | Backend | B4 | Important | **`@Transactional` retiré des resources** (2026-09-30) — il était posé sur dix classes de `api/` : au niveau de la classe sur les quatre `*CommentResource`, sur la méthode de mise à jour de `RideResource`, `PostResource`, `TripResource`, `AdResource`, `TeamResource` et `TeamMemberResource`. Chacune de ces méthodes n'appelle **qu'une** méthode de service, elle-même `@Transactional` et qui construit son DTO dans la transaction (`CommentService.listComments`/`createComment`/`deleteComment`, `RideService.updateRide`, `PostService.updatePost`, `TripService.updateTrip`, `AdService.updateAd`, `TeamService.updateTeam`, `MembershipService.updateMemberRole`) : aucune ne compose plusieurs appels qui devraient être atomiques, donc aucune n'a été gardée. La frontière de transaction est la méthode de service ; une resource qui aurait besoin de plusieurs appels atomiques doit recevoir une méthode de service qui les fait, pas une transaction de resource. Deux règles d'`ArchitectureTest` le gardent (`resources_should_not_be_transactional`, `resource_methods_should_not_be_transactional`, vérifiées en réintroduisant l'annotation). Couvert par les tests de ressource des classes touchées, verts : `AdResourceTest`, les quatre `*CommentResourceTest`, `CommentPaginationTest`, `CommentCountTest`, `PostResourceTest`, `RideResourceTest`, `RideGroupLeaderTest`, `TeamMembershipResourceTest`, `TeamResourceTest`, `TripResourceTest` |
