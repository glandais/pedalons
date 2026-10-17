#!/usr/bin/env python3
"""Seeds the fictional demo clubs: on staging for the store screenshots, on prod for
the store reviewers' test account.

    python3 screenshots/seed.py                  # staging: create what is missing, rebuild both clubs
    python3 screenshots/seed.py --dry-run        # print the plan, touch nothing
    MARKETPLACE_TESTER_PASSWORD=… python3 screenshots/seed.py --target prod
    MARKETPLACE_TESTER_PASSWORD=… python3 screenshots/seed.py --target prod --refresh

`--target prod` builds the same two clubs on www.pedalons.fr for the account given
to the Apple, Google and Garmin reviewers (marketplace-tester@pedalons.fr, which
must exist: its password comes from the environment, and it is neither renamed
nor registered). It is the viewer of both clubs, and the calendar is dense: one
or two rides a week over the next fifteen months.

`--refresh` keeps the prod clubs and brings them back to date, every day from the
production host's crontab: the test account is registered to its next ride, which
carries a comment thread from other members, and to a few more in the next three
weeks; rides drawing near fill up; a trip is always ahead, the month has its post,
and the calendar's end moves forward. Nothing is deleted, so the history builds up
as rides pass (the API refuses a registration to a past ride), and the test
account's blocks are lifted so the next reviewer finds every member. API calls
only, as the club's members: no SSH, no SQL, no platform role.

Two clubs around Lake Annecy, one per store locale (fr-FR, en-US), share the same
eight fictional members; each locale has its own viewer account, the one the
capture signs in as, member of its club only. Every run deletes and recreates the
two clubs, so dates stay relative to today: capture right after seeding.

Everything goes through the public API except two SQL statements run over SSH on
the staging database, both on accounts this script created:

- registration always e-mails a verification link, and no endpoint creates a
  verified user. The script registers normally, then swaps the pending token's
  hash for the hash of a token it knows, and verifies through the API — the
  account is created by the real code path, and no inbox is read. The addresses
  are plus-aliases of one real inbox, so no verification mail bounces;
- the organizer account is made PLATFORM_ADMIN, which lets it add members to a
  club (the API only adds members to a club that allows it, a flag only a
  platform admin can set).

On prod the organizer's PLATFORM_ADMIN role is taken back at the end of the run,
failed or not; the demo accounts get their e-mail notifications switched off, and
the test account joins the clubs only once the rides' announcements are fanned out,
so it doesn't receive a hundred "new ride" mails in one go.

Writes screenshots/accounts.local.json (staging) or accounts.prod.local.json
(git-ignored: passwords), and on staging screenshots/plan.json (the screens to
capture, with this run's slugs). `--refresh` only reads the prod file, from the
path in SEED_ACCOUNTS when set (the production host keeps it outside the checkout).
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import random
import secrets
import subprocess
import sys
import time as clock
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

HERE = Path(__file__).resolve().parent
TARGETS = {
    "staging": {"api": "https://staging.pedalons.fr", "env": "pedalons-staging",
                "accounts": HERE / "accounts.local.json"},
    "prod": {"api": "https://www.pedalons.fr", "env": "pedalons-prod",
             "accounts": HERE / "accounts.prod.local.json"},
}
TARGET = sys.argv[sys.argv.index("--target") + 1] if "--target" in sys.argv else "staging"
if TARGET not in TARGETS:
    sys.exit(f"--target must be one of {', '.join(TARGETS)}")
PROD = TARGET == "prod"

API = TARGETS[TARGET]["api"]
SSH = "pedalons@pedalons.fr"
ENV_NAME = TARGETS[TARGET]["env"]
INBOX = "gabriel.landais+pdl-demo-{key}@gmail.com"
TZ = ZoneInfo("Europe/Paris")

ACCOUNTS = Path(os.environ.get("SEED_ACCOUNTS") or TARGETS[TARGET]["accounts"])
PLAN = HERE / "plan.json"

DRY_RUN = "--dry-run" in sys.argv
REFRESH = "--refresh" in sys.argv
if REFRESH and not PROD:
    sys.exit("--refresh keeps the prod clubs up to date: use it with --target prod")
# Healthchecks URL of the daily refresh: /start, then success or /fail with the error.
PING_URL = os.environ.get("STORE_DEMO_PING_URL")

# The account the store reviewers sign in with, on prod. It exists already.
TESTER = "marketplace-tester@pedalons.fr"
TESTER_PASSWORD_ENV = "MARKETPLACE_TESTER_PASSWORD"
# How far ahead the prod calendar reaches; --refresh moves its end forward.
CALENDAR_AHEAD = timedelta(days=455)
# Rides closer than this are well attended; further ones only have a few early birds.
NEAR_DAYS = 21

# ---------------------------------------------------------------- people

# key -> display name. `julien` organizes both clubs (ADMIN, platform admin),
# `sophie` is an organizer; the viewers are the accounts the capture signs in as.
MEMBERS = {
    "julien": "Julien Berthet",
    "sophie": "Sophie Lambert",
    "thomas": "Thomas Girod",
    "lea": "Léa Dubois",
    "marc": "Marc Perrin",
    "emma": "Emma Rossi",
    "nicolas": "Nicolas Favre",
    "claire": "Claire Vidal",
}
VIEWERS = {"fr-FR": ("viewer-fr", "Camille Martin"), "en-US": ("viewer-en", "Alex Morgan")}

# ---------------------------------------------------------------- places

ANNECY = (45.9003, 6.1302)  # Le Pâquier
PLACES = {
    "paquier": {"fr": "Le Pâquier, Annecy", "en": "Le Pâquier, Annecy", "at": ANNECY,
                "address": "Avenue d'Albigny, 74000 Annecy"},
    "thorens": {"fr": "Place de Thorens-Glières", "en": "Thorens-Glières square", "at": (45.9957, 6.2478),
                "address": "74570 Thorens-Glières"},
}

# Waypoints, routed leg by leg by the staging backend (/api/router, Stadia Maps).
ROUTES = [
    {"key": "lac", "surface": "ROAD", "profile": "BIKE", "tags": ["lakeside", "flat"],
     "fr": "Tour du lac d'Annecy", "en": "Lake Annecy loop",
     "md": {"fr": "Le grand classique, à plat : parfait pour une reprise ou une sortie récupération.",
            "en": "The flat classic: ideal to get back on the bike or for a recovery ride."},
     "via": [ANNECY, (45.8640, 6.1400), (45.8290, 6.2010), (45.7760, 6.2230), (45.8410, 6.2130),
             (45.8830, 6.1720), ANNECY]},
    {"key": "forclaz", "surface": "ROAD", "profile": "BIKE", "tags": ["col", "lakeside"],
     "fr": "Col de la Forclaz par Talloires", "en": "Col de la Forclaz via Talloires",
     "md": {"fr": "Montée par Talloires, descente sur Doussard et retour par la rive ouest.",
            "en": "Up from Talloires, down to Doussard and back along the west shore."},
     "via": [ANNECY, (45.8830, 6.1720), (45.8410, 6.2130), (45.8134, 6.2466), (45.7760, 6.2230),
             (45.8640, 6.1400), ANNECY]},
    {"key": "semnoz", "surface": "ROAD", "profile": "BIKE", "tags": ["col"],
     "fr": "Semnoz et col de Leschaux", "en": "Semnoz and Col de Leschaux",
     "md": {"fr": "Le Semnoz par Quintal, puis la descente sur Leschaux. Vue sur le Mont-Blanc au sommet.",
            "en": "The Semnoz from Quintal, then down to Leschaux. Mont Blanc views at the top."},
     "via": [ANNECY, (45.8290, 6.0880), (45.7990, 6.1010), (45.7720, 6.1130), (45.8640, 6.1400), ANNECY]},
    {"key": "bauges", "surface": "ROAD", "profile": "BIKE", "tags": ["col", "long"],
     "fr": "Boucle des Bauges", "en": "Bauges loop",
     "md": {"fr": "Leschaux, Lescheraines et le cœur des Bauges : une longue sortie vallonnée.",
            "en": "Leschaux, Lescheraines and the heart of the Bauges: a long rolling ride."},
     "via": [ANNECY, (45.8640, 6.1400), (45.7720, 6.1130), (45.7110, 6.1060), (45.7410, 6.1400),
             (45.7720, 6.1130), ANNECY]},
    {"key": "glieres", "surface": "GRAVEL", "profile": "GRAVEL", "tags": ["gravel", "col"],
     "fr": "Plateau des Glières en gravel", "en": "Glières plateau gravel",
     "md": {"fr": "Départ de Thorens, montée au plateau et pistes d'alpage. Pneus de 40 mm conseillés.",
            "en": "From Thorens up to the plateau and its alpine tracks. 40 mm tyres recommended."},
     "via": [(45.9957, 6.2478), (45.9650, 6.3310), (45.9757, 6.3197), (45.9957, 6.2478)]},
    {"key": "beaufort", "surface": "ROAD", "profile": "BIKE", "tags": ["stage", "long"],
     "fr": "Annecy – Beaufort", "en": "Annecy to Beaufort",
     "md": {"fr": "Première étape : la vallée jusqu'à Albertville, puis la montée vers Beaufort.",
            "en": "Stage one: down the valley to Albertville, then up to Beaufort."},
     "via": [ANNECY, (45.7760, 6.2230), (45.6760, 6.3920), (45.7190, 6.5730)]},
    {"key": "roselend", "surface": "ROAD", "profile": "BIKE", "tags": ["stage", "col"],
     "fr": "Beaufort – Cormet de Roselend", "en": "Beaufort to Cormet de Roselend",
     "md": {"fr": "Deuxième étape : le lac de Roselend et le Cormet, descente sur Bourg-Saint-Maurice.",
            "en": "Stage two: Lake Roselend and the Cormet, down to Bourg-Saint-Maurice."},
     "via": [(45.7190, 6.5730), (45.6880, 6.6720), (45.6180, 6.7690)]},
]

# Each club's tag vocabulary, by kind of content: key -> (fr, en, colour). The
# seed puts them on what it creates; a club admin's tag of the same label is reused.
TAGS = {
    "ROUTE": {"col": ("Col", "Climb", "ORANGE"), "lakeside": ("Bord du lac", "Lakeside", "BLUE"),
              "flat": ("Plat", "Flat", "GREEN"), "long": ("Longue distance", "Long distance", "GRAPE"),
              "gravel": ("Gravel", "Gravel", "YELLOW"), "stage": ("Étape", "Stage", "TEAL")},
    "RIDE": {"mountain": ("Montagne", "Mountain", "ORANGE"), "afterwork": ("Afterwork", "After work", "INDIGO"),
             "gravel": ("Gravel", "Gravel", "YELLOW"), "winter": ("Hiver", "Winter", "BLUE"),
             "easy": ("Allure cool", "Easy pace", "GREEN")},
    "TRIP": {"mountain": ("Montagne", "Mountain", "ORANGE"), "weekend": ("Week-end", "Weekend", "TEAL")},
    "POST": {"programme": ("Programme", "Schedule", "INDIGO"), "club": ("Vie du club", "Club life", "GRAPE")},
    "AD": {"bike": ("Vélo", "Bike", "BLUE"), "gear": ("Équipement", "Gear", "TEAL"),
           "parts": ("Pièces", "Parts", "GRAY")},
}

# ---------------------------------------------------------------- HTTP


class ApiError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body[:400]}")
        self.status = status
        self.body = body


def call(method: str, path: str, body=None, token: str | None = None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise ApiError(e.code, e.read().decode(errors="replace")) from None


def sql(statement: str) -> str:
    # A Swarm task container has no fixed name: found by its service label, then by the
    # compose name — scripts/_backup_common.sh container_of.
    container = (f'"$(docker ps -q --filter label=com.docker.swarm.service.name={ENV_NAME}_postgres | head -n1)"'
                 f'; [ "$c" != "" ] || c="$(docker ps -q --filter name=^{ENV_NAME}-postgres$ | head -n1)"')
    cmd = ["ssh", "-o", "BatchMode=yes", SSH,
           f'c={container}; docker exec -i "$c" sh -c '
           f'\'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -v ON_ERROR_STOP=1\'']
    out = subprocess.run(cmd, input=statement, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"✖ SQL on {ENV_NAME} failed: {out.stderr.strip()}")
    return out.stdout.strip()


def media(markdown: str = "") -> dict:
    return {"markdown": markdown, "assets": {"images": [], "attachments": []}}


def point(lat: float, lon: float) -> dict:
    return {"type": "Point", "coordinates": [lon, lat]}


def ensure_tags(base: str, org: str, lang: str) -> dict:
    """The club's TAGS, created when missing; (kind, key) -> tag id."""
    existing = {(t["type"], t["label"].lower()): t["id"] for t in call("GET", f"{base}/tags", token=org)}
    out = {}
    for kind, vocabulary in TAGS.items():
        for key, (fr_label, en_label, color) in vocabulary.items():
            label = fr_label if lang == "fr" else en_label
            tag_id = existing.get((kind, label.lower()))
            if not tag_id:
                tag_id = call("POST", f"{base}/tags", {"type": kind, "label": label, "color": color}, org)["id"]
                print(f"  tag {kind} {label}")
            out[(kind, key)] = tag_id
    return out


