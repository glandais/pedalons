# Privacy Policy

**Last updated: October 16, 2026**

This privacy policy describes how Pedalons ("we", "our", "us") collects, uses, and protects your personal data when you use our platform (website, mobile app, GPS device extensions).

For any questions about your personal data, you can contact us at: **privacy@pedalons.fr**

---

## 1. Data We Collect

### Account Data

When you create an account, we collect:

- **Email address**: for authentication and service-related communications
- **Display name**: chosen by you, visible to your team members
- **Profile picture** (optional). In the mobile app, you pick it with the system picker: the app receives only that photo, and has no access to the camera or to the rest of your library.
- **Preferences**: units, theme, language, time zone, notification settings, and whether other members may write to you about your classified ads (yes by default, can be turned off in your profile). Units, theme, language and time zone are stored in your account only once you choose them; until then, your browser's or device's setting applies. We use your language and time zone to write and date our emails and notifications (failing that: the language of the page you made the request from or the sender's language, and Paris time).
- **Acceptance of the terms of service**: the date on which you accepted them at sign-up, kept as proof of that acceptance
- **Account status data**: whether your email address has been verified and the date of that verification, the date your account was created and last modified, the site (domain) your account belongs to, and — for the small number of accounts that administer the platform — an administrator role flag.
- **Team memberships**: your teams, your role in each (member, organiser, administrator) and the date you joined. Who can see the member list: see "Visibility Within the Platform" in section 4.

### Teams Coming from Biketeam

A Biketeam team administrator can transfer their team to Pedalons. Our server then fetches the team's content directly from Biketeam: pages (including the contact details they show), places, routes, rides, trips, publications and images. **No member data is transferred**: no accounts, memberships, registrations or comments. The Pedalons account that confirms the transfer becomes the team's administrator and the author of everything imported; members then join the team through the usual invitation link. For each transfer request we record the account that confirmed it, the Biketeam team concerned, the dates and the outcome.

### Authentication Data

To secure access to your account, we process:

- **Password** (if you set one): stored only as an irreversible hash, never in plain text, and never sent by email.
- **Passkeys**: the private key stays on your device and is never transmitted to us. We keep the public key and its technical data (including the authenticator model), the device label you give it, and the dates it was created and last used.
- **Sessions**: a sign-in token, hashed on our servers, valid for 30 days, or 90 days for a Karoo or Garmin GPS head unit, which is not connected continuously. Where it is stored on your device: see "Data Stored Locally on Your Device".
- **One-time passwords (OTP)**: hashed, valid for 5 minutes, and invalidated after 5 wrong attempts.
- **Links sent by email** (sign-up verification, email change, password reset): hashed, single-use tokens, valid for 24 hours (1 hour for a password reset). At sign-up, your email address, your name and the date you accepted the terms are held pending: the account is only created, with the password you choose on the page the link opens, once you follow that link, and a new address is only applied once you follow its own.
- **GPS device pairing codes**: temporary codes (10 minutes) to connect a Karoo or a Garmin.
- **Failed attempts**: each wrong password and each unknown pairing code is recorded with its date, to block repeated guesses for a few minutes. We record neither the password nor the code tried, nor your email address in clear (only an irreversible fingerprint), nor your IP address; for a pairing code entered while signed in, your account's technical identifier.
- **Calendar token**: if you subscribe to the calendar, a random token embedded in your feed address, which expires after 90 days without your calendar application fetching it. It is stored in readable form so that your calendar application can use it; you can regenerate it at any time (see "Calendar subscriptions" in section 4).

### Session Data

Each time you sign in, we record:

- **IP address** and **user agent** (browser/device type): for account security and suspicious activity detection.
- **Last login date** and **last session usage time**.
- **Server logs**: date and time, IP address, browser or device, requested page and response code, sometimes your email address and technical identifiers. They are used only for security, abuse detection and troubleshooting — never for profiling or advertising. Your location and your sign-in tokens are never written to them. The website's audience measurement requests are not in them (see "Website Audience Measurement" below). Kept for 14 days (see section 6).

### Website Audience Measurement

On the website, we count page views, to know which sites and which pages of the platform are used, with an audience measurement tool we host ourselves. The mobile app and the GPS device extensions do not measure audience.

- **What is counted**: page views, not visits or visitors. For each page view: the site (its domain name); the type of page (for example "ride details") and whether that type of page is open to everyone or members only; for a team page, the team's identifier (the one in its address on pedalons.fr), private teams included, even on a club's own domain; for the first page displayed only, the site you came from, reduced to its domain name; your browser's family and major version, your system, your screen's size category (phone, tablet, computer, large screen; never its exact width) and your country.
- **What is never counted**: the page's full address, the ride, route, post or page you viewed, the address's parameters (invitation links, sign-in links…), the page title, your account, your teams, or whether you are signed in.
- **No cookie, no identifier**: no cookie is set and no visitor or session identifier is computed: two page views cannot be linked to each other, neither on the same site nor from one club's site to another.
- **Your IP address is not kept**: it is used for a few seconds, in memory, to work out your country on our servers, with no third-party service, and to filter out bots and abuse; it is never written to the statistics.
- **Counters, not a record per page view**: for each page we keep hourly or daily totals, and each characteristic (browser, system, screen, country, referring site) is counted separately. Only the data controller looks at these statistics; they are shared with no one, and not cross-referenced with the platform's other data.
- **Duration**: 24 months (see section 6). Requests recognised as coming from bots are not counted.
- **Objecting**: see section 7.

### Location and GPS Data

When you create or view routes:

- **GPS tracks**: coordinates (latitude, longitude, altitude) taken from GPX files you import or from routes you draw with our route planner (where your site or team has turned it on). The points you place are sent to our self-hosted routing engine.
- **GPX files you import**: we keep only the track and its waypoints (position and name). Timestamps, sensor measurements (heart rate, cadence, power, temperature) and the file's metadata (author, email address, device) are removed before anything is stored, and so appear in none of the files we keep, offer for download or send to your GPS services. The same goes for a GPX or FIT file attached to a post as a plain attachment: we keep only the track and its points, and a FIT file is rewritten as a course (without laps, sessions or device information).
- **Waypoints**: names and coordinates of places you add.
- **Team location** (optional): geographic point representing your team's location.
- **Ad and meeting-place locations**: the address or map point you attach to a classified ad or to a meeting place. The map point of an ad is shown to other members only as an approximate area (see "Classified ads" below). For a location entered as text, choose a nearby landmark rather than your home if you do not want your address visible to your team.

We do not continuously track your movements, and we never store a location history. Two features read your current position:

- **Garmin Edge app**: when its main screen is shown, it sends the device's position to our server to sort your team's routes by distance. It requires the Garmin "Positioning" permission, granted at installation.
- **iOS/Android app**: only if you tap "Around me" in the routes list. It then reads your approximate position once, never in the background, and sends it with the route-list requests while that filter is on. It does not save it on your phone.

These coordinates are used only for that sorting and filtering: they are not stored in your account, in our database, or in our logs. Our website and our Hammerhead Karoo extension do not access your device location.

### GPX Analysis Tool

Our GPX tool lets you analyse a GPX file, or a route you draw, without attaching it to a team; it requires an account. For each file analysed we store the file (cleaned as described above), its derived files (simplified GPX, FIT, map image), its statistics, its name and a link to your account, to show you your history in "My files". These files are deleted automatically after **30 days**, or sooner if you delete them.

**Anyone who has the link can see the file.** Each analysed file gets a long random address that is impossible to guess. Anyone holding it — including without an account — can view the track on a map, see its statistics and download it as a GPX or FIT file. Only you can modify or delete it. Share the link only with people you want to give the track to, and delete the file if the link has been shared more widely than you intended.

### Content You Create

- **Rides**: title, description, date and time, pace groups, associated route, meeting and finish places, publication status (draft, published, cancelled) and scheduled publication date.
- **Trips**: multi-day trips and their stages (title, description, dates, routes, start and finish places).
- **Sign-ups (participations)**: the ride or trip, the pace group you chose, and the date of your registration. Your display name and profile picture then appear in the participant list, visible to everyone who can see the ride or trip — including visitors who are not logged in when it is public. Cancelling your registration deletes the record.
- **Posts**: title and text in Markdown format.
- **Comments**: text attached to a post, ride, trip or route.
- **Classified ads**: title, description, photos, type (sale, purchase, rental), price, rental period, and the location you enter (free text and/or a point on the map). Ads are only visible to signed-in members of your team, never publicly. We store exactly the point you place, but only you, your team's administrators and the platform administrators see it exactly; other members see only an area about 1 km across. Location text you type is shown as you typed it. Attached photos carry no GPS position (see "Photos and images").
- **Messages about a classified ad**: "Contact the seller" emails your message (up to 2,000 characters) to the ad's author, along with your display name, the ad's title and a link to it. Your email address is set as the reply address: the author sees it and can reply to you; theirs is never shown to you. We do not keep the text of the message: we record only that you wrote about that ad, and when, to limit abuse (at most 10 messages per hour).
- **Team pages**: the "about" page and any additional pages your team publishes.
- **Ride templates**: reusable ride models (title, description, pace groups) saved by your team's organisers.
- **Places**: names, postal addresses, links and coordinates of meeting and finish points you save for your team.
- **Routes**: name, distance, elevation gain and loss, hilliness, surface type, GPS tracks and waypoints, and two derived files (simplified GPX and FIT) for sending to a GPS device.
- **Photos and images**: the files you upload, with their original file name, format and dimensions. Before storing an image (photo, avatar, logo, attachment), we re-encode it: only the picture itself is kept, and all the metadata added by your device or software is gone, including the GPS position where the photo was taken, the date and the device model. Re-encoding may slightly lower the quality; some formats are converted to JPEG, and an image we cannot re-encode is refused. Other attached files (PDFs, documents…) are kept as you upload them, with their metadata. Videos are not accepted: they carry the place and time they were filmed, sometimes the whole path recorded by the camera, and we cannot reliably strip them of it.

Every item above is stored together with the identity of the account that created it and the creation and last-modification dates.

### Team Invitations

A team administrator can invite someone by email address, whether or not that person has an account. We store the invited address, the team, the role offered, the inviting administrator, the invitation's status and dates, and who accepted or revoked it; the link sent is stored only as a hash. The invitation email shows the administrator's display name and the team name; the number of invitation emails a single address can receive per day is limited. Nobody joins a team without accepting, and creating an account does not accept an invitation. The team's administrators can see the invitations sent, with each address and its status. Validity and retention periods: see section 6.

### Notifications

When something happens in your teams — a new ride, trip or post, a change to or cancellation of a ride you signed up for, a reminder before a ride, a sign-up to a ride you organise, a comment or reply, an invitation, a report to moderate — we create a notification for you. It keeps its type, the dates it was created and read, and a copy of what it is about, taken when it was created: the name of the member who triggered it, the team's name, the title and date of the item concerned, and, for a comment, an extract of up to 280 characters.

Every notification appears in your inbox, on the website and in the app; depending on your settings, per type and per channel, it can also be sent to you by email or as a push notification. You can also receive your non-urgent emails as a daily digest, and mute a team (its announcements no longer reach you, while notifications that concern you personally still do). We store these choices, as well as the channel, status and date of each email or push send.

If you allow push notifications, we store, for each phone or browser: a push token issued by Google Firebase Cloud Messaging that identifies the installation or the browser, not you as a person; the platform; the device name or model (on the website, the browser and the system); the app version; and the dates it was registered and last seen. Permission is only requested when you choose, never at launch, and you can withdraw it at any time in your device's, browser's or notification settings.

Push notifications show their title and text on your device, and, depending on your settings, on the lock screen; for a comment, this text includes its author's name and an extract. If you do not want it visible, change your lock-screen settings or turn off push for these types.

**Team chat channels**: a team's administrators can connect it to a chat channel (Slack, Discord, Mattermost) or to any HTTPS address of their choice. The team's announcements (a ride, trip or post published, a ride or trip cancelled or changed) are then posted there, with the name of the member who triggered them, the team's name, the title and date of the item, what changed, and a link. Everyone with access to the channel can read them, and the service keeps them under its own rules. We record whether each message was delivered, and when.

### Reports and Blocks

To make moderation possible (see section 6 of the terms of service), we record:

- **Your reports**: who reported (you), what is reported (the content or the member, and the team concerned), the author of the content or the member concerned, the reason you chose, the optional message you add, a **copy of the reported text** (at most 1,000 characters), and the decision taken (content removed or report dismissed, by whom and when). The copy lets the decision be checked even if the content has since been edited or deleted.
- **Your blocks**: who blocked whom, and since when.

Who can see them:

- **Your identity as a reporter** is visible **to the Pedalons team only**. It is never shown to the team's organizers, to the author of the content, or to the reported member.
- **The team's organizers and administrators** see the reported content, its author, the reasons, and the messages added, but not who reported it. A message can identify you by what it says: write it knowing they will read it. An organizer who is the subject of a report does not see it.
- **Your blocks** are visible to you only. The blocked person is not told, and nothing in the service reveals it to them.

Content reported by at least three members is hidden from members until a moderator has decided. The notification that alerts moderators to a report contains only the team's name, never the reported content or the reporter's identity.

**Publication filter**: when you publish, your text is compared with a short list of abusive or hateful terms. If it contains one, publication is refused and the text is not stored; the refusal has no other consequence for your account.

### Problem Reports and Error Reports

To fix bugs, we receive:

- **Your problem reports or suggestions** ("Report a problem", on the website or in the app): the text you write, the platform and the app version, and, if you leave the "Attach technical information" box checked, the page or screen displayed, the team you are viewing, the device's system and model or the browser, the language, the time zone, and a log of your last actions in the app (pages visited, failed requests, errors). The form shows you exactly what will be sent.
- **Automatic error reports** (signed in only): when the app hits an unexpected error, it sends the technical description of the error, the same technical information and the log of your last actions. You can turn this off in **Profile → Privacy**.

The log contains no password, no form content and no web address parameter; any sign-in token or e-mail address found in it is masked by our servers before anything is stored. This information reaches the Pedalons team as tickets in a **private** GitHub repository (see section 4), where you are designated by a technical identifier, never by your name or e-mail address.

### Beta Programme Sign-ups

On the Apps page, anyone, with or without an account, can leave an email address to hear when a test version of our mobile or Garmin app opens. We store the address, the site it was entered on and the date; it is not linked to any account and no confirmation email is sent. We use it only to contact you about the beta. If we invite you, we enter it by hand in the beta-testing service of the store concerned (Apple TestFlight or Google Play Console), which processes it under its own privacy policy. Connect IQ, Garmin's store, has no beta-testing service, so your address is not entered there. To be removed from the list, write to privacy@pedalons.fr.

### Third-Party GPS Service Connections

If you connect an external GPS service (Hammerhead, Garmin, Wahoo):

- **OAuth access tokens**: encrypted before storage. We never store your credentials (username/password) for these services.
- **External user ID**: where the service returns one when you connect (Hammerhead does, Wahoo does not), to link it to your Pedalons account.
- **What we send**: a route's track and name to your account on the service, in two cases only:
  - **on request**, when you choose to send a route; it then stays on your account on the service;
  - **automatically**, if you turn on "automatic sending" for that service (off by default, set service by service): the route of each ride you are signed up for that starts within 7 days, named after the date, the group and the route. We update it if the route changes, and remove it from your account on the service 24 hours after the start, if you withdraw, if the ride is cancelled or no longer concerns you, and as soon as you turn automatic sending off, disconnect the service or delete your Pedalons account.

  Wahoo also receives the start point, distance, climb and descent, and a fingerprint of the file (to avoid duplicates). Connecting Wahoo asks for permission to read your profile (Wahoo requires it) and to create routes; we do not read your Wahoo profile or activities.
- **Sending record**: for each route sent, the identifier the service gave it, a fingerprint of what was sent and the sending dates, so that we update or remove it rather than create a duplicate.

### Data Stored Locally on Your Device

**In your web browser**: the cookies and local storage used by the website are listed in section 8. In addition, the log of your last actions (200 entries at most) is kept in memory while the page is open, for a possible problem report; it only leaves your device in the cases described in "Problem Reports and Error Reports".

**In the mobile app:**

- **Your session token**: held in your device's secure storage, and deleted when you sign out. The app does not use cookies.
- **Display preferences**: a copy of your theme, language and units (the value saved in your account takes precedence), plus your map settings and the layout of the routes list.
- **Image and map caches**: the photos and avatars displayed (including your teams' private photos) and the map images, kept in the app's storage so they do not have to be downloaded again, and cleared when you uninstall the app or clear its data.
- **Files you download**: a route or an attachment you download is saved in the app's temporary folder, then handed to the share sheet; it stays there until the system clears it or you uninstall the app.
- **Push token**: the Firebase Cloud Messaging component keeps an installation identifier and a push token on the device. They remain after you sign out, because they identify the installation rather than you, but our server then stops using them for your account.
- **Log of your last actions and error reports**: your last actions (200 entries at most), the error reports not yet sent and your automatic-error-report setting. None of this leaves your phone except in the cases described in "Problem Reports and Error Reports".
- **No backup**: on Android, the app's data is excluded from cloud backup and from transfer to a new device.

**On your GPS device (Karoo, Garmin)**: the Pedalons extension stores only your session tokens and their expiry (plus, during pairing, the temporary code), in its private storage, without additional encryption: anyone with access to the unlocked device or to a backup of it could read them. No ride or route content is kept on it. Signing out on the device erases the tokens from the device only: the session stays valid on our servers until it expires (90 days). To end it immediately, for example if you lose the device, use "Sign out of every device" in your profile, on the website or in the mobile app.

---

## 2. How We Collect Your Data

- **Directly from you**: when you create an account, fill in your profile, import GPX files, create content, or connect a GPS service.
- **Automatically**: IP address and user agent during sign-in; session cookie to maintain your authentication; server logs as described in section 1; on the website, audience measurement as described in section 1 ("Website Audience Measurement"); and, unless you turn them off, automatic error reports (see "Problem Reports and Error Reports").
- **From the platform Pedalons succeeds**: a Biketeam team administrator can have their team's content transferred from Biketeam's server, as described in section 1 ("Teams Coming from Biketeam").
- **From other members**: a team administrator who invites you gives us your email address (see "Team Invitations"); a member who reports you or your content gives us the reason, their message and a copy of the reported text (see "Reports and Blocks").
- **From the beta sign-up form** (see "Beta Programme Sign-ups").

Apart from these cases, **we do not collect data from third parties**: we never buy or rent data, and we collect nothing from social networks.

---

## 3. Why We Use Your Data

For each purpose, the legal basis (GDPR) it rests on:

- **Provide the service (account, authentication, navigation)**: Performance of contract
- **Display your team's routes, rides, trips and other content**: Performance of contract
- **Send verification emails and sign-in codes**: Performance of contract
- **Show notifications about your teams in your inbox on the website and in the app**: Performance of contract
- **Send you notifications by email, according to your notification settings**: Performance of contract (adjustable at any time, per type)
- **Notify you on your phone or in your browser (push notifications)**: Consent (permission granted on the phone or in the browser); you can withdraw it in your device's or browser's settings, or turn push off per type in your notification settings
- **Post the team's announcements to the chat channel its administrators connected**: Legitimate interest (the team's interest in informing its members)
- **Relay messages about classified ads**: Performance of contract
- **Team invitations**: Legitimate interest (the team's interest in inviting its members)
- **Moderate content: handle reports, apply your blocks, filter abusive terms at publication**: Performance of contract (terms of service) and legitimate interest (protecting members)
- **Keep proof that you accepted the terms of service**: Legitimate interest
- **Secure your account (suspicious session detection)**: Legitimate interest
- **Sync your routes with connected GPS devices**: Consent (voluntary connection; for automatic sending, turning it on, service by service, which you can withdraw at any time by turning it off)
- **Display maps (map backgrounds downloaded by your device from the chosen provider)**: Legitimate interest
- **Approximate location ("Around me", optional, mobile app)**: Consent, given through the operating-system permission prompt; you can withdraw it in your device settings
- **Provide your personal calendar feed to the calendar app you choose**: Consent (voluntary subscription)
- **Tell you when a beta of our apps opens**: Consent (voluntary sign-up)
- **Handle your problem reports and fix the app's errors**: Legitimate interest (reliability of the service; automatic reports can be turned off)
- **Measure the website's audience, anonymously and in aggregate**: Legitimate interest (exempt from consent); you can object, see section 7
- **Continue the service for teams coming from the previous platform**: Legitimate interest
- **Operate and support the platform**: Legitimate interest

We **never** use your data for:
- Targeted advertising
- Selling, renting or sharing it for commercial purposes
- Automated profiling or automated decision-making
- Tracking you across sites, or usage statistics tied to your account

---

## 4. Data Sharing

### Visibility Within the Platform

- **Team content** ("team"): visible to the members of that team. Drafts and unpublished items are visible only to the team's organisers and administrators.
- **Unlisted content** ("unlisted"): not shown in public lists, search results or directories, but readable by anyone who has the link, including people without an account. Treat an unlisted link as semi-public: we cannot prevent it from being forwarded.
- **Public content** ("public"): content set to "public" in a public team is accessible to anyone on the internet, without an account and without logging in. Such pages may be indexed by search engines and displayed as link previews in social networks and messaging apps. This includes the participant lists of public rides and trips (display name and profile picture of each registered member).
- **A team's member list**: administrators see all of it (display name, picture, role, join date) and can search it by email address; organisers see names and pictures, so that they can choose a group leader; other members see it only if the administrators turn on the member directory (off by default). Email addresses are never shown to other members.
- **Your display name and profile picture** are visible to the members of your teams, and to anyone on the internet wherever they appear on public content (participant list, author of a post). Your picture file is served from an address that does not require logging in. Choose a name and a picture you are comfortable showing publicly; you can remove your picture at any time.
- **GPX tool files**: accessible to anyone who has the link, without an account (see "GPX Analysis Tool" in section 1).
- **Link previews**: when a link to a route, a ride or an analysed GPX file is pasted into a messaging app, a social network or a chat tool, that platform fetches the preview image we publish — for a track, a map of the track with its name, distance and elevation — even if nobody clicks. Do not share the link if the track starts at your home.
- **Calendar subscriptions (ICS)**: your personal calendar link works without logging in: anyone who obtains it can read the rides and trips you can see, including team-only ones. A hosted calendar service (Google Calendar, Apple Calendar, Outlook, …) fetches the feed on its own servers and stores its content (titles, dates and links of rides and stages, your team names); we have no control over what it does with it. Treat the feed address as a password: it stays valid as long as a calendar application fetches it; it expires after 90 days without a fetch, and regenerating it immediately invalidates the old one.
- **Team chat channels**: if your team's administrators have connected one (see "Notifications" in section 1), the team's announcements, with the name of the member who triggered them, are posted there. The team chooses the service, which receives them as a recipient acting under its own terms, not as our provider.
- **Reports**: see "Reports and Blocks" in section 1.
- **Platform administration**: a very small number of platform administrator accounts (currently the data controller himself) can technically access all accounts and all content across all sites, including team-only and draft content, and can list email addresses, last-login dates and beta programme sign-ups. This access is used only to operate, support and moderate the service, and only when necessary.

### Technical Service Providers

We use technical services to operate the platform:

- **Scaleway (Scaleway SAS, France)**
  - *Role*: Application, database, and file hosting; email delivery (Transactional Email SMTP relay)
  - *Data Involved*: For hosting, all data. For emails: the recipient's address and name, and the full content of each message — sign-in links and codes, invitations (valid 14 days), messages about classified ads (with the sender's address as the reply address), notifications and digests (which contain lasting links to the content concerned), and the link to your data export. Scaleway is contractually bound to use this data only to deliver the email on our behalf.
- **GitHub (GitHub, Inc., United States)**
  - *Role*: Tracking of problem reports and error reports, in a private repository only the Pedalons team can access
  - *Data Involved*: Report text, technical information, log of last actions, team viewed, technical account identifier and domain
- **Google Firebase Cloud Messaging (Google Ireland Limited, Ireland)**
  - *Role*: Routing push notifications to the mobile app, through Apple Push Notification service for iPhones, and to your browser
  - *Data Involved*: The push token of your phone or browser, your device's IP address when the app or the browser contacts Firebase, and the content of each notification: title and text (which can include a team name, a ride, trip or post title and date, the name of a member and an extract of a comment), plus technical data used to open the right page (notification type and identifier, team and page identifiers)
- **Apple Push Notification service (Apple Distribution International Ltd, Ireland)**
  - *Role*: Delivering push notifications to iPhones, relayed by Firebase Cloud Messaging
  - *Data Involved*: The same notification content and your device's Apple push token
- **Hammerhead, Garmin, Wahoo (United States)**
  - *Role*: Sending your routes to your GPS device, only if you connect the service: on request, or automatically if you turn it on
  - *Data Involved*: OAuth tokens, the routes you choose to send and, if you turn on automatic sending, those of the rides you are signed up for within 7 days (track, name — for an automatic send, the date and the group name are added; for Wahoo also start point, distance, climb and descent)

The website's audience measurement tool is hosted by us at Scaleway, like the rest of the platform: no other provider receives these statistics.

### Browser Push Services

On the website, a push notification is delivered to your browser by its vendor's push service (Google for Chrome, Mozilla for Firefox, Apple for Safari, Microsoft for Edge), chosen by your browser, not by us. The service receives the encrypted message, which it cannot read, your browser's subscription address and your device's IP address. It acts as an independent controller, under your browser vendor's policy, and is only involved if you turn notifications on for the website.

### Map Display and Address Search

Map images are downloaded by your device directly from the provider of the map background you selected. That provider receives your IP address, your browser or app version, and the map area you are viewing (which reveals, roughly, the area of the route you are looking at); we send them nothing about you. These providers act as independent controllers, under their own policies.

Place search (team location, meeting places, classified ads; when signed in), by contrast, goes through our server, which queries Nominatim on your behalf: Nominatim receives only the search text and your display language, never your IP address or your identity. Results are kept in our server's memory for up to 24 hours.

Ride weather forecasts are requested from Open-Meteo by our server, in the background and never while you browse: Open-Meteo receives only the centre of a cell of about 5 km around the start and the route's points (never the exact meeting place), sometimes an altitude rounded to 100 m, and our server's IP address — never your identity, account or IP address.

- **VersaTiles (tiles.versatiles.org)**
  - *Role*: Vector map background (default style), map fonts and sprites
  - *Data Involved*: IP address, map area viewed
- **Mapterhorn (tiles.mapterhorn.com, served by Cloudflare, United States)**
  - *Role*: Terrain-elevation and hillshade tiles (3-D relief); also used by our server to correct the altitude of imported tracks
  - *Data Involved*: Your browser or app, only when you switch on relief shading or 3-D terrain (both off by default): IP address, map area viewed. Server-side: coordinates of coarse map tiles (~10 km squares) covered by a track and our server's IP address — never your identity, account or IP address
- **IGN / Géoplateforme (data.geopf.fr, France)**
  - *Role*: French IGN map, satellite and SCAN 25 backgrounds; also used by our server (LiDAR HD) to correct the altitude of tracks imported in France
  - *Data Involved*: Your browser or app: IP address, map area viewed. Server-side: coordinates of the map tiles (~1 km squares) covered by a track and our server's IP address — never your identity, account or IP address
- **OpenStreetMap Foundation (tile.openstreetmap.org, United Kingdom)**
  - *Role*: OpenStreetMap map background
  - *Data Involved*: IP address, map area viewed
- **OpenStreetMap France (tile-cyclosm.openstreetmap.fr)**
  - *Role*: CyclOSM map background
  - *Data Involved*: IP address, map area viewed
- **OpenStreetMap Nominatim (nominatim.openstreetmap.org)**
  - *Role*: Place search, queried by our server
  - *Data Involved*: The text you type and your display language; never your IP address or identity
- **Open-Meteo (api.open-meteo.com)**
  - *Role*: Ride weather forecasts, queried by our server
  - *Data Involved*: Coordinates of the centre of cells of about 5 km, rounded altitude, our server's IP address; never your IP address or identity
- **Esri (server.arcgisonline.com, United States)**
  - *Role*: "Satellite (ESRI)" map background
  - *Data Involved*: IP address, map area viewed

The "Michelin" map background is served by us (tiles.pedalons.fr): choosing it involves no third party. Image processing, map rendering and route calculation are also self-hosted, and the site's and the app's typefaces are bundled with them (except the map-label fonts, provided by VersaTiles).

### Authorities

We may be required to disclose your data if required by law (judicial request, legal obligation).

---

## 5. International Data Transfers

Our servers are hosted by **Scaleway** (Scaleway SAS, Vitry-sur-Seine, France) and are located in France. The data we store remains within the European Union.

Some processing you can trigger involves servers outside the European Union:

- **Third-party GPS services** (Hammerhead, Garmin, Wahoo, United States): only if you connect one, and only for the routes you send them or, if you turn on automatic sending, those of the rides you are signed up for. This transfer is necessary for the service you request, putting the route on your account (Article 49(1)(b) GDPR); Garmin is also certified under the EU–US Data Privacy Framework.
- **Map backgrounds and terrain**: your device sends your IP address and the area viewed to the provider of the background you choose (see section 4). The "Satellite (ESRI)" background comes from Esri (United States), which is certified under the Data Privacy Framework. Mapterhorn's terrain tiles, requested only if you switch on relief shading or 3-D terrain, are served by Cloudflare (United States), which is certified too. The OpenStreetMap background is served from the United Kingdom, which benefits from a European Commission adequacy decision.
- **Google's Firebase messaging component**: the mobile app includes it, and it contacts Google's servers when the app starts, even before you sign in or allow notifications, which reveals your device's IP address and creates a Firebase installation identifier. The app and the website include only this messaging part of Firebase: no Firebase analytics, advertising or tracking component. On the website, this component is loaded only once you have turned on notifications.
- **Push notifications**: Google (Firebase Cloud Messaging) may process their title, their text and your device's push token in the United States; this transfer is covered by the European Commission's standard contractual clauses and by Google LLC's certification under the Data Privacy Framework. On iPhone, they are delivered by Apple (Apple Distribution International, Ireland), whose transfers to the United States are covered by the standard contractual clauses; in a browser, by its vendor's push service, which only receives the encrypted message (see section 4). This happens only while you allow notifications.
- **Problem reports and error reports**: sent to GitHub (United States), without your name or your e-mail address; this transfer is covered by the European Commission's standard contractual clauses and by GitHub, Inc.'s certification under the Data Privacy Framework.
- **Team chat channels**: the service chosen by the team's administrators (for example Slack or Discord, operated from the United States) receives the team's announcements. This transfer takes place on the administrators' instructions, who choose the service: Slack and Discord are certified under the Data Privacy Framework; any other service is governed by its own terms.
- **Beta programmes**: if we invite you, your email address is entered in Apple TestFlight or Google Play Console; Apple and Google cover their transfers to the United States with the standard contractual clauses.

---

## 6. Data Retention

- **Account data (email address, display name, profile picture, preferences, password hash)**: For as long as your account exists; erased as soon as you delete it (see section 7)
- **Date of acceptance of the terms of service**: As long as your account exists
- **Login sessions (hashed token, IP address, browser or device, creation and last-use dates)**: 30 days from sign-in, not extended by use
- **Sessions of a paired GPS device (Karoo, Garmin)**: 90 days from pairing, not extended by use. "Sign out of every device" revokes it, and so does a password reset; signing out on the device itself does not
- **Temporary sign-in codes (OTP)**: 5 minutes, or until 5 wrong attempts
- **Pending sign-up (verification link, display name, password hash, date of acceptance of the terms)**: 24 hours
- **Password reset link**: 1 hour
- **Email change verification link**: 24 hours
- **GPS device pairing codes**: 10 minutes at most
- **Passkey challenges**: 5 minutes at most
- **Failed sign-in and pairing attempts**: 24 hours
- **Calendar token (secret URL of your .ics feed)**: Until regenerated, or deleted after 90 days without the feed being fetched
- **Teams and content (rides, posts, routes, trips, pages)**: Deleting an item hides it from members and visitors, but it stays in our database: the team's administrators still see it in their lists, marked "Deleted", and can restore it. The record is kept until permanent erasure is requested
- **Comments**: Erased as soon as you or your team delete them, together with the replies they received; the extract copied into a notification remains until that notification expires (90 days)
- **Photos, uploaded files, waypoints, places, sign-ups, passkeys, GPS-service connections**: Erased immediately and permanently when you or your team delete them
- **Record of routes sent to a GPS service**: Until the automatically sent route is removed, and at the latest until you disconnect the service, which erases it
- **Files attached to content (images, GPX, FIT, generated map images)**: As long as the associated record exists in our database. Files uploaded but never attached to any content are erased one day after upload
- **GPX analysis tool files**: 30 days from creation (deletable by you at any time)
- **Notifications (inbox, read status, copy of the content, record of email, push and chat-channel sends)**: 90 days. Messages already posted to a team's chat channel stay there under that service's rules
- **Notification settings (per-type settings, daily digest, muted teams)**: As long as your account exists
- **Push registration of a phone or browser (push token, platform, device or browser, app version, dates)**: Until you sign out on that device or turn notifications off there, another account signs in on it, Firebase Cloud Messaging rejects the token (for example after the app was uninstalled), or you delete your account. "Sign out of every device" removes only the registration of the device you use it from: your other devices keep receiving push notifications until you sign out on them
- **Team chat channel settings (address of the channel, language, last delivery status)**: Until the team's administrators remove the channel
- **Team invitations (invited email address, role offered, who sent it, status and dates)**: Valid for 14 days; the record, including the address of someone who never created an account, is kept for 1 year after it was accepted, revoked or expired, so the team can see who invited whom
- **Record of messages sent about a classified ad (sender, ad, date; the message itself is not stored)**: Until the ad is permanently erased
- **Blocks**: Until you unblock the person, or until either of your accounts is deleted
- **Reports, copy of the reported text, and decision**: As long as the account of the person concerned exists, to keep a record of moderation decisions; when the reporter's account is deleted, kept with no link to them (see section 7)
- **Problem reports and suggestions**: 1 year on our servers, or until your account is deleted; the matching GitHub ticket is kept as long as it is useful to track the bug
- **Automatic error reports**: 90 days on our servers, or until your account is deleted; the matching GitHub ticket is kept as long as it is useful
- **Team transfer requests from Biketeam (account that confirmed, Biketeam team, dates, outcome)**: 1 year after the transfer ended or the request expired; after the account is deleted, the request is no longer linked to anything that identifies the person
- **Beta programme sign-ups (email address, site, date)**: 1 year after sign-up; ask privacy@pedalons.fr to be removed sooner
- **Data export archive (ZIP)**: 7 days
- **Data export request history (request date, status, archive size, expiry date)**: 90 days
- **Server access logs (date and time, IP address, browser or device, requested address without the coordinates or tokens, response code; excluding audience measurement requests, which are not written to them)**: 14 days
- **Website audience statistics (per-page counters, without IP address, identifier or session; aggregated statistics included)**: 24 months. For requests recognised as coming from bots, which are not counted, the requested page and the user agent: 30 days
- **Data after account deletion**: Erased immediately (see section 7)

Expired data is erased from the database by a clean-up that runs every night, so it may remain stored for up to 24 hours beyond the period shown.

**Backups.** Every night we take a complete copy of the database and of the uploaded files, stored on a separate server in France; the last 30 copies are kept, and older ones are deleted automatically. Data that is deleted or erased, including when you delete your account, can therefore remain in our backups for up to 30 days. Backups are encrypted (see section 9) and used only to restore the service after an incident. The website's audience statistics are not backed up.

---

## 7. Your Rights

Under the General Data Protection Regulation (GDPR), you have the following rights:

- **Right of access**: obtain a copy of your personal data.
- **Right to rectification**: correct inaccurate or incomplete data.
- **Right to erasure** ("right to be forgotten"): request deletion of your data.
- **Right to restriction of processing**: temporarily restrict the use of your data.
- **Right to data portability**: receive your data in a structured, machine-readable format.
- **Right to object**: object to processing based on legitimate interest. For the website's audience measurement: turn on Do Not Track or Global Privacy Control in your browser, which applies to all our sites; or, on the website, use the switch under **Profile → Privacy** or on the **Privacy** page (/privacy). That switch applies only to this browser and this site: repeat it on each club's site and in each browser. The app measures nothing.
- **Right to withdraw consent**: at any time, without affecting the lawfulness of prior processing.

### Export your data yourself

You can exercise the rights of access and portability yourself, without writing to us: under **Profile → Privacy → My data**, on the website or in the app, request an export. We prepare a ZIP archive and email you a download link, valid for **7 days**. One export per hour per account.

The archive contains, in JSON format, everything that concerns you: your profile, your teams, your sign-ups, what you have published and your files, your notifications from the last 90 days and their settings, your devices registered for push, your blocks, the reports you made (without the copy of the reported text, which is someone else's content) and your problem reports. Authentication secrets (password hash, tokens, keys) are excluded for security reasons, but their metadata (dates, devices, services) is included. The archive does not yet include your time zone, your ad-contact setting, your team invitations, or the record of messages sent about classified ads; ask privacy@pedalons.fr for these.

### Delete your account

You can delete your account yourself, at any time, without writing to us:

- **on the website as in the mobile app**: **Profile → My account → Danger zone**, then "Delete the account".

If you are the only administrator of a team that has other members, you must first make another member an administrator: the app and the website name the teams concerned. A team of which you are the only member is deleted along with your account.

If you no longer have access to your account or to the app, write to **privacy@pedalons.fr** from your account's email address asking for its deletion.

Deletion is irreversible and immediate: all the data linked to your account is erased as soon as you confirm, with these exceptions:

- **What you published for a team** (rides, trips, routes, posts and their files) belongs to that team and stays online, credited to "Ancien membre" (French for "former member"), with no remaining link to you. Your registrations for past rides are kept in the same anonymous form, without being displayed.
- **Your comments** are erased, except a comment other members replied to, which is kept empty, marked "Comment deleted".
- **Your classified ads** are withdrawn, stripped of their text, price and location, and their photos are deleted.
- **Reports you made** are kept with no link to you, so that the decisions taken can still be checked; GitHub tickets created from your problem reports remain, with an identifier that no longer leads to anyone. Reports about you are deleted.
- **Notifications you triggered** for other members keep your display name until they expire (90 days), and messages already posted to a team's chat channel stay there.
- **Our backups** still contain your data for up to 30 days (see section 6).

If you want content published for a team to disappear, delete it before deleting your account, or ask one of the team's organizers. Deleting your account removes the link to your GPS services on our side, but does not withdraw the authorisation you gave them: you can revoke it from your Hammerhead, Garmin or Wahoo account.

### Contact us

For the other rights, or if you would rather go through us, write to **privacy@pedalons.fr**. To protect your data, we may ask you to confirm a request from the email address attached to your account.

We will respond to any request within **30 days**. If we cannot comply, we will explain why.

You may also lodge a complaint with the **CNIL** (French Data Protection Authority): [www.cnil.fr](https://www.cnil.fr)

---

## 8. Cookies and Local Storage

Pedalons uses a minimal number of cookies and local storage items:

- **refresh_token**
  - *Type*: HttpOnly cookie (website)
  - *Purpose*: Maintain your authenticated session
  - *Duration*: 30 days after sign-in
- **refresh_token**
  - *Type*: Device secure storage (mobile app; not a cookie)
  - *Purpose*: Keep you signed in without re-entering your credentials
  - *Duration*: Until you sign out (server-side session validity: 30 days)
- **lang**
  - *Type*: Cookie
  - *Purpose*: Remember the language you chose, so that pages are displayed in it
  - *Duration*: 1 year
- **pedalons-unit-system**
  - *Type*: localStorage
  - *Purpose*: Remember your unit system
  - *Duration*: Persistent
- **mantine-color-scheme-value**
  - *Type*: localStorage
  - *Purpose*: Remember your theme (light/dark)
  - *Duration*: Persistent
- **pedalons-map-style, pedalons-map-terrain3d, pedalons-map-hillshade**
  - *Type*: localStorage
  - *Purpose*: Remember your map display preferences
  - *Duration*: Persistent
- **pedalons-error-reports**
  - *Type*: localStorage
  - *Purpose*: Remember that you turned off automatic error reports
  - *Duration*: Persistent
- **pedalons.webPush.token**
  - *Type*: localStorage
  - *Purpose*: Unregister this browser from push notifications when you sign out or turn them off
  - *Duration*: Until you sign out or turn them off
- **Firebase messaging data**
  - *Type*: Browser storage (website)
  - *Purpose*: Registration of this browser for push notifications, only once you turn them on
  - *Duration*: Until you clear your browser data
- **pedalons.installBanner.dismissedAt**
  - *Type*: localStorage
  - *Purpose*: Remember that you dismissed the suggestion to install the website as an app
  - *Duration*: Persistent (the suggestion comes back after 90 days)
- **pendingInvitationToken, pendingBiketeamMigrationRequest**
  - *Type*: sessionStorage
  - *Purpose*: Keep a team invitation, or a team transfer request from Biketeam, while you sign in
  - *Duration*: Until the tab is closed
- **pedalons-analytics-optout**
  - *Type*: localStorage
  - *Purpose*: Remember that you object to audience measurement, on this site and in this browser only
  - *Duration*: Until you withdraw your objection or clear the site's data in your browser

When you are signed in, the language, units and theme saved in your account take precedence over the local copy. For the other data kept by the mobile app and by the Karoo and Garmin extensions, see "Data Stored Locally on Your Device" in section 1.

**We do not use any tracking, analytics, or advertising cookies.** The website's audience measurement uses no cookie and meets the CNIL's conditions for exemption from consent (see "Website Audience Measurement" in section 1); you can object to it at any time (see section 7). No consent is therefore required: the session cookie is strictly necessary for the service to function, and the lang cookie only remembers a choice you made. Note that displaying a map causes your browser to request map tiles directly from the provider of the style you selected — see "Map Display and Address Search" in section 4.

---

## 9. Security

We implement the following measures to protect your data:

- **Encryption in transit**: all communications use HTTPS (TLS).
- **Encryption at rest**: the access tokens of your GPS services are encrypted (AES-256-GCM).
- **Secret hashing**: passwords (bcrypt), session tokens, one-time codes and links sent by email are stored only as irreversible hashes. Two secrets are an exception, because our systems must look them up directly: the token in your calendar link and the short pairing code of a GPS device (valid for 10 minutes).
- **Session cookie**: unreadable by the page's scripts, sent over HTTPS only, and protected against use by another website to change your data.
- **Isolation between sites**: each site's data is isolated in the database; platform administrators are the only exception (see section 4).
- **Limits on sign-in codes**: the number of sign-in codes and links that can be requested for the same address is capped, and each one expires quickly.
- **Limits on guesses**: after several wrong passwords for the same address, password sign-in is suspended for a quarter of an hour (sign-in by email code and by passkey remain available); unknown GPS device pairing codes are limited likewise.
- **Backups**: encrypted in transit to a separate server. The database is encrypted before it leaves our servers, and only a key kept offline can decrypt it; everything is stored on an encrypted volume.

No system is infallible. If you notice suspicious activity on your account, contact us immediately.

**Data breach**: if a breach of your data poses a risk to your rights and freedoms, we notify the CNIL (the French data protection authority) within 72 hours of becoming aware of it; if the risk is high, we also inform you without undue delay, telling you what happened and what you can do.

---

## 10. Children's Privacy

Pedalons is not intended for children under 16, and we do not knowingly collect their data. When you create your account, you declare that you are at least 16, in the same checkbox as the acceptance of the terms, whose date we keep. We do not verify this declaration and do not ask for your date of birth. If you are a parent and believe your child has provided us with data, contact us so we can delete it.

---

## 11. Changes to This Policy

We may update this policy to reflect changes in our practices or in regulations; the date at the top of this page shows the latest version. In case of a significant change, we will inform you by email.

---

## 12. Data Controller

The data controller for your personal data is:

- **LANDAIS Gabriel** (sole proprietorship)
- **Address**: 29 rue Docteur Jean Rostand, 44800 Saint-Herblain, France
- **SIRET**: 897 872 958 00011

The same controller is responsible on every site Pedalons hosts, including a club's site under its own domain name: the clubs and teams that use the platform are not controllers of your data on Pedalons.

### Data Protection Officer (DPO)

The Data Protection Officer is **Gabriel Landais**, reachable at the contact address below.

## 13. Contact

For any questions about this policy or your personal data: **privacy@pedalons.fr** (response within 30 days maximum).

---
