# Pédalons - Product Sheet

## Overview

**Pédalons** is a multi-tenant cycling team platform for clubs and groups to organize rides, share routes, coordinate events, and build community.

**Target audience:** Cycling clubs, informal riding groups, tour organizers, bike shops, corporate teams.

---

## Core Features

### Team Management

| Feature | Description |
|---------|-------------|
| Multi-tenant architecture | Complete team isolation |
| Custom profiles | Name, logo, description, custom pages |
| Visibility control | Team (members only), unlisted (anyone with the link) or public (listed) — for teams and for each item. A members-only team publishes an item outside its members only once the platform admin has allowed it; ads always stay members-only. Member names never reach a non-member — the count only |
| Role-based access | Member, Organizer, Admin |
| Joining & invitations | Join an open public team, be added by an admin, or be invited by e-mail (people without an account too) or by link, on the web and in the app |
| Team tags | The team defines its own tags, labels its rides, routes, posts and ads with them, and lists can be filtered by tag (web and app) |
| Team pages | Custom content with markdown and media |
| Configurable features | Enable/disable rides, routes, trips, posts and marketplace; member directory (off by default); interactive route planner (on for a new team, switched by the platform admin) |
| Team dashboard | One page per team, by role: next ride, what awaits the organizers and admins; partly open to visitors |
| Getting started | A person with no team is offered to find or create one; a newly created team is offered its first steps |
| Agenda & publications | Rides and trips in an agenda ("Upcoming", "Earlier", "All"), posts in their own list; thumbnails, rows or map |
| Team time zone | Events are entered and shown in the team's time zone |
| Member directory | Team roster, opened to members by the admins |
| Team webhook | Announcements posted to Slack, Discord, Mattermost or any https address |
| Domain aliases | A team served on its own hostname |
| Free tier | A new team is free: up to 25 members (pending invitations count) and 20 saves a month of a route drawn in the planner (creations and edits; copies and GPX imports are not counted). Outside any unlocked team, 10 saves a month per person in the GPX tools. The platform admin unlocks a team by hand; teams that existed before the limits are unlocked. No payment yet |

### Rides & Events

| Feature | Description |
|---------|-------------|
| Ride scheduling | Date, time, location, description |
| Multiple pace groups | Named groups (A/B/C or any name), each with its own speed, start time, route, capacity, optional leader and page; one tap to change group |
| Route linking | Attach GPX routes to rides |
| Participant management | Registration in one group per ride, capacity limits per group, attendee lists for members (others see the count only) |
| Start/end places | Predefined meeting points |
| Draft & cancellation | Prepare a ride as a draft before publishing; cancel a published ride, which stays listed as cancelled and notifies its participants |
| Ride templates | Reusable templates for recurring rides, with numbering of the rides created from them |
| Weather forecast | Forecast at the start and along the route of the group one joined: wind on the track and the profile, weather at checkpoints, estimated arrival |

### Routes & GPX