def tag_ids(tags: dict, kind: str, keys) -> list:
    return [tags[(kind, k)] for k in keys]


def ride_tags(route: str, when: datetime) -> list:
    """A ride's RIDE tags, read off its route and its date."""
    keys = []
    if route in ("forclaz", "semnoz", "bauges"):
        keys.append("mountain")
    if route == "glieres":
        keys.append("gravel")
    if when.weekday() == 2:
        keys.append("afterwork")
    elif route == "lac":
        keys.append("easy")
    if not 4 <= when.month <= 10:
        keys.append("winter")
    return keys


# ---------------------------------------------------------------- accounts


def load_accounts() -> dict:
    return json.loads(ACCOUNTS.read_text()) if ACCOUNTS.exists() else {}


def save_accounts(accounts: dict, keys: list) -> dict:
    stored = {k: {"email": accounts[k]["email"], "password": accounts[k]["password"], "id": accounts[k]["id"]}
              for k in keys}
    if not PROD:
        for locale, (key, _) in VIEWERS.items():
            stored[locale] = {"email": accounts[key]["email"], "password": accounts[key]["password"]}
    ACCOUNTS.write_text(json.dumps(stored, indent=2, ensure_ascii=False) + "\n")
    ACCOUNTS.chmod(0o600)
    return stored


