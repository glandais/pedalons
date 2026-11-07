# Pedalons - Product Sheet

## Overview

**Pedalons** is a multi-tenant cycling team platform for clubs and groups to organize rides, share routes, coordinate events, and build community.

**Target audience:** Cycling clubs, informal riding groups, tour organizers, bike shops, corporate teams.

---

## Core Features

### Team Management

| Feature | Description |
|---------|-------------|
| Multi-tenant architecture | Complete team isolation |
| Custom profiles | Name, logo, description, custom pages |
| Visibility control | Team (members only), unlisted (anyone with the link) or public (listed) — for teams and for each item |
| Role-based access | Member, Organizer, Admin |
| Team pages | Custom content with markdown and media |
| Configurable features | Enable/disable rides, routes, trips, posts and marketplace; member directory (off by default); interactive route planner (platform admin only) |
| Member directory | Team roster, opened to members by the admins |
| Team webhook | Announcements posted to Slack, Discord, Mattermost or any https address |
| Domain aliases | A team served on its own hostname |

### Rides & Events

| Feature | Description |
|---------|-------------|
| Ride scheduling | Date, time, location, description |
| Multiple pace groups | A/B/C groups with different speeds |
| Route linking | Attach GPX routes to rides |
| Participant management | Registration, capacity limits, attendee lists |
| Start/end places | Predefined meeting points |
| Draft workflow | Prepare before publishing |
| Ride templates | Reusable templates for recurring rides |

### Routes & GPX

| Feature | Description |
|---------|-------------|
| GPX upload | Import from any cycling app |
| Route planner | Draw a track on the map (when enabled for the team) |
| Auto-calculated metrics | Distance, elevation gain/loss, hilliness |
| Surface classification | Road, gravel, MTB, mixed |
| Map visualization | Interactive route display |
| Advanced filtering | By distance, elevation, terrain |
| FIT export | Download for cycling computers |
| Thumbnail generation | Auto-generated previews |
| GPX track departure and weather | In the GPX tools, a departure date and time (local to the track's start point) and an optional average speed give the forecast along the track, up to 7 days ahead |

### Multi-Day Trips

| Feature | Description |
|---------|-------------|
| Trip management | Multi-stage cycling events |
| Stage configuration | Individual routes and places per stage |
| Trip participation | Registration for complete trips |

### Posts & Communication

| Feature | Description |
|---------|-------------|
| Team announcements | News and updates |
| Rich content | Markdown, images, attachments |
| Visibility options | Team-only, unlisted or public |

### Marketplace (Ads)

| Feature | Description |
|---------|-------------|
| Listing types | Sale, rental, wanted |
| Pricing | Fixed price or rental periods |
| Search & filter | By type, date, keywords |
| Privacy by design | Position blurred to about 1 km; no contact field — buyers write through an e-mail relay, and the seller answers them directly |

### Additional Features

- **Comments**: Threaded discussions on rides, routes, posts, trips
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

A team always keeps at least one admin: the last one must name another before leaving the team or
deleting their account.

### Authentication

- Sign-up with email, password and acceptance of the terms, then email verification
- Email + password, with password reset by email
- Email + OTP (one-time password sent by email)
- Passkeys / WebAuthn support
- Device Code Flow (RFC 8628) for GPS devices (Karoo, Garmin)
- User profiles with avatars

### Personal Data

- Self-service data export (ZIP archive emailed as a link), on the web and in the mobile app
- Self-service account deletion: personal data erased immediately, content published for a team kept and credited to "Ancien membre"

---

### Key Technical Features

- TSID (time-sortable unique IDs)
- Auto-generated URL slugs with redirect on change
- Multi-language support (EN/FR)
- Dark mode
- Platform admin panel

---

## Asset Management

| Type | Usage |
|------|-------|
| Logo | Team branding |
| Image | Media content |
| Attachment | Downloadable files (documents, videos…) |
| GPX/FIT | Route data |
| Thumbnail | Auto-generated previews |

---

## Implemented Integrations

- **Mobile app** (Flutter, iOS/Android) — teams, rides, trips, routes, posts, ads, comments, calendar, notifications
- **Garmin Connect IQ app** — ride and route browsing, FIT download on Edge devices
- **Hammerhead Karoo extension** — ride and route browsing, sync
- **GPS device sync** — upload routes to Garmin Connect, Karoo and Wahoo
- **Calendar sync** — iCal feed export

## Roadmap Potential

- Weather forecasts for rides
- Live tracking during rides
- Statistics and analytics

---

## Positioning

Primary market: France (French is the default language). The decision-makers are club presidents,
ride organizers and team administrators.

### Personas

| Persona | Cares about | Challenge | Value we promise |
|---------|-------------|-----------|------------------|
| Club Admin | Growing membership, smooth operations | Managing multiple communication channels, keeping members engaged | Centralized platform for all club activities |
| Ride Organizer | Safe, well-organized rides | Coordinating groups, sharing routes, tracking participation | Easy ride creation with groups, routes, and participant management |
| Club Member | Finding rides that match their level | Knowing which rides suit their fitness, getting routes on GPS | Clear group info, easy registration, one-click GPS sync |

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

The French product vocabulary (sortie, parcours, étape…) is in the editorial lexicon of
[BRANDING.md](BRANDING.md#8-ton-éditorial-des-libellés-français).

---

## Summary

Pedalons is a production-ready platform for cycling communities combining team management, event coordination, route sharing, and social features.

**Key differentiators:**
- True multi-tenancy with complete team isolation
- Advanced GPX/route management with terrain analysis
- Flexible ride organization with multiple pace groups
- Multi-day trip support for tours
- Built-in marketplace for equipment exchange
- Modern, responsive web interface