| Feature | Description |
|---------|-------------|
| GPX upload | Import from any cycling app |
| Route planner | Draw and edit a track on the map, by mouse or touch: choice of routing (standard, or the team's usual roads for road, gravel and MTB, with a silent fallback to standard), avoid hills, traffic or main roads, straight lines, GPX import, live elevation profile (when enabled for the team) |
| Route generator | Proposes up to three routes from a start, an arrival, a direction and a distance, with one slider from the team's usual roads to discovery and a target share of off-road paths; worldwide coverage. On the web, and in the app (new) |
| Route retouch | On a route's page, aim it at a new distance or move its finish: only one section is re-routed and the rest of the track stays as it was; up to three proposals with the changed section highlighted, nothing saved until the user saves (web and app, new; someone who cannot edit the route gets a new route or a copy) |
| Duplicate | Copy a route and edit the copy |
| Auto-calculated metrics | Distance, elevation gain/loss, hilliness |
| Surface classification | Road, gravel, MTB, mixed — and the detailed surface along the track, on the map and the profile |
| Typed waypoints | Regroup point, water, café, summit, danger… shown on the map, the profile and in a list |
| Map visualization | Interactive route display with kilometre markers, slope, surface or weather colouring, "Road" and "Gravel" backgrounds, light or dark; place search, and the framing kept in the link on the web |
| Advanced filtering | By distance, elevation, terrain |
| GPS menu | On a route, ride, group or stage page: download the GPX or FIT file, or send the route to Garmin Connect, Hammerhead (Karoo) or Wahoo, with the state of the automatic sending |
| Thumbnail generation | Auto-generated previews of routes, rides and trips, light and dark |
| GPX tools | Outside any team: preview a GPX file, merge 2 to 10 files, draw a track, share or duplicate a preview, or copy a team route into one's own previews to edit it (10 planner saves a month per person) |
| GPX track departure and weather | In the GPX tools, a departure date and time (local to the track's start point) and an optional average speed give the forecast along the track, up to 7 days ahead |

### Multi-Day Trips

| Feature | Description |
|---------|-------------|
| Trip management | Multi-stage cycling events |
| Stage configuration | Individual routes and places per stage, optional average speed |
| Stage weather | Forecast at the start of each stage and along its route, estimated arrival |
| Trip participation | Registration for complete trips |

### Posts & Communication

| Feature | Description |
|---------|-------------|
| Team announcements | News and updates |
| Rich content | Rich-text editor (the same on the web and in the app), images, attachments |
| Visibility options | Team-only, unlisted or public |

### Marketplace (Ads)

| Feature | Description |
|---------|-------------|
| Listing types | Sale, rental, wanted |
| Pricing | Fixed price or rental periods |
| Search & filter | By type, date, price, keywords, tags and distance; sortable |
| Privacy by design | Members only; position blurred to about 1 km and shown as a sector, never a pin; no contact field — buyers write through an e-mail relay, and the seller answers them directly |

### Additional Features

- **Comments**: Threaded discussions on rides, routes, posts, trips and trip stages
- **Places directory**: Meeting points with geolocation
- **Unified feed**: Combined publication stream across teams
- **Notifications**: In-app inbox, mobile push and web push (in the browser, or the site installed as an app), with per-type preferences; the e-mail channel is built but not yet switched on in production
- **Moderation**: Reporting of content and members, blocking, publication filter for abusive terms
- **Problem reports**: "Report a problem" and automatic error reports, filed as issues in a private GitHub repository

---

## User Management

### Roles & Permissions

| Role | Capabilities |
|------|--------------|
| **Member** | View, participate, comment |
| **Organizer** | Create/edit rides, routes, posts, places |
| **Admin** | Manage members, roles and team settings, delete the team |

Above the teams, the platform admin unlocks a team's free-tier limits, allows a members-only team
to publish items by link, and sees the platform statistics.

A team always keeps at least one admin: the last one must name another before leaving the team or
deleting their account.

### Authentication

- Sign-up with email, password and acceptance of the terms, then email verification
- Email + password, with password reset by email
- Email + OTP (one-time password sent by email)
- Passkeys / WebAuthn support
- Device Code Flow (RFC 8628) for GPS devices (Karoo, Garmin)
- OAuth 2.0 (authorization code + PKCE) for third-party applications, listed and revoked under
  Profile > Devices and services
- User profiles with avatars

### Personal Data

- Self-service data export (ZIP archive emailed as a link), on the web and in the mobile app
- Self-service account deletion: personal data erased immediately (credentials, memberships, upcoming registrations, ads, comments, notifications, avatar); the rides, routes and posts created for a team are kept and credited to "Ancien membre", and a comment others replied to stays as an empty placeholder

---

### Key Technical Features

- Multi-tenant by domain: each hostname is its own platform, with its own teams and accounts (the same e-mail can exist on two domains) and its own passkey and e-mail settings
- TSID (time-sortable unique IDs)
- Auto-generated URL slugs with redirect on change
- Multi-language support (EN/FR)
- Dark mode
- Platform admin panel (web): domains, teams and users, free-tier unlocks, permission for members-only teams to publish by link, thumbnail regeneration, and statistics in counts only (sign-up activation by week, usage of the platform)
- Cookie-free audience measurement of the website (self-hosted, same origin, no third party)
- OpenAPI contract served at `/api/openapi`

---

## Asset Management

| Type | Usage |
|------|-------|
| Logo | Team branding |
| Image | Media content |
| Attachment | Downloadable files (documents, PDFs…; videos are refused, as they carry location data) |
| GPX/FIT | Route data: the original GPX kept, a filtered GPX and a FIT derived from it |
| Thumbnail | Previews of routes, rides and trips, light and dark |

---

## Implemented Integrations

- **Mobile app** (Flutter, iOS/Android) — teams, rides, trips, routes, posts, ads, comments, calendar, notifications, weather; reading and writing: create and edit rides, ride templates, trips, posts, ads and routes (GPX upload or drawn on the map), create and manage a team (settings, members, invitations, places, tags, pages, reports); invitation and web links open the app; the route generator and route retouch (new); the GPX tools, and a .gpx received from another app opens in Pédalons (new). On the App Store; on Android, closed testing on Google Play and a signed APK for each beta
- **Garmin Connect IQ app** — upcoming rides, ride and route browsing, FIT download on Edge devices; on the Connect IQ Store
- **Hammerhead Karoo extension** — upcoming rides and the stages of the trips one joined, ride and route browsing, sync
- **GPS device sync** — upload routes to Garmin Connect, Hammerhead (Karoo) and Wahoo, on demand or automatically for the rides and trip stages a member joined
- **Calendar sync** — iCal feed export, at the start time of the member's own group
- **External API** — the site's own API, with its contract and OAuth 2.0, usable by a third-party application
- **Third-party services** — Stadia Maps (maps, geocoding, routing), Open-Meteo (weather), the osm-route-details engine (route generator, retouch and team routing), team webhooks (Slack, Discord, Mattermost, any https address), mobile and web push

## Roadmap Potential

- Team routing: richer routing data and road types read from the engine's graph
- A heat map of the team's routes
- Favourite routes and alternative routes for trip stages
- Paid tiers (a proposal, nothing decided)
- Live tracking during rides (an idea, not planned)
- Statistics for teams and members (the platform admin already has a Statistics tab; audience statistics for club admins were ruled out for now)

---

## Positioning

Primary market: France (French is the default language). The decision-makers are club presidents,
ride organizers and team administrators.

### Personas

| Persona | Cares about | Challenge | Value we promise |
|---------|-------------|-----------|------------------|
| Club Admin | Growing membership, smooth operations | Managing multiple communication channels, keeping members engaged | Centralized platform for all club activities |
| Ride Organizer | Safe, well-organized rides | Coordinating groups, sharing routes, tracking participation | Easy ride creation with groups, routes, and participant management |
| Club Member | Finding rides that match their level | Knowing which rides suit their fitness, getting routes on GPS | Clear group info, easy registration, one-click GPS sync, the weather of their own group |

**Anti-persona:** Solo cyclists who ride alone and don't need group coordination.

### Problems & Pain Points

**Core problem:** Cycling clubs struggle to organize rides across multiple tools (WhatsApp, email, Strava, spreadsheets).

**Why alternatives fall short:**
- WhatsApp/Facebook: No route management, no structured ride info, messages get lost
- Strava: Individual-focused, not designed for club coordination
- Spreadsheets: Manual, no GPS integration, poor mobile experience

**What it costs them:** Missed rides, confusion about meeting points, riders showing up to the wrong group.

**Emotional tension:** Frustration for organizers, anxiety for new members unsure which group to join.

### Switching Dynamics

- **Push:** Frustration with fragmented tools, messages getting lost, route sharing hassles
- **Pull:** Integrated platform, GPS sync, professional club presence
- **Habit:** Existing WhatsApp groups, familiarity with current tools
- **Anxiety:** Learning curve, getting all members to switch
- **Migration:** a team on biketeam can be copied over to Pédalons, again as often as needed, and switch when it is ready ([MIGRATE_BIKETEAM.md](MIGRATE_BIKETEAM.md))

The French product vocabulary (sortie, parcours, étape…) is in the editorial lexicon of
[BRANDING.md](BRANDING.md#8-ton-éditorial-des-libellés-français).

---

## Summary

Pédalons is a production-ready platform for cycling communities combining team management, event coordination, route sharing, and social features.

**Key differentiators:**
- True multi-tenancy with complete team isolation
- Advanced GPX/route management with terrain analysis, a route planner that can follow the team's usual roads, a route generator that blends them with discovery, and a retouch tool for existing routes
- Flexible ride organization with multiple pace groups
- Weather along the route, at the pace and start time of each group
- Routes sent to Garmin Connect, Hammerhead (Karoo) and Wahoo, on demand or automatically for the rides and stages a member joined
- Multi-day trip support for tours
- Built-in marketplace for equipment exchange
- Modern, responsive web interface and a mobile app that writes as well as reads