def known_token(email: str, token_type: str) -> str:
    """Swaps the hash of `email`'s pending `token_type` token for the hash of a token
    this script knows, and returns that token: no inbox is read."""
    token = secrets.token_urlsafe(32)
    token_hash = base64.b64encode(hashlib.sha256(token.encode()).digest()).decode()
    updated = sql(
        "UPDATE auth_tokens SET token_hash = '%s' WHERE email = '%s' "
        "AND token_type = '%s' AND used_at IS NULL RETURNING id;" % (token_hash, email, token_type))
    if not updated:
        raise RuntimeError(f"no pending {token_type} token for {email}")
    return token


def ensure_account(accounts: dict, key: str, name: str) -> dict:
    """Signs `key` in, registering and verifying it first if it doesn't exist."""
    acc = accounts.get(key) or {"email": INBOX.format(key=key), "password": secrets.token_urlsafe(18)}
    accounts[key] = acc
    try:
        auth = call("POST", "/api/auth/login", {"email": acc["email"], "password": acc["password"]})
    except ApiError as e:
        if e.status not in (400, 401):
            raise
        try:
            call("POST", "/api/auth/register", {"email": acc["email"], "displayName": name,
                                                 "password": acc["password"], "acceptTerms": True})
            print(f"  registered {name} <{acc['email']}>")
            auth = call("POST", "/api/auth/verify-email",
                        {"token": known_token(acc["email"], "EMAIL_VERIFICATION")})
        except ApiError as e:
            if "EMAIL_ALREADY_EXISTS" not in e.body:
                raise
            # The account exists with a password this file doesn't know (the
            # database was rebuilt, or seeded from another checkout): reset it.
            print(f"  resetting the password of {name} <{acc['email']}>")
            call("POST", "/api/auth/forgot-password", {"email": acc["email"]})
            auth = call("POST", "/api/auth/reset-password",
                        {"token": known_token(acc["email"], "PASSWORD_RESET"),
                         "newPassword": acc["password"]})
    acc["id"] = auth["user"]["id"]
    acc["token"] = auth["accessToken"]
    if auth["user"].get("displayName") != name:
        call("PUT", "/api/users/me", {"displayName": name}, acc["token"])
    return acc


def tester_account() -> dict:
    """Signs the reviewers' account in. Never registered nor renamed by this script."""
    password = os.environ.get(TESTER_PASSWORD_ENV)
    if not password:
        sys.exit(f"--target prod needs {TESTER_PASSWORD_ENV}")
    auth = call("POST", "/api/auth/login", {"email": TESTER, "password": password})
    return {"email": TESTER, "id": auth["user"]["id"], "token": auth["accessToken"]}


def mute_email(acc: dict) -> None:
    """Switches every e-mail notification of a demo account off; the inbox keeps them."""
    prefs = call("GET", "/api/notifications/preferences", token=acc["token"])
    cells = [{"type": c["type"], "channel": c["channel"], "enabled": False}
             for c in prefs["preferences"] if c["channel"] != "IN_APP" and c["enabled"]]
    if cells:
        call("PUT", "/api/notifications/preferences", {"preferences": cells}, acc["token"])


def wait_for_fan_out(slug: str) -> None:
    """Waits until the club's notification events have all been fanned out."""
    team_id = sql("SELECT id FROM teams WHERE NOT deleted AND slug = '%s';" % slug)
    for _ in range(120):
        pending = int(sql("SELECT count(*) FROM notification_events WHERE team_id = %s "
                          "AND status IN ('PENDING', 'PROCESSING');" % team_id))
        if not pending:
            return
        print(f"  waiting for {pending} notification events to fan out")
        clock.sleep(10)
    raise RuntimeError("notification events still pending after 20 minutes")


# ---------------------------------------------------------------- routes


def routed_points(via: list, profile: str, token: str) -> list:
    points: list = []
    for (a, b) in zip(via, via[1:]):
        leg = call("POST", "/api/router", {"from": {"lat": a[0], "lng": a[1]},
                                           "to": {"lat": b[0], "lng": b[1]}, "profile": profile}, token)
        coords = leg["route"]["coordinates"]
        if points:
            coords = coords[1:]
        points += [{"lng": c[0], "lat": c[1]} for c in coords]
    return points


# ---------------------------------------------------------------- club


def next_weekday(weekday: int, at: time, min_days: int = 1) -> datetime:
    """The next `weekday` (Mon=0) at least `min_days` away, at local `at`."""
    today = datetime.now(TZ).date()
    d = today + timedelta(days=min_days)
    while d.weekday() != weekday:
        d += timedelta(days=1)
    return datetime.combine(d, at, TZ)


def calendar(fr: bool, start: date, end: date) -> list:
    """The prod calendar from `start` to `end`, as `rides_spec` entries: every Saturday
    (mountains from April to October, the lake and the Bauges later in the morning in
    winter), Wednesday evenings round the lake from April to September, gravel on the
    first Sunday of the month from May to October. A given day always gets the same
    ride, whatever the range: --refresh extends what a full run created."""
    leaders = ["thomas", "marc", "sophie", "lea", None, None]
    names = {r["key"]: r["fr" if fr else "en"] for r in ROUTES}
    d = start
    out = []
    while d <= end:
        rng = random.Random(f"calendar-{fr}-{d}")
        summer = 4 <= d.month <= 10
        week = d.isocalendar()[1]
        if d.weekday() == 5:
            route = (["forclaz", "semnoz", "bauges", "lac"] if summer else ["lac", "bauges"])[week % (4 if summer else 2)]
            out.append((route, "paquier", datetime.combine(d, time(8, 30) if summer else time(9, 30), TZ),
                        tuple(rng.choice(leaders) for _ in range(3)),
                        (f"Sortie du samedi : {names[route]}" if fr else f"Saturday ride: {names[route]}")
                        if summer else (f"Sortie d'hiver : {names[route]}" if fr else f"Winter ride: {names[route]}"),
                        ("Rendez-vous au Pâquier, départ à l'heure. Regroupement au sommet." if fr else
                         "Meet at Le Pâquier, we leave on time. Regroup at the top.") if summer else
                        ("Départ plus tard pour éviter le gel. Gants longs et couvre-chaussures." if fr else
                         "Later start to avoid the frost. Full gloves and overshoes.")))
        elif d.weekday() == 2 and 4 <= d.month <= 9:
            out.append(("lac", "paquier", datetime.combine(d, time(18, 15), TZ), (rng.choice(leaders),),
                        "Tour du lac en semaine" if fr else "Midweek lake loop",
                        "Sortie courte après le travail, éclairage obligatoire au retour." if fr else
                        "Short after-work ride, lights required on the way back."))
        elif d.weekday() == 6 and d.day <= 7 and 5 <= d.month <= 10:
            out.append(("glieres", "thorens", datetime.combine(d, time(9, 0), TZ),
                        (rng.choice(leaders), None),
                        "Gravel aux Glières" if fr else "Glières gravel ride",
                        "Pistes roulantes, quelques passages caillouteux au plateau." if fr else
                        "Fast tracks, a few rocky sections on the plateau."))
        d += timedelta(days=1)
    return out


def random_signups(when: datetime, group_count: int, seed: str) -> dict:
    """Members registered on a calendar ride: four to eight once it is near, the first
    zero to three of them (the early birds) while it is months away. The same ride
    always draws the same members, so --refresh only tops it up as it draws near."""
    rng = random.Random(seed)
    riders = rng.sample(list(MEMBERS), rng.randint(4, 8))
    early = rng.randint(0, 3)
    joins = {key: rng.randrange(group_count) for key in riders}
    if (when - datetime.now(TZ)).days >= NEAR_DAYS:
        joins = dict(list(joins.items())[:early])
    return joins


def tester_rides(rides: list, locale: str) -> set:
    """The prod rides the test account rides: its very next one, so the home screen
    always shows it, and two in five of those in the next three weeks."""
    now = datetime.now(TZ)
    upcoming = [r for r in rides if r[1] > now]
    near = {r[0] for r in upcoming if (r[1] - now).days < NEAR_DAYS
            and random.Random(f"tester-{locale}-{r[1]:%Y%m%d}").random() < 0.4}
    return near | ({upcoming[0][0]} if upcoming else set())


def iso(dt: datetime) -> str:
    return dt.astimezone(ZoneInfo("UTC")).isoformat().replace("+00:00", "Z")


def wall(dt: datetime) -> str:
    """An event's `dateTime`: wall-clock time in the team's zone (Paris), no offset — the
    API refuses an instant since contract 11.0.0 (API-60)."""
    return dt.astimezone(TZ).strftime("%Y-%m-%dT%H:%M:%S")


def instant(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(TZ)


def club_name(fr: bool) -> str:
    return "VC du Lac d'Annecy" if fr else "Annecy Lakeside Cycling"


def ride_groups(acc: dict, fr: bool, route: str, leaders: tuple, when: datetime) -> list:
    """One group per entry of `leaders` (None: no leader), fastest first, the first
    leaving at the ride's time and the others a quarter of an hour later."""
    names = (["Groupe rapide", "Groupe intermédiaire", "Groupe découverte"] if fr
             else ["Fast group", "Intermediate group", "Discovery group"])
    speeds = [31, 27, 23]
    # Fewer groups keep the middle ones: a lone group is the intermediate one.
    picked = {1: [1], 2: [0, 1], 3: [0, 1, 2]}[len(leaders)]
    out = []
    for n, (i, leader) in enumerate(zip(picked, leaders)):
        start = when if n == 0 else when + timedelta(minutes=15)
        g = {"name": names[i], "time": f"{start:%H:%M}:00", "averageSpeed": speeds[i],
             "maxParticipants": 12, "routeSlug": route}
        if leader:
            g["leaderId"] = acc[leader]["id"]
        out.append(g)
    return out


def create_ride(base: str, acc: dict, fr: bool, routes: dict, places: dict, tags: dict, spec: tuple,
                joins: dict) -> tuple:
    """Publishes one `rides_spec` entry and registers `joins` (member -> group index)."""
    route, place, when, leaders, title, text = spec
    ride = call("POST", f"{base}/rides", {
        "name": title, "media": media(text), "dateTime": wall(when), "status": "PUBLISHED",
        "visibility": "TEAM", "routeSlug": routes[route], "startPlaceId": places[place],
        "endPlaceId": places[place], "groups": ride_groups(acc, fr, routes[route], leaders, when),
        "tagIds": tag_ids(tags, "RIDE", ride_tags(route, when))},
                acc["julien"]["token"])
    gids = [g["id"] for g in ride["groups"]]
    for key, g in joins.items():
        call("POST", f"{base}/rides/{ride['slug']}/groups/{gids[g]}/join", token=acc[key]["token"])
    print(f"  ride {ride['slug']}  {when:%a %d %b %Y %H:%M}  {len(joins)} riders")
    return ride["slug"], when, gids


def join_ride(base: str, ride_slug: str, group_id: str, token: str) -> bool:
    """Registers to a ride's group; False when already registered, full or started."""
    try:
        call("POST", f"{base}/rides/{ride_slug}/groups/{group_id}/join", token=token)
        return True
    except ApiError as e:
        if e.status in (400, 409) and any(c in e.body for c in ("ALREADY_REGISTERED", "GROUP_FULL", "RIDE_PAST")):
            return False
        raise


def create_trip(base: str, acc: dict, fr: bool, routes: dict, places: dict, tags: dict, day: datetime) -> str:
    trip = call("POST", f"{base}/trips", {
        "name": "Week-end dans le Beaufortain" if fr else "Beaufortain weekend",
        "tagIds": tag_ids(tags, "TRIP", ["mountain", "weekend"]),
        "media": media("Deux jours, deux étapes, une nuit à Beaufort. Voiture d'assistance pour les sacs." if fr
                       else "Two days, two stages, one night in Beaufort. A support car carries the bags."),
        "dateTime": wall(day), "status": "PUBLISHED", "visibility": "TEAM",
        "stages": [
            {"name": "Annecy – Beaufort" if fr else "Annecy to Beaufort", "dateTime": wall(day),
             "routeSlug": routes["beaufort"], "startPlaceId": places["paquier"],
             "media": media("Pique-nique à Albertville." if fr else "Picnic lunch in Albertville.")},
            {"name": "Cormet de Roselend" if fr else "Cormet de Roselend",
             "dateTime": wall(day + timedelta(days=1)), "routeSlug": routes["roselend"],
             "media": media("Retour en train depuis Bourg-Saint-Maurice." if fr
                            else "Train back from Bourg-Saint-Maurice.")},
        ]}, acc["julien"]["token"])
    for key in ["sophie", "thomas", "emma", "marc"]:
        call("POST", f"{base}/trips/{trip['slug']}/join", token=acc[key]["token"])
    print(f"  trip {trip['slug']}  {day:%a %d %b %Y}")
    return trip["slug"]


# The thread on the viewer's next ride: another member's comment and a reply to
# it, the viewer's comment and a reply to it, which lands in the viewer's inbox.
# The App Review notes report and block from it. --refresh rotates the wording.
THREADS = [
    {"fr": ("Je prends le groupe rapide, on regroupe au sommet ?", "Oui, regroupement au col, 5 minutes max.",
            "Première sortie avec le club, j'ai hâte !",
            "Bienvenue ! Tu verras, le groupe intermédiaire est très sympa."),
     "en": ("I'll lead the fast group, regroup at the top?", "Yes, regroup at the col, 5 minutes max.",
            "First ride with the club, can't wait!", "Welcome! You'll see, the intermediate group is great fun.")},
    {"fr": ("Météo correcte annoncée, mais prenez un coupe-vent pour la descente.", "Merci, bien noté !",
            "Je serai là, quelqu'un a une pompe à prêter ? La mienne a rendu l'âme.",
            "J'en ai une dans mon sac, pas de souci."),
     "en": ("Decent forecast, but bring a windproof for the descent.", "Thanks, noted!",
            "I'll be there. Anyone have a pump to lend? Mine just died.", "I have one in my bag, no problem.")},
    {"fr": ("Qui part de Seynod ? On peut rouler ensemble jusqu'au départ.", "Moi ! Rendez-vous au rond-point à 8 h 10.",
            "Je viens pour la première fois dans ce groupe, l'allure me va ?",
            "Aucun souci, on attend toujours en haut des bosses."),
     "en": ("Anyone coming from Seynod? We could ride to the start together.", "Me! Roundabout at 8:10.",
            "First time in this group for me, will the pace suit?", "No worries, we always wait at the top of the climbs.")},
]


def comment_thread(base: str, ride_slug: str, acc: dict, viewer: dict, lang: str, n: int) -> None:
    first, answer, mine, welcome = THREADS[n % len(THREADS)][lang]
    url = f"{base}/rides/{ride_slug}/comments"
    c1 = call("POST", url, {"content": first}, acc["thomas"]["token"])
    c2 = call("POST", url, {"content": mine}, viewer["token"])
    call("POST", url, {"content": welcome, "parentId": c2["id"]}, acc["lea"]["token"])
    call("POST", url, {"content": answer, "parentId": c1["id"]}, acc["sophie"]["token"])


MONTHS = {"fr": ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre",
                 "octobre", "novembre", "décembre"],
          "en": ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                 "October", "November", "December"]}
DAYS = {"fr": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"],
        "en": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]}


def month_post(fr: bool, month: date) -> tuple:
    """The organizer's post announcing `month`'s rides, read off the calendar."""
    lang = "fr" if fr else "en"
    end = (month.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)
    rides = calendar(fr, month, end)
    saturdays = [r for r in rides if r[2].weekday() == 5]
    name = MONTHS[lang][month.month - 1]
    hour = f"{saturdays[0][2]:%H}" if saturdays else "8"
    minute = f"{saturdays[0][2]:%M}" if saturdays else "30"
    days = DAYS[lang]
    routes = {r["key"]: r[lang] for r in ROUTES}
    lines = "\n".join(f"- {days[r[2].weekday()]} {r[2].day} : {routes[r[0]]}" if fr else
                      f"- {days[r[2].weekday()]} {name} {r[2].day}: {routes[r[0]]}" for r in rides)
    if fr:
        title = f"Le programme {'d’' if name[0] in 'aeiouéy' else 'de '}{name}"
        text = (f"Les sorties du samedi partent à **{int(hour)} h {minute}** du Pâquier.\n\n{lines}\n\n"
                "Pensez à vous inscrire dans votre groupe : ça aide les capitaines de route à s'organiser.")
    else:
        title = f"The {name} programme"
        text = (f"Saturday rides leave Le Pâquier at **{int(hour)}:{minute}**.\n\n{lines}\n\n"
                "Please sign up in your group: it helps the ride captains plan.")
    return title, text


def seed_club(locale: str, acc: dict, viewer: dict) -> list:
    lang = locale[:2]
    fr = lang == "fr"
    org = acc["julien"]["token"]
    name = club_name(fr)

    # One club per locale, rebuilt on every run.
    # Looked up in SQL: the organizer is a platform admin, so the API lists every
    # club on staging, and the demo club can fall past any page.
    quoted = name.replace("'", "''")
    for old in sql("SELECT slug FROM teams WHERE NOT deleted AND name = '%s';" % quoted).split():
        print(f"  deleting previous {old}")
        call("DELETE", f"/api/teams/{old}", token=org)
    # A deleted club keeps its slug (uk_teams_domain_slug), and slug generation
    # doesn't reliably step around it (HTTP 500). Free it so the club comes back
    # under the same slug on every run.
    sql("UPDATE teams SET slug = slug || '-deleted-' || id WHERE deleted AND name = '%s' "
        "AND slug NOT LIKE '%%-deleted-%%';" % quoted)
    about = ("Club cyclosportif du bassin annécien : sorties route et gravel toute l'année, "
             "trois groupes d'allure, un voyage par saison." if fr else
             "A road and gravel club around Lake Annecy: rides all year round, three pace groups, "
             "one trip per season.")
    team = call("POST", "/api/teams", {
        "name": name, "media": media(about), "visibility": "TEAM",
        "enableTrips": True, "enableAds": True, "enablePosts": True, "enableRides": True,
        "enableRoutes": True, "enableMemberDirectory": True, "geometry": point(*ANNECY)}, org)
    slug = team["slug"]
    print(f"  club {slug}")
    base = f"/api/teams/{slug}"

    roles = {"sophie": "ORGANIZER"}
    for key in [k for k in MEMBERS if k != "julien"]:
        call("POST", f"{base}/members", {"userId": acc[key]["id"], "role": roles.get(key, "MEMBER")}, org)
    if not PROD:
        call("POST", f"{base}/members", {"userId": viewer["id"], "role": "MEMBER"}, org)

    places = {}
    for key, p in PLACES.items():
        places[key] = call("POST", f"{base}/places", {
            "name": p[lang], "address": p["address"], "startPlace": True, "endPlace": True,
            "geometry": point(*p["at"])}, org)["id"]

    tags = ensure_tags(base, org, lang)

    routes = {}
    for r in ROUTES:
        pts = routed_points(r["via"], r["profile"], org)
        preview = call("POST", "/api/gpx-previews/from-points", {"name": r[lang], "points": pts}, org)
        route = call("POST", f"/api/gpx-previews/{preview['id']}/routes/{slug}", {
            "name": r[lang], "media": media(r["md"][lang]), "surfaceType": r["surface"],
            "visibility": "TEAM", "tagIds": tag_ids(tags, "ROUTE", r["tags"])}, org)
        routes[r["key"]] = route["slug"]
        print(f"  route {route['slug']}  {preview['distance'] / 1000:.0f} km, +{preview['elevationGain']:.0f} m")

    rides_spec = [
        ("forclaz", "paquier", next_weekday(5, time(8, 30)), ("thomas", None, "sophie"),
         "Sortie du samedi : la Forclaz" if fr else "Saturday ride: the Forclaz",
         "Rendez-vous au Pâquier. Café à Talloires au retour pour ceux qui veulent." if fr else
         "Meet at Le Pâquier. Coffee in Talloires on the way back for those who want."),
        ("lac", "paquier", next_weekday(2, time(18, 15)), (None, None, None),
         "Tour du lac en semaine" if fr else "Midweek lake loop",
         "Sortie courte après le travail, éclairage obligatoire au retour." if fr else
         "Short after-work ride, lights required on the way back."),
        ("semnoz", "paquier", next_weekday(6, time(8, 30), 3), ("marc", None, None),
         "Dimanche au Semnoz" if fr else "Sunday on the Semnoz",
         "Grosse journée de montagne : prévoyez deux bidons et un coupe-vent pour la descente." if fr else
         "A big mountain day: bring two bottles and a windproof for the descent."),
        ("glieres", "thorens", next_weekday(5, time(9, 0), 8), (None, None, None),
         "Gravel aux Glières" if fr else "Glières gravel ride",
         "Pistes roulantes, quelques passages caillouteux au plateau." if fr else
         "Fast tracks, a few rocky sections on the plateau."),
    ]
    # Registrations of the four rides above.
    signups = [{"thomas": 0, "nicolas": 0, "emma": 0, "lea": 1, "marc": 1, "claire": 2, "sophie": 2},
               {"lea": 0, "claire": 0, "nicolas": 1},
               {"marc": 0, "thomas": 0, "emma": 1},
               {"nicolas": 0, "julien": 0, "lea": 1}]
    if PROD:
        # From tomorrow only: the API refuses a registration to a past ride, so the
        # history is what --refresh leaves behind as the days go by.
        today = datetime.now(TZ).date()
        taken = {when.date() for _, _, when, *_ in rides_spec}
        for spec in calendar(fr, today + timedelta(days=1), today + CALENDAR_AHEAD):
            if spec[2].date() not in taken:
                rides_spec.append(spec)
                signups.append(random_signups(spec[2], len(spec[3]), f"{locale}-{spec[2]:%Y%m%d}"))
        rides_spec, signups = map(list, zip(*sorted(zip(rides_spec, signups), key=lambda x: x[0][2])))
    ride0 = None
    rides = []
    for spec, joins in zip(rides_spec, signups):
        rides.append(create_ride(base, acc, fr, routes, places, tags, spec, joins))
        if joins is signups[0]:
            ride0 = rides[-1][0]

    trip_slug = create_trip(base, acc, fr, routes, places, tags, next_weekday(5, time(8, 0), 15))

    now = datetime.now(TZ)
    month = now.date().replace(day=1)
    posts = [
        # Dated within its month, which --refresh then finds it in.
        (*month_post(fr, month), min(now, max(now - timedelta(days=2), datetime.combine(month, time(7), TZ))),
         ["programme"]),
        ("Nouveaux maillots du club" if fr else "New club jerseys",
         ("Les maillots du club sont commandés ! Livraison prévue dans un mois, distribution à la "
          "sortie du samedi suivant." if fr else
          "The club jerseys are ordered! Delivery expected in a month, handed out at the following "
          "Saturday ride."),
         now - timedelta(days=6), ["club"]),
    ]
    post_slugs = []
    for title, text, when, keys in posts:
        post = call("POST", f"{base}/posts", {"name": title, "media": media(text), "dateTime": wall(when),
                                              "status": "PUBLISHED", "visibility": "TEAM",
                                              "tagIds": tag_ids(tags, "POST", keys)}, org)
        post_slugs.append(post["slug"])

    ads = [
        ("emma", "SALE", 1450, None, "Vélo route carbone, taille M" if fr else "Carbon road bike, size M",
         "Groupe Shimano 105 12 vitesses, freins à disque, 4 000 km. Révisé cet été." if fr else
         "Shimano 105 12-speed, disc brakes, 4,000 km. Serviced this summer.", (45.9050, 6.1250), ["bike"]),
        ("marc", "RENTAL", 15, "DAY", "Porte-vélos d'attelage 3 vélos" if fr else "Tow-bar bike rack, 3 bikes",
         "Idéal pour le week-end dans le Beaufortain." if fr else "Just right for the Beaufortain weekend.",
         (45.8700, 6.1100), ["gear"]),
        ("nicolas", "WANTED", None, None, "Cherche roues gravel 700C" if fr else "Looking for 700C gravel wheels",
         "Axe traversant 12 mm, compatibles tubeless." if fr else "12 mm thru-axle, tubeless-ready.",
         (45.9200, 6.1500), ["parts"]),
    ]
    for key, ad_type, price, period, title, text, at, keys in ads:
        body = {"name": title, "media": media(text), "status": "PUBLISHED", "adType": ad_type,
                "locationDescription": "Annecy", "locationGeometry": point(*at),
                "tagIds": tag_ids(tags, "AD", keys)}
        if price is not None:
            body["price"] = price
        if period:
            body["rentalPeriod"] = period
        call("POST", f"{base}/classifieds", body, acc[key]["token"])

    if PROD:
        # The viewer joins last, once every announcement above has been fanned out
        # to the members of the moment: the reviewers' inbox gets comments, not
        # a hundred "new ride" mails.
        wait_for_fan_out(slug)
        call("POST", f"{base}/members", {"userId": viewer["id"], "role": "MEMBER"}, org)

    # The viewer rides the first ride, in the intermediate group; on prod, also
    # its very next one and a few more in the next three weeks.
    viewer_rides = {ride0} | (tester_rides(rides, locale) if PROD else set())
    for ride_slug, when, gids in rides:
        if ride_slug in viewer_rides:
            call("POST", f"{base}/rides/{ride_slug}/groups/{gids[len(gids) // 2]}/join",
                 token=viewer["token"])

    comment_thread(base, ride0, acc, viewer, lang, 0)
    call("POST", f"{base}/posts/{post_slugs[1]}/comments", {
        "content": "Trop bien, j'en prends deux !" if fr else "Great, I'll take two!"}, acc["claire"]["token"])

    prefix = "/equipes" if fr else "/teams"
    sorties = "sorties" if fr else "rides"
    parcours = "parcours" if fr else "routes"
    voyages = "voyages" if fr else "trips"
    # `wait`: seconds before the screen may be taken, for maps whose tiles keep
    # arriving after the frame first looks still. The iPad home is left out: its
    # wide layout adds "latest publications" from every public club on staging,
    # real people's content a store page must not show; the trip takes its place.
    # `push`: a screen without a URL, pushed by the app over `path` once loaded
    # (lib/screenshots/screenshot_mode.dart). The weather needs ride0 within
    # seven days — next Saturday, so capture right after seeding.
    return [
        {"id": "01-home", "path": "/", "devices": ["iphone"]},
        {"id": "01-trip", "path": f"{prefix}/{slug}/{voyages}/{trip_slug}", "devices": ["ipad"], "wait": 12},
        {"id": "02-ride", "path": f"{prefix}/{slug}/{sorties}/{ride0}", "push": "rideGroups", "wait": 12},
        {"id": "03-weather", "path": f"{prefix}/{slug}/{sorties}/{ride0}", "push": "rideGroupWeather", "wait": 12},
        {"id": "04-route", "path": f"{prefix}/{slug}/{parcours}/{routes['forclaz']}", "wait": 12},
        {"id": "05-dashboard", "path": f"{prefix}/{slug}"},
        {"id": "06-routes", "path": f"{prefix}/{slug}/{parcours}"},
        {"id": "07-calendar", "path": "/calendrier" if fr else "/calendar"},
    ]


# ---------------------------------------------------------------- refresh


def listing(base: str, token: str, **params) -> list:
    """Every page of a club's publications matching `params`, the deleted ones left out:
    the API lists them too to a club admin, which the organizer is."""
    out, page = [], 0
    while True:
        query = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in
                         {**params, "status": "PUBLISHED", "view": "FULL", "page": page, "size": 100}.items())
        resp = call("GET", f"{base}/publications?{query}", token=token)
        out += [p for p in resp["publications"] if not p.get("deleted")]
        page += 1
        if page * 100 >= resp["total"]:
            return out


def find_club(fr: bool, org: str) -> str:
    name = club_name(fr)
    teams = call("GET", f"/api/teams?minRole=ADMIN&search={urllib.parse.quote(name)}", token=org)["teams"]
    slugs = [t["slug"] for t in teams if t["name"] == name]
    if not slugs:
        raise RuntimeError(f"no club named {name!r}: run the full seed (--target prod) first")
    return slugs[0]


def club_assets(base: str, org: str, lang: str) -> tuple:
    """The club's route slugs and place ids, by the keys of ROUTES and PLACES."""
    routes = {r["name"]: r["slug"] for r in call("GET", f"{base}/routes?size=100", token=org)["routes"]}
    places = {p["name"]: p["id"] for p in call("GET", f"{base}/places?size=100", token=org)["places"]}
    return ({r["key"]: routes[r[lang]] for r in ROUTES}, {k: places[p[lang]] for k, p in PLACES.items()})


def ensure_member(slug: str, viewer: dict) -> None:
    """Fails the run when the test account isn't in the club (a reviewer left it, or a
    rebuild stopped before adding it): a club admin can neither add nor invite it
    back (TEAM_ADD_MEMBER_NOT_ALLOWED), and a TEAM club can't be joined."""
    try:
        if call("GET", f"/api/teams/{slug}", token=viewer["token"]).get("role"):
            return
    except ApiError as e:
        if e.status not in (403, 404):
            raise
    raise RuntimeError(f"{TESTER} is not a member of {slug}: add it back by hand, or rebuild (--target prod)")


def refresh_club(locale: str, acc: dict, viewer: dict) -> None:
    lang = locale[:2]
    fr = lang == "fr"
    org = acc["julien"]["token"]
    slug = find_club(fr, org)
    base = f"/api/teams/{slug}"
    print(f"  club {slug}")
    ensure_member(slug, viewer)
    tags = ensure_tags(base, org, lang)
    now = datetime.now(TZ)
    today = now.date()

    def upcoming_rides() -> list:
        rides = sorted(listing(base, org, type="RIDE", **{"from": iso(now)}), key=lambda r: r["dateTime"])
        out = []
        for r in rides:
            groups = r.get("groups") or call("GET", f"{base}/rides/{r['slug']}", token=org)["groups"]
            out.append((r["slug"], instant(r["dateTime"]),
                        [g["id"] for g in sorted(groups, key=lambda g: g["sortOrder"])], r))
        return out

    # The calendar's end moves forward, one day at a time.
    rides = upcoming_rides()
    last = rides[-1][1].date() if rides else today
    new = calendar(fr, last + timedelta(days=1), today + CALENDAR_AHEAD)
    if new:
        routes, places = club_assets(base, org, lang)
        for spec in new:
            create_ride(base, acc, fr, routes, places, tags, spec,
                        random_signups(spec[2], len(spec[3]), f"{locale}-{spec[2]:%Y%m%d}"))
        rides = upcoming_rides()

    # Rides drawing near fill up with the members they always drew.
    topped = 0
    for ride_slug, when, gids, ride in rides:
        joins = random_signups(when, len(gids), f"{locale}-{when:%Y%m%d}")
        if ride["participantCount"] >= len(joins):
            continue
        for key, g in joins.items():
            topped += join_ride(base, ride_slug, gids[g], acc[key]["token"])
    print(f"  {topped} registrations added")

    # The test account rides its next ride and a few more, in the intermediate group.
    # A reviewer who unregistered is registered again for the next one.
    joined = 0
    wanted = tester_rides([r[:3] for r in rides], locale)
    for ride_slug, when, gids, _ in rides:
        if ride_slug in wanted:
            joined += join_ride(base, ride_slug, gids[len(gids) // 2], viewer["token"])
    print(f"  test account registered to {joined} more rides")

    # Its next ride carries comments from other members, as the test account sees
    # them: one it reported or whose author it blocked doesn't count.
    mine = listing(base, viewer["token"], type="RIDE", participating="true", **{"from": iso(now)})
    if mine:
        next_slug = min(mine, key=lambda r: r["dateTime"])["slug"]
        comments = call("GET", f"{base}/rides/{next_slug}/comments?size=50", token=viewer["token"])["items"]
        if not any((c.get("author") or {}).get("id") not in (None, viewer["id"]) and not c.get("deleted")
                   for c in comments):
            comment_thread(base, next_slug, acc, viewer, lang, today.toordinal() // 7)
            print(f"  comment thread on {next_slug}")

    # A trip always ahead.
    if not listing(base, org, type="TRIP", **{"from": iso(now)}):
        routes, places = club_assets(base, org, lang)
        create_trip(base, acc, fr, routes, places, tags, next_weekday(5, time(8, 0), 15))

    # The month's programme, on its first refresh. Found by its title, not its date:
    # a post dated in the previous month would otherwise be written twice.
    title, text = month_post(fr, today.replace(day=1))
    if not any(p["name"] == title for p in listing(base, org, type="POST")):
        call("POST", f"{base}/posts", {"name": title, "media": media(text), "dateTime": wall(now),
                                       "status": "PUBLISHED", "visibility": "TEAM",
                                       "tagIds": tag_ids(tags, "POST", ["programme"])}, org)
        print(f"  post {title!r}")


def unblock_all(viewer: dict) -> None:
    """Lifts the test account's blocks: a reviewer tries blocking, the next one must
    still see every member."""
    for user in call("GET", "/api/users/me/blocks", token=viewer["token"])["users"]:
        call("DELETE", f"/api/users/me/blocks/{user['id']}", token=viewer["token"])
        print(f"  unblocked {user['displayName']}")


def ping(suffix: str = "", body: str = "") -> None:
    if not PING_URL:
        return
    try:
        urllib.request.urlopen(urllib.request.Request(PING_URL + suffix, data=body.encode()[:10000]), timeout=10)
    except OSError as e:
        print(f"  ping failed: {e}")


def refresh() -> None:
    ping("/start")
    try:
        tester = tester_account()
        if os.environ.get("SEED_ACCOUNTS") and not ACCOUNTS.exists():
            # On the production host: a missing file would mean resetting every
            # password, over an SSH the host doesn't have.
            raise RuntimeError(f"SEED_ACCOUNTS names {ACCOUNTS}, which doesn't exist")
        accounts = load_accounts()
        print(f"▸ accounts on {API}")
        # A password this file doesn't know is reset over SSH, as in a full run: the
        # first refresh from a workstation writes the file the production host keeps.
        people = {k: ensure_account(accounts, k, n) for k, n in MEMBERS.items()}
        save_accounts(accounts, list(MEMBERS))
        unblock_all(tester)
        for locale in ("fr-FR", "en-US"):
            print(f"▸ club {locale}")
            refresh_club(locale, people, tester)
    except Exception as e:
        ping("/fail", f"{type(e).__name__}: {e}")
        raise
    ping()
    print("✔ refreshed")


# ---------------------------------------------------------------- main


def main() -> None:
    if REFRESH and not DRY_RUN:
        refresh()
        return
    if DRY_RUN:
        print(json.dumps({"target": TARGET, "api": API, "members": MEMBERS,
                          "viewers": {"fr-FR": TESTER, "en-US": TESTER} if PROD else VIEWERS,
                          "routes": [r["key"] for r in ROUTES]}, indent=2, ensure_ascii=False))
        if PROD:
            today = datetime.now(TZ).date()
            for fr in (True, False):
                spec = calendar(fr, today + timedelta(days=1), today + CALENDAR_AHEAD)
                print(f"{'fr' if fr else 'en'}: {len(spec) + 4} rides, "
                      f"{spec[0][2]:%d/%m/%Y} → {spec[-1][2]:%d/%m/%Y}")
        return
    tester = tester_account() if PROD else None
    accounts = load_accounts()
    print(f"▸ accounts on {API}")
    people = {k: ensure_account(accounts, k, n) for k, n in MEMBERS.items()}
    if PROD:
        viewers = {"fr-FR": tester, "en-US": tester}
        for acc in people.values():
            mute_email(acc)
    else:
        viewers = {loc: ensure_account(accounts, key, n) for loc, (key, n) in VIEWERS.items()}
    julien = people["julien"]["email"]
    sql("UPDATE users SET platform_role = 'PLATFORM_ADMIN' WHERE email = '%s';" % julien)
    try:
        # The token was minted before the promotion: sign in again to carry the role.
        accounts["julien"].pop("token", None)
        people["julien"] = ensure_account(accounts, "julien", MEMBERS["julien"])

        plan = {"api": API, "locales": {}}
        for locale, viewer in viewers.items():
            print(f"▸ club {locale}")
            plan["locales"][locale] = {"screens": seed_club(locale, people, viewer)}
    finally:
        if PROD:
            # No fictional account keeps a platform role on prod.
            sql("UPDATE users SET platform_role = NULL WHERE email = '%s';" % julien)
            print("  organizer's platform role taken back")

    save_accounts(accounts, list(MEMBERS) + ([] if PROD else [key for key, _ in VIEWERS.values()]))
    if PROD:
        print(f"✔ {ACCOUNTS.name} written")
        return
    PLAN.write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n")
    print(f"✔ {PLAN.name} and {ACCOUNTS.name} written")

if __name__ == "__main__":
    main()
