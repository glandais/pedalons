# Operations

How Pedalons is deployed, backed up and restored on a host. Workstation setup stays in the
[README](../README.md); this is the server side.

## Deployment

A host is a single-node **Docker Swarm**, and runs **one shared stack** plus **one stack per
environment**, each from its own checkout (`~/shared`, `~/prod`, `~/staging`) with its own `.env` —
and a monitoring stack, from `~/shared` too (see [Monitoring](#monitoring)).
Caddy terminates TLS on the host and reverse-proxies each hostname to that environment's traefik
(`HTTP_PORT`: 8090 for prod, 8089 for staging). Swarm rather than plain compose for what it
reconciles: a `deploy` converges the running services onto the file, and a task that dies is
rescheduled rather than left for a `restart:` policy.

`docker-compose.shared.yml` holds what carries no application data and is read-only: `tileserver`
(server-side raster rendering, ~1.8 GB resident). One instance serves every environment. It owns
the `pedalons-shared` overlay network. Route computation is not hosted at all any more: it is
bought from Stadia Maps, with a key per environment, and so is geocoding (see
[Stadia Maps: routing and geocoding](#stadia-maps-routing-and-geocoding)).

`docker-compose.yml` holds everything that must stay isolated per environment: traefik, backend,
frontend, postgres, minio, imgproxy and varnish — and goatcounter, which runs in production only
(see [Web analytics](#web-analytics-goatcounter)). Its `backend` also joins `pedalons-shared` to reach
the shared service, by its service name `tileserver`.

Each environment's `.env` differs from a workstation's in five keys only — see
[The `.env`, on a workstation and on a server](../README.md#the-env-on-a-workstation-and-on-a-server).
The same `docker-compose.yml` also runs on a workstation, under plain compose, to test a build:
[Running the full stack locally](../README.md#running-the-full-stack-locally). It therefore stays
valid for both tools — its header lists what each one ignores.

**Always deploy through `scripts/deploy.sh`**, never `docker stack deploy` by hand:

- `docker stack deploy` reads **no `.env`**. Every `${VAR}` of the file would expand to nothing —
  image tags, memory limits, ports — and a default would silently take its place;
- it picks the **build of the checked-out commit**, `pedalons-backend:${ENV_NAME}-<sha12>` (see
  [Rolling updates](#rolling-updates-and-rollback)), and refuses a checkout with uncommitted changes;
- the stack must be named after `ENV_NAME`: the backup scripts find its containers and volumes
  (`${ENV_NAME}_postgres_data`) by that name.

```bash
# once per host — the firewall unit (see "Only Caddy may reach traefik") before the swarm
docker swarm init
cd ~/shared && scripts/deploy.sh --shared

# then each environment, on every deploy
cd ~/prod && ./build.sh && scripts/deploy.sh
docker stack ps "$ENV_NAME"        # what is running, and why a task was rejected

# teardown — keeps the volumes
docker stack rm "$ENV_NAME"
```

Swarm ignores `depends_on`. The backend therefore waits for its dependencies at boot: Flyway retries
the database for about a minute, and the S3 bucket check retries MinIO for as long. That covers a
stack's first deploy, and every deploy that changes postgres's or minio's spec, since Swarm stops
them (stop-first) while the new backend boots. On a first deploy, `docker stack ps` may still show
varnish `Failed` with `(2)` when it starts before `imgproxy` resolves; its replacement is the one
running, so there is nothing to do.

### Rolling updates and rollback

`./build.sh` tags each image twice: `pedalons-backend:${ENV_NAME}-<sha12>`, never moved once
written, and `pedalons-backend:${ENV_NAME}`, the latest build (what a workstation runs). From a
checkout with uncommitted changes it writes the second only. No registry: on a single-node swarm the
images built on the host are all Swarm needs, and it merely warns that it cannot record a digest.

A deploy of a new commit changes the image in the backend and frontend specs, and Swarm rolls them
**start-first**: the new task boots beside the old one, which keeps serving until the new one's
healthcheck passes (`/q/health/ready`, i.e. after Flyway). traefik health-checks both too, and the
old task reports itself not ready for 15 s after SIGTERM (`quarkus.shutdown.delay`; `/health` in
the frontend's `server.js`) before it drains, so no request lands on a stopping task. A new task
that never turns healthy is rolled back on its own (`failure_action: rollback`), and
`scripts/deploy.sh` waits for that outcome: it returns once backend and frontend both run the new
build, healthy, and exits non-zero on a rollback or after `DEPLOY_TIMEOUT` seconds (600 by default)
— a deploy that printed no error is one that went through. postgres, minio,
imgproxy and varnish keep the default stop-first: each owns a volume, one instance at a time. So does
goatcounter, spelled out in its file: it migrates its own database at start (`-automigrate`), and two
instances would migrate it at once. `deploy.sh` does not wait for it.

```bash
docker service ps "${ENV_NAME}_backend"           # the rollout, and why a task failed
docker service rollback "${ENV_NAME}_backend"     # back to the previous spec, i.e. the previous build
scripts/deploy.sh --rev HEAD~1                    # or any earlier commit still built
```

`deploy.sh` keeps the last five builds per image (and whatever a service runs or would roll back
to), and drops the older ones; `--rev` of a dropped commit means `git checkout` + `./build.sh`.

**For about a minute, two backends run against the same database.** What that asks of the code:

- **Flyway migrations stay backward compatible** — the previous release must run on the new
  schema. Renaming or dropping a column takes two deploys: add and write both, then drop.
- **Scheduled jobs may run on both.** Those that claim their work in the database
  (`for update skip locked`: notifications, webhooks, user exports) are safe; any other job must be
  idempotent, since `concurrentExecution = SKIP` only guards within one JVM.
- **`data/cache` is shared** by the two for that while — the cache race described below.

A `.env` value changed on the host takes effect on the next `scripts/deploy.sh`: `env_file` is read
at deploy time and a new value rolls the backend.

### Memory

Every service carries a memory limit under `deploy.resources.limits` — Swarm and compose both
apply it, so a workstation runs under the same ceilings as a host. A container that crosses its
limit is killed by the kernel (`OOMKilled` in `docker inspect`, `task: non-zero exit (137)` in
`docker stack ps`) and Swarm starts a new one.

| Service | Limit | What it covers |
|---|---|---|
| backend | `BACKEND_MEMORY`, 1536M | JVM heap = 60 % of the limit; the rest is metaspace (capped at 256 MB), code cache, threads, Netty buffers, Magika's ONNX runtime |
| varnish | `VARNISH_MEMORY`, 1536M | the image cache, **in memory**: `VARNISH_SIZE`, 1G |
| imgproxy | 1536M | 4 images at once (`IMGPROXY_WORKERS`), each up to 50 Mpx |
| postgres | 1G | `shared_buffers` 128 MB, 20 pooled connections, autovacuum |
| minio | 1G | |
| frontend | 512M | Node sizes its heap from the limit |
| traefik | 256M | |
| goatcounter | 128M | production only; 36 to 40 MiB at rest, the rest for CSV exports and the dashboard |
| tileserver (shared) | 3G | ~1.8 GB resident |
| monitoring stack | 2G in all | see [Monitoring](#monitoring); ~1 GB resident |

**The backend has no `-Xmx`.** The image's entrypoint (`run-java.sh`, from the Jib base image
`ubi9/openjdk-25-runtime`) passes `-XX:MaxRAMPercentage=$JAVA_MAX_MEM_RATIO`, and the ratio is
baked into the image by `quarkus.jib.environment-variables` in `application.properties`. The heap
therefore follows `BACKEND_MEMORY` on its own; raising the limit is the one knob. Without any limit
the same entrypoint would size the heap on the whole host: 80 % of its RAM. Check what a running
backend got:

```bash
docker exec "$(docker ps -qf name=${ENV_NAME}_backend)" sh -c \
  'java -XX:+PrintFlagsFinal -XX:MaxRAMPercentage=${JAVA_MAX_MEM_RATIO} -version | grep MaxHeapSize'
docker stats --no-stream        # usage against each limit
```

**Varnish's cache size and its limit go together.** `VARNISH_SIZE` is malloc storage, so it is
resident memory once the cache fills; keep `VARNISH_MEMORY` about half as much again. It used to be
20 G with no limit at all. A smaller cache only costs imgproxy CPU on a miss.

**What a host must hold**: these are ceilings, not usage — but a host should hold the sum of them.
Per environment, 7.3 GB (7.4 GB in production, with goatcounter), plus 2 GB during a rolling update (a second backend and frontend run
beside the old ones, see above); on top, the shared stack's tileserver (3 GB) and the monitoring
stack (2 GB). Two environments with the defaults come to about 23 GB with the host's own share
(Caddy, Docker, the OS): a 32 GB host holds them with room to spare — since 2026-10-17 no routing
tiles compete for its page cache (`OPS-48`). A staging environment can take less through its own `.env` (`BACKEND_MEMORY=1G`,
`VARNISH_SIZE=256M`, `VARNISH_MEMORY=512M`); prod, more `BACKEND_MEMORY` if `docker stats` shows the
backend near its limit.

### Only Caddy may reach traefik

**Swarm cannot publish a port on the loopback.** Given `127.0.0.1:8090:80`, it drops the address
with a mere warning and listens on every interface — which is why `docker-compose.yml` does not
pretend to. And `ufw` cannot close it either: Docker inserts its rules ahead of ufw's. The rule has
to go into the `DOCKER-USER` chain, which Docker consults first and never rewrites — one per
environment port, on the public interface.

**IPv6 bypasses `DOCKER-USER`.** The routing mesh has no IPv6 NAT: Docker serves a published port on
`[::]` through a `docker-proxy` listening on the host itself, so the packets go through `INPUT` and
the proxy relays them over IPv4 from the host. The script therefore also drops each of these ports in
`INPUT`, v4 and v6 (a no-op for IPv4). Without it traefik and Grafana answered from the Internet over
IPv6 (ledger `SEC-29`). Test from **another machine, over IPv6**, not only IPv4: no AAAA record is
not a protection.

`docker swarm init` also opens the swarm's own ports on every interface: 2377/tcp (cluster
management), 7946/tcp+udp (gossip) and 4789/udp — the VXLAN that carries the overlay networks, which
is **unauthenticated**: anyone who reaches it can inject packets into `pedalons-shared` or an
environment's network. A single-node swarm needs none of them from outside. They go through the
host's `INPUT` chain, not `DOCKER-USER`, and a host with no firewall (`-P INPUT ACCEPT`) leaves them
open.

Both sets of rules come from `scripts/pedalons-firewall.sh`, run by a systemd unit **before**
`docker.service`: Docker keeps an existing `DOCKER-USER` chain as it is, so no stack is ever up
without the rules — not even at boot. **Install it before `docker swarm init`**, IPv4 and IPv6
alike. Not `iptables-persistent`: it would save fail2ban's chains and Docker's too, which both
rebuild their own at start.

```bash
install -m 755 scripts/pedalons-firewall.sh /usr/local/sbin/pedalons-firewall.sh
install -m 644 scripts/pedalons-firewall.service /etc/systemd/system/pedalons-firewall.service
# The public interface: `eth0` on some hosts, `ens2`, `enp5s0` on others. A rule naming an interface
# the host does not have is accepted without a word, and drops nothing. TRAEFIK_PORTS (default
# "8089 8090") lists the HTTP_PORT of every environment.
echo "PUBLIC_IF=$(ip -o route get 1.1.1.1 | sed -n 's/.* dev \([^ ]*\).*/\1/p')" > /etc/default/pedalons-firewall
systemctl daemon-reload && systemctl enable --now pedalons-firewall.service
iptables -S DOCKER-USER                                   # one DROP per environment port
iptables -S FORWARD | head -3                             # -A FORWARD -j DOCKER-USER, first
iptables -S INPUT | grep -E '2377|7946|4789'              # four DROP; ip6tables alike
ip6tables -S INPUT | grep -E '8089|8090|3300'             # the IPv6 path, see above
curl -6 -m 4 http://[<host-ipv6>]:8090/                   # from another machine: must time out
```

`--ctorigdstport` matches the port as the client asked for it, before the routing mesh rewrites the
destination; Caddy, which comes in over the loopback, is untouched.

**Then check from another machine, once the first stack is up — it is part of the procedure, not an
option**: `curl -m 5 http://<host>:8090` must time out, while the site answers through Caddy, and
`nc -zv -w 3 <host> 2377` must fail. Nothing
on the host itself can tell: the loopback is not filtered, so a local `curl` succeeds either way.

Postgres, for the same reason, publishes no port at all on a host — a raw Postgres guarded by a
password alone has no business on a public interface. Reach it through `docker exec` (see
[Running SQL](../README.md#running-sql)); a workstation still gets `127.0.0.1:5432` from the overlay.

### Services that stay per-environment

Two services stay per-environment on purpose, even though they look shareable:

- **imgproxy/varnish** — imgproxy only takes a single global `IMGPROXY_S3_ENDPOINT`, so one instance
  cannot serve two MinIO backends. They become shareable if and when MinIO is shared.
- **the vcyclist cache** (`DATA_CACHE_PATH`) — per environment by choice, not by necessity. Two
  backends can share it safely (two of the same environment already do during a start-first
  update): map tiles (vcyclist ≥ 5.1.1) and elevation tiles (`DemTileFetcher`) are both written to a
  temp file then renamed into place, and only once they decode, so a reader never sees a partial
  file and an unreadable cached tile is fetched again (ledger `OPS-10`). Sharing it across
  environments would save the downloads; it is not done. The directory must stay on one filesystem
  (the rename is atomic only there). Keep it at
  `/mnt/cache`: pointed at `/tmp` it lives inside the container and is re-downloaded in full on every
  restart.

### Rate limiting

Traefik refuses a client past **50 requests per second on `/api` (bursts of 200) and 100 on the site
(bursts of 400)** with a `429` — the `ratelimit` middlewares on both routers of `docker-compose.yml`
(audit M10, ledger `SEC-28`). The thresholds are wide on purpose: a map pans in bursts of tiles, a
first visit loads every chunk, and a club behind one address is still one client. They come from
`RATE_LIMIT_API_AVERAGE`, `…_BURST`, `RATE_LIMIT_FRONTEND_AVERAGE` and `…_BURST` in `.env` when set.
It sits beside the per-address counters of the backend (`AuthThrottle`, ledger `SEC-7`), which
stop a guess at one account; this one stops one client flooding everything.

**The client is the last `X-Forwarded-For` hop** (`ipStrategy.depth=1`), which is right only
because Caddy is the only way in (the section above) and **replaces** the header a client sends
rather than appending to it — Caddy's default while no `trusted_proxies` is configured. Traefik
cannot use the connection's address: that is Caddy's, the same for everyone. So:

- a proxy put in front of Caddy (a CDN, another reverse proxy) makes every client one: set
  `trusted_proxies` in Caddy for it, so the last hop is the visitor again;
- the server-side renders call the backend directly (`API_BASE_URL`), not through Traefik: they
  are bounded by the frontend's limit, not counted twice;
- a stack with nothing in front (the e2e one) sees no header and one client: `.env.e2e` lifts the
  limit.

**Check once deployed**: from outside, a burst of ~300 requests on `/api/config` must end in `429`s,
and a second machine must stay answered meanwhile — if it does not, every client shares one bucket
and the header is not what this section expects.

```bash
seq 300 | xargs -P 50 -I{} curl -s -o /dev/null -w '%{http_code}\n' https://<host>/api/config | sort | uniq -c
```

### Content Security Policy

The site's CSP is set by the frontend's `server.js` (`frontend/server/csp.js`, ledger `SEC-31`), not
by Traefik: each page carries a fresh nonce for its inline scripts, and the map hosts of its
`/api/config`. Traefik's `site-headers` middleware therefore sets **no** `contentSecurityPolicy` — it
would overwrite the one `server.js` sends. The API keeps **no CSP at all**: it would override the
sandbox policy of downloads (`UploadedContentHeaders`, ledger `SEC-1`) and stop the PDF viewer.

| Response | Header |
|---|---|
| Everything `server.js` answers | `Content-Security-Policy: frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'self'` (ledger `SEC-30`) |
| SSR pages, `CSP_MODE` unset or `report-only` (the default) | the above, plus the full policy as `Content-Security-Policy-Report-Only` |
| SSR pages, `CSP_MODE=enforce` | the full policy as `Content-Security-Policy` |

The full policy allows scripts from the site and by nonce only, styles inline (Mantine), images from
any `https:` host (markdown), and `connect-src` to the site plus the hosts `/api/config` names: style
documents and dark variants, the tile hosts of the raster basemaps the backend wraps
(`/api/map/styles/{id}.json`, read by `server.js` and kept ten minutes), the terrain TileJSON, and
Firebase when web push is configured. A third-party style is assumed to keep its sprite, glyphs and
tiles on its own host (true of VersaTiles and IGN); one that does not needs its hosts in
`CSP_CONNECT_SRC_EXTRA` (space-separated origins, in `.env`).

**Violations** are posted by browsers to `POST /csp-report` (a `server.js` route, under the site
router, not the API) and logged as one JSON line each — URLs without query or fragment, at most
120 lines a minute for all senders together, then a `{"dropped":n}` line:

```
{stack="pedalons-prod", service="frontend"} |= "[csp-report]"
```

Anyone can post to that route, so a report is not proof on its own: read for a pattern across many
clients and pages. A flood of forged reports can also use up the shared 120-line budget and hide
real ones for the rest of the minute (ledger `SEC-40`).

**Changing a map provider** under `CSP_MODE=enforce`: the raster tile hosts are cached ten minutes by
`server.js`, so restart the frontend service with the backend (`docker service update --force
<stack>_frontend`), or the new basemap stays blocked until the cache expires.

**Going to enforce**: leave report-only in place on staging and prod long enough to see every page
and basemap used, read the reports (an empty week, or only browser extensions — `blockedURL` of
`chrome-extension`, `moz-extension` — is the signal), then set `CSP_MODE=enforce` in `.env` and
`scripts/deploy.sh`. Rolling back is the same variable set back. **Check once deployed**:

```bash
curl -sI https://<host>/ | grep -i -E '^content-security-policy|^reporting-endpoints'
curl -sI https://<host>/api/version | grep -ic content-security-policy        # 0
curl -sI https://<host>/assets/<any>.js | grep -i content-security-policy     # the SEC-30 four only
```

### Access logs

The host's Caddy writes the **only** access log: Traefik's is off (`--accesslog=false` in
`docker-compose.yml`), since it cannot filter a query parameter and its file, with no volume, died
with the container anyway. The privacy policy (§1, §6) makes two promises about that log, and both
live in the host's Caddy configuration, outside this repository:

- **Nothing sensitive from the query string.** Three kinds of parameters are written away before
  the line is:
  - credentials, because their client fetches them outside the authenticated HTTP stack and
    cannot set a header — `?t=` on `/api/…/tiles/{z}/{x}/{y}.mvt` (the tile token, ~15 min, see
    `TileTokenService`; MapLibre fetches tiles itself, so dozens of lines per map session),
    `?token=` on the ICS calendar feed (it only expires after 90 days *without a fetch*, `SEC-17`: a feed still polled stays valid for ever), and the OAuth
    `?code=`/`?state=` of the GPS-service callbacks;
  - the device's position: `?lat=`/`?lon=` from the Garmin app (`DeviceRoutesResource`),
    `?nearLat=`/`?nearLon=` from "around me" and the ad proximity probe.
- **14 days**, then deleted.

```caddyfile
# {args[0]}: the log file's name, so each stack gets its own file under the logrotate glob.
(pedalons_access_log) {
	log {
		output file /var/log/caddy/{args[0]}.log {
			roll_disabled          # logrotate owns the rotation, below
		}
		format filter {
			request>uri query {
				replace t REDACTED
				replace token REDACTED
				replace code REDACTED
				replace state REDACTED
				# A path to come back to after signing in — it can hold a token (an export link).
				replace next REDACTED
				delete lat
				delete lon
				delete nearLat
				delete nearLon
			}
			# A redirect's Location repeats the raw query string, filter or not.
			resp_headers>Location delete
			# So does the Referer of every asset a page loads: the page's full URL, query and all.
			request>headers>Referer delete
		}
	}
	# The web analytics' pageview requests are not logged at all (see « Web analytics »).
	# log_skip since Caddy 2.8, skip_log before.
	@count path /count
	log_skip @count
}

# The bare domain only redirects, but {uri} carries the query string: it logs through the snippet too.
pedalons.fr {
	import pedalons_access_log pedalons-access
	redir https://www.pedalons.fr{uri}
}

www.pedalons.fr {
	import pedalons_access_log pedalons-access
	reverse_proxy 127.0.0.1:8090
}

staging.pedalons.fr, staging.np.pedalons.fr {
	import pedalons_access_log pedalons-staging-access
	reverse_proxy 127.0.0.1:8089
}
```

Three traps, each met on the first install (29 September 2026):

- **`www.pedalons.fr` is the application**, `pedalons.fr` a redirect. Both must import the snippet:
  the redirect sees the same query string.
- **`resp_headers>Location`**: without its `delete`, the redirect's log line carries
  `?lat=…&t=…` in clear in the `Location` header, next to a correctly filtered `uri`.
- **`next` and `Referer`** (ledger `OPS-24`): a data-export link opened without a session is sent
  to `/login?next=/api/export/download?token=…`, so the token rides in `next`, which no `replace`
  named; and the login page's assets then carry that whole URL as their `Referer`. A token must
  never be in a URL path (ledger `API-45`): a query parameter is the only place this filter reaches.
- **`caddy validate` run as root creates the log files as `root:root 0600`**, which Caddy (user
  `caddy`) then cannot open on reload. After any `validate`, `chown caddy:caddy` the **files**, not
  just `/var/log/caddy`.

**`/count` never reaches the log** (`log_skip`, in the snippet): one line per pageview, with the
visitor's IP, user agent, time, host and page, would be each address's browsing history, kept 14
days here and 14 more in Loki — and the privacy policy says the web analytics keep no IP. The trap
grows with the platform: **every club domain and every alias has its own Caddy block, and each must
import the snippet**; a block that does not logs `/count` in clear. Check it on every new domain,
and check `caddy version` once (`log_skip` needs 2.8; `skip_log` before).

Credentials are replaced rather than deleted, so a line still shows that one was there; the
position leaves no trace. Caddy already leaves `Authorization` and `Cookie` headers out of its log.
Rotation, from the repository like the backup logs:

```bash
mkdir -p /var/log/caddy && chown caddy:caddy /var/log/caddy
install -m 644 scripts/caddy-access.logrotate /etc/logrotate.d/caddy-access
logrotate -d /etc/logrotate.d/caddy-access     # dry run: must list every *-access.log
```

Check it bites after `systemctl reload caddy`, on the application **and** on the redirect:

```bash
for h in www.pedalons.fr pedalons.fr staging.pedalons.fr; do
  curl -s -o /dev/null "https://$h/api/version?lat=1&t=x"
done
tail -n 3 /var/log/caddy/pedalons-access.log /var/log/caddy/pedalons-staging-access.log
```

Every line must show `t=REDACTED`, no `lat`, and no `Location` header. And `/count` must leave
none: `curl -s -o /dev/null "https://$h/count?p=/log-check"` for each host, then
`grep -c '/count' /var/log/caddy/*-access.log` stays at 0. Keep
`/etc/caddy/Caddyfile.bak-<date>` until then; rolling back is restoring it and reloading. Installed
on the production host on 29 September 2026 (ledger `OPS-6`). The short TTL of the tile token is
what makes any line written before that inert, and the reason that TTL must never be raised to
hours.

### Ride weather (Open-Meteo)

Each backend keeps its own forecast cache from Open-Meteo, in its own database (`weather_cells`,
`weather_hourly`, `weather_daily`, migration V61): a planner (every 5 min) lists the ~5 km cells the
published rides of the next 7 days need, a worker (every minute) refreshes the due ones, and a
nightly job (03:40) purges the old hours and the cells nobody asked for in 2 days. The API **only
reads that cache** — no request ever waits on Open-Meteo, and a provider outage shows the last
forecast flagged as old, never an error. Design and decisions: ledger `API-74`.

All optional, in `.env` (commented in `.env.example`):

| Key | Default | What it does |
|---|---|---|
| `OPEN_METEO_URL` | `https://api.open-meteo.com` | The free endpoint. A commercial plan is its own host (`https://customer-api.open-meteo.com`) |
| `OPEN_METEO_API_KEY` | empty | Sent only when set. It travels as a query parameter, so nothing logs the request URL |
| `OPEN_METEO_DAILY_CALL_BUDGET` | `5000` | Locations asked for per UTC day, by **this** backend (free plan: 10 000) |
| `OPEN_METEO_HOURLY_CALL_BUDGET` | `4500` | The same per sliding hour (free plan: 5 000) |
| `OPEN_METEO_PER_MINUTE_CALL_BUDGET` | `500` | The same per sliding minute (free plan: 600) |
| `WEATHER_ENABLED` | `true` | `false` stops every call to the provider; what is cached is still shown until it ages out |

The budgets are counted **in memory, per backend**: they reset on restart, and two backends add
up. Open-Meteo counts per egress address, and **prod and staging leave this host by the same
one**: together at their defaults they reach the free plan's 10 000 a day. Give staging smaller
budgets (or `WEATHER_ENABLED=false` when nobody looks at it); the free plan is also for
non-commercial use only — a paid plan is `OPEN_METEO_URL` + `OPEN_METEO_API_KEY` and higher
budgets, no code change.

What to look for in the backend logs: `Open-Meteo circuit open for 10 min` (three failures in a
row, or a `429`: refreshes wait for the next full hour), `daily Open-Meteo call budget spent`
(paused until 00:00 UTC), `Weather: Open-Meteo request for N cell(s) failed`. In the database,
a healthy cache has recent `fetched_at` and `attempts = 0`:

```bash
docker exec "$(docker ps -qf name=${ENV_NAME}_postgres)" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "select count(*), max(fetched_at), max(attempts), max(last_error) from weather_cells"'
```

### Automatic route sync to GPS services

A member who connected Hammerhead, Wahoo or Garmin can turn on « envoi automatique » for that
connection (`gps_service_connections.auto_sync`, off by default): the backend then puts the route of
every group they are registered in, leaving within 7 days, on their account at the service, updates
it when the route or its GPX changes, and deletes it 24 h after the group's departure or as soon as
the registration, the route or the switch goes away. Disconnecting the service and erasing the
account delete the automatically sent routes too, best effort. Design and decisions: ledger
`API-120`, plan [`2026-10-16-gps-route-autosync.md`](plans/2026-10-16-gps-route-autosync.md).

Two scheduled jobs do it, never during an HTTP request: a planner (every 60 s) writes the state
each connection should hold into `gps_route_syncs`, and a worker (every 20 s) makes the calls to
the services under a 5-minute lease — at most 30 calls and 10 s per tick, to stay under the
providers' quotas.

| Key | Default | What it does |
|---|---|---|
| `GPS_SYNC_ENABLED` | `false` | `true` starts the planner and the worker, and makes `/api/config` serve `gpsAutoSyncEnabled: true`, which shows the switch in the web and mobile clients |

The window (`pedalons.gps-sync.horizon=P7D`) and the retention after departure
(`pedalons.gps-sync.retention=P1D`) are plain properties, not `.env` keys. **Prod and staging run
with `GPS_SYNC_ENABLED=true`** since 16 October 2026; the privacy policy describes the feature
(ledger `LEGAL-21`).

**Turning it off freezes, it does not clean up.** With `false`, the planner and the worker stop:
routes already sent stay at the services, and are no longer updated or removed, even after the
ride — the policy promises that removal. The switch disappears from the clients, the stored
`auto_sync` values are kept, and turning the flag back on resumes from them (the planner catches up
on its first pass). Manual sends (« Envoyer vers l'appareil ») work either way: they go through the
same table but never depend on the flag.

What to look for in the backend logs: `Route sync N: <service> <op> failed (…)` (one call failed;
the row is retried with a backoff), `token refresh refused` (the connection now needs a
reconnection), `Route sync planning failed` / `Route sync failed` (a whole tick failed). A `401`
or a Garmin `412` marks the connection « à reconnecter » (`sync_reconnect_required_at`), a `429`
pauses it until `Retry-After` (`sync_paused_until`). In the database, a healthy sync has rows
with `attempts = 0` and no `last_error`:

```bash
docker exec "$(docker ps -qf name=${ENV_NAME}_postgres)" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "select (ride_id is not null) as automatic, count(*), count(external_route_id) as at_service,
          max(attempts), max(last_error), max(synced_at) from gps_route_syncs group by 1"'
```

### Web analytics (GoatCounter)

The site's audience is measured by a self-hosted [GoatCounter](https://www.goatcounter.com), the
`goatcounter` service of `docker-compose.yml`, with its own database `goatcounter` on the
environment's postgres. Design, what is counted and why: `docs/plans/2026-10-15-web-analytics.md`
(ledger `OPS-36`). What this section keeps true is the privacy policy's promise: **pageviews only,
no cookie, no session, no IP kept**.

- **Production only.** Its `.env` sets `GOATCOUNTER_VHOST`, `GOATCOUNTER_DB_PASSWORD` and
  `GOATCOUNTER_ADMIN_EMAIL` (`.env.example`); staging sets none, and `deploy.sh` then runs
  goatcounter at 0 replicas — a service with no task gives Traefik no router, so `/count` there falls
  to the site's 404 page. `deploy.sh` refuses one of the first two keys without the other, and
  `PEDALONS_ANALYTICS_COUNT_PATH` (the site's own switch, served in `/api/config`) without them. On a
  workstation and in the e2e stack it sits behind a profile, `analytics`, that nothing enables.
- **One GoatCounter site for every host.** Traefik routes `Path(/count)` on every host that reaches
  it, so a club domain needs nothing here (but see [Access logs](#access-logs)), and its
  `count-headers` middleware rewrites `Host` to `GOATCOUNTER_VHOST` and strips `Cookie`, `Referer`
  and the client-settable IP headers (`X-Real-Ip`, `Cf-Connecting-Ip`, `Fly-Client-Ip`,
  `X-Azure-Socketip`), so the IP GoatCounter reads is the one Caddy wrote. The club's host travels in
  the counted path.
- **Not in the backup.** The statistics are disposable: `backup.sh` dumps `POSTGRES_DB` only, and
  `restore.sh` recreates an empty `goatcounter` database (below).
- **Not waited for by `deploy.sh`**, and off the site's path: a GoatCounter that does not start fails
  no deploy.

#### First deployment

The service is deployed before its database role exists, so it **restarts in a loop** until the
first command below — expected, and harmless (`pq: password authentication failed`; the DSN carries
no password, which goes through `PGPASSWORD`).

```bash
# .env: GOATCOUNTER_VHOST=stats.pedalons.internal, GOATCOUNTER_DB_PASSWORD=$(openssl rand -hex 24),
#       GOATCOUNTER_ADMIN_EMAIL=<the controller's address>
scripts/deploy.sh
scripts/goatcounter-init.sh db       # role + database, GoatCounter restarted and migrated
scripts/goatcounter-init.sh site     # from a terminal: site + account (password prompted), settings
```

Both are idempotent, and do nothing where `GOATCOUNTER_VHOST` is empty. No secret goes on a command
line: the SQL reaches `psql` on its standard input, the account's password through GoatCounter's
prompt. `db` sets the role's password from `.env` on every run — after changing it in `.env`, run
`deploy.sh` then `db`.

#### Settings

A new GoatCounter site starts with **sessions on** — and with sessions on, GoatCounter writes
`<user agent>-<IP>-<site>` in clear into its `store` table on every shutdown. `goatcounter-init.sh
site` therefore stops GoatCounter **before** creating the site (from a one-off container of the same
image, in the postgres container's network namespace), sets them by SQL, deletes any session a
shutdown wrote, and only then starts it again: no hit is ever counted with the defaults, even with
live traffic on `/count` (after a restore, the site's switch still set). GoatCounter caches its
settings, hence the stop. The script fails unless they read back:

| Setting (*Settings* page, 2.7) | Value | Column |
|---|---|---|
| *Data collection* | **Referrer**, **User-Agent**, **Size**, **Country** checked; **Sessions**, **Region**, **Language**, **Individual pageviews** unchecked | `settings.collect = 30` |
| *Data retention in days* | **730** (24 months, aggregated tables included) | `settings.data_retention = 730` |
| *Dashboard viewable by* | Only logged in users (the default) | `settings.public = private` |
| *Allow adding visitor counts on your website* | unchecked (the default) | `settings.allow_counter` |
| API tokens | none | |

**Never tick a box back on in *Settings***: *Sessions* brings back the clear `<user agent>-<IP>` keys,
*Individual pageviews* a row per pageview. Re-running `goatcounter-init.sh site` puts the values
above back. To check them, and that nothing per visitor is kept:

```bash
pg() { docker exec -i "$(docker ps -qf name=${ENV_NAME}_postgres)" sh -c 'psql -U "$POSTGRES_USER" -d goatcounter -tA'; }
echo "select settings->>'collect', settings->>'data_retention', settings->>'public' from sites" | pg   # 30|730|private
echo "select count(*) from hits" | pg                                          # 0
echo "select value from store where key = 'session'" | pg                      # empty maps only
echo "select min(day) from hit_stats" | pg                                     # never older than 730 days
```

**The retention purge** runs once a day, **24 h after GoatCounter starts**, and its timer restarts
with it: a GoatCounter restarted every day never purges. Look at `min(day)` now and then.

**Once a year, review the retention** (the CNIL recommends reviewing it periodically): is 730 days
still what the five questions of the plan need? If it changes, change `DATA_RETENTION` in
`scripts/goatcounter-init.sh`, re-run `site`, and rewrite the privacy policy's « 24 mois » / « 24
months » (sections 1 and 6, FR and EN) in the same commit.

#### The dashboard

Production only, for the controller alone: no Caddy block serves `GOATCOUNTER_VHOST`, no port is
published, and the `goatcounter-dash` router answers on that host only, on the environment's
Traefik — so the way in is a tunnel to `HTTP_PORT`, as for [Grafana](#grafana):

```bash
ssh -L 8090:127.0.0.1:8090 <host>        # prod's HTTP_PORT; staging (8089) runs no GoatCounter
# /etc/hosts on the workstation: 127.0.0.1 stats.pedalons.internal
# then http://stats.pedalons.internal:8090 (GoatCounter drops the port before looking up the site)
```

Its login cookie has no `Secure` flag over this `http://` tunnel; nothing else reaches it. Check
once, from another machine, that a request through Caddy with `Host: <GOATCOUNTER_VHOST>` does not
get the dashboard.

**Never use « Forgot password ».** GoatCounter has no mail relay here: it writes its e-mails to its
standard output, so the reset link would land in Loki. Change the password with:

```bash
scripts/goatcounter-init.sh password    # prompted; handed over through docker exec's environment
```

(`goatcounter db update user -password <value>` takes the value as given, on the command line,
where `ps` shows it.)

#### Logs

GoatCounter writes no access log (`/count` is excluded even with `-debug=req`). But **when it fails to
store a hit** — postgres down, a panic — its error log dumps the hit, **raw IP and user agent
included**, as a `hit = &{…}` line (`paths = …` for the pending ones). Alloy drops those lines
before Loki (`services/monitoring/alloy/config.alloy`), and the service's Docker log is rotated
short (2 × 1 MB) to bound the copy left on the host. After every GoatCounter upgrade, check that the
filter still bites: stop postgres for a few seconds while a hit arrives, then search Loki
(`{service="goatcounter"} |= "hit ="`) — nothing must come back.

#### Restore

`restore.sh` holds goatcounter at 0 with backend and frontend (`deploy.sh --hold-app`), then, after
`pg_restore`, runs `goatcounter-init.sh db`: role and empty database recreated, GoatCounter back on
them. **The site and its account went with the old database**: the script ends by saying so, and
`scripts/goatcounter-init.sh site` (from a terminal) recreates them — with GoatCounter stopped until
its settings are in place, so the live hits of the meantime are lost, never counted with a new
site's defaults. Until then `/count` refuses every hit — the site is unaffected.

### Stadia Maps: routing and geocoding

Route computation (`/api/router`, behind the web planner) is done by **Stadia Maps**
(`POST https://api-eu.stadiamaps.com/route/v1`, a Valhalla-compatible API on Stadia Maps' EU-only
host: the requests stay on servers in the European Union), not by a service of ours:
the self-hosted `valhalla` of the shared stack and its 17 GB of OSM tiles left on 2026-10-17
(ledger `OPS-48`). The backend sends the planner's waypoints, the profile and its costing options,
nothing else — no account, no client IP — and the privacy policy says so (§4 and §5, ledger
`LEGAL-23`).

The same key and the same host serve **geocoding** since 2026-10-17 (ledger `OPS-49`), in two
ways that must not be confused:

- **The forms' place search** (team location, meeting places, ads) still goes through the backend,
  authenticated by the same `Authorization: Stadia-Auth …` header, in two steps (ledger `API-129`):
  `GET /api/geocode/search?q=` (signed in, 3 characters minimum, 5 results, 24 h Caffeine cache
  `geocode-search`) calls `GET https://api-eu.stadiamaps.com/geocoding/v2/autocomplete` with the
  typed text and the display language — suggestions, usually without a position; once the user
  picks one, `GET /api/geocode/place?id=` (24 h cache `geocode-place`) calls
  `/geocoding/v2/place_details?ids=` for that one. Credits (stadiamaps.com/pricing, 2026-10-17): v2
  autocomplete 1 per request, Place Lookup 20 per id — about 24 credits for a typed search and a
  pick, against about 80 with the v1 autocomplete (20 per request) used until then. A failed place
  lookup is a 503 the form shows (search and pick again, or leave the position empty). Nominatim is
  gone with it: no `NOMINATIM_URL`, no `GEOCODE_USER_AGENT`, no usage-policy `User-Agent` to
  maintain (the Open-Meteo client now has a `User-Agent` of its own, `pedalons.weather.user-agent`, which a fork
  overrides with `PEDALONS_USER_AGENT`; see `.env.example`).
- **The search bar of the free-roaming maps** (web planner, routes map, GPX tool; ledger `WEB-99`)
  calls `api-eu.stadiamaps.com` **from the browser**, with no key at all: Stadia Maps authenticates
  it by the page's origin (`Origin`/`Referer`), against the domains declared in their dashboard.
  **`pedalons.fr` and all its subdomains are declared**; `localhost` passes without a key, under a
  strict quota. A deployment on another hostname needs that hostname added in the Stadia Maps
  dashboard (*domain-based authentication*), or its search bar answers nothing — the rest of the
  map is unaffected, and the forms' search, which goes through the backend, keeps working. The
  frontend's CSP (`frontend/server/csp.js`) always allows `https://api-eu.stadiamaps.com` in
  `connect-src`, so nothing is to be configured there.

| Key | Where | What it does |
|---|---|---|
| `STADIAMAPS_API_KEY` | the `.env` of **each environment** (`~/prod/.env`, `~/staging/.env`), never `~/shared/.env`: the shared stack has no routing any more | One key for routing and the forms' geocoding. Sent as `Authorization: Stadia-Auth …` on every request. **Required** in `%prod`: `docker-compose.yml` restates it with `:?`, so a deploy without it stops before any container starts (the backend itself would start and fail every route with a 500: the header is resolved per request). `scripts/dev-env.sh` exports it for `mvn quarkus:dev`; the e2e stack takes it from the shell or the workstation's `.env` (`scripts/e2e.sh`), the CI from a GitHub secret of the same name |
| `STADIAMAPS_URL` | optional | `https://api-eu.stadiamaps.com` by default (EU-only host; `https://api.stadiamaps.com` is the global one, same key), used by both the routing and the geocoding REST clients; another Valhalla-compatible host for a test — but then the geocoder points at it too |

The same key also serves the **surface along saved tracks** (ledger `WEB-100`, C1b):
`SurfaceRefreshWorker` (every 30 s, never during an HTTP request) sends a saved route's or GPX-tool
preview's stored track to `POST /trace_attributes/v1` once it has been left alone for 90 s (never
beyond 10 min), in `map_snap` mode, and stores the surface as ranges in `gpx_tracks.surfaces` /
`gpx_previews.surfaces`. **20 credits per 190 km slice** (a typical route is one request). The queue
is `surface_refresh`; a request that failed five times (2 min, 10 min, 1 h, 6 h) stays in the table
for diagnosis, untouched, and the API then says nothing for that track. `SURFACE_ENABLED=false` stops new requests **and** the worker's calls, the queue waits; it is
also off by itself when the key is empty. Set it to `false` in the `.env` of a workstation stack,
and the e2e stack has it off (`.env.e2e`): both would otherwise spend real credits, a biketeam
migration test included.

The **catch-up of old tracks** (`WEB-100`, C1c; the routes saved before the surface existed,
biketeam ones included): `SurfaceBackfill` (every 5 min) queues the routes without a surface nor
any request, most recent first, then the GPX-tool previews younger than 29 days, as requests marked
`surface_refresh.backfill`. The worker serves them only once no normal request is due. The cap is
global (carried by the requests' due times, spaced under a lock, so two backends of a rolling deploy
do not double it): `SURFACE_BACKFILL_PER_HOUR` provider calls an hour (default 300 = **6,000
credits/h**; a 188 km slice is one call, a 400 km route three), and never more than 10 minutes of it
waiting in the queue, so it pauses by itself while Stadia fails. The cap is on the due times: after
the worker was held up (a backlog of normal requests, `SURFACE_ENABLED` off a while, a restart) it
sends what fell due at once, so an hour can see up to the cap plus those 10 minutes (350 calls,
7,000 credits at the default), retries of failed requests aside. **Cost**: tracks x 20 credits; 10,000
routes take about 34 h and about 200,000 credits at the default cap (about 4 to 6 USD on the Starter
plan). A biketeam migration leaves its routes to the catch-up instead of queuing them at once.

- **Stop it**: `SURFACE_BACKFILL_ENABLED=false` (nothing more is queued; what is already queued, at
  most 10 minutes of cap, is still computed). `SURFACE_ENABLED=false` stops everything.
- **Before the first deploy, estimate it** (the routes the catch-up will take, its calls and
  credits; the previews are a few days' worth at most):
  ```sql
  select count(*) as routes,
         sum(greatest(1, ceil(coalesce(t.distance, 0) / 188000.0))) as calls,
         20 * sum(greatest(1, ceil(coalesce(t.distance, 0) / 188000.0))) as credits
    from team_entities t join teams tm on tm.id = t.team_id
   where t.id in (select g.route_id from gpx_tracks g where g.surfaces is null)
     and not t.deleted and not tm.deleted
     and not exists (select 1 from surface_refresh r where r.route_id = t.id)
     and exists (select 1 from assets a
                  where a.team_entity_id = t.id and a.type = 'ROUTE_ORIGINAL_GPX');
  ```
  `calls / SURFACE_BACKFILL_PER_HOUR` is the duration in hours.
- **Follow it**: `select count(*) filter (where backfill), count(*) filter (where backfill and attempts >= 5) from surface_refresh;`
  and what is left: `select count(distinct route_id) from gpx_tracks where surfaces is null;`. The log
  says `Surface catch-up done` once nothing is left.
- **A track the provider cannot match** gets an « unavailable » document and is never retried; one
  that failed five times keeps its request row (normal or catch-up) and is not taken again either.
  To retry the given-up ones (a revoked key made a batch fail):
  `delete from surface_refresh where attempts >= 5;` — they become candidates of the catch-up again,
  under its cap.
- A workstation stack keeps `SURFACE_ENABLED=false` (above), which disables the catch-up too.

One key for prod and staging works (Stadia Maps counts requests per key); a second key makes
staging's usage readable apart on their dashboard, and revocable alone. **The key never reaches a
log**: the request URL is not logged, and a failure is logged by its status only —
`Stadia Maps routing failed with status 429` means the plan's quota is spent (the planner answers
an error until the quota renews or the plan is raised), `401` a wrong or revoked key, `5xx` their
outage. The geocoder shares the quota and the key: on any failure it answers an empty list, not an
error, so a dead key shows up as forms that find no address — check the backend log for the
geocoding client's warning before suspecting the data. Published limits, which a planner can hit: 50 locations per request, and at most 500 km as
the crow flies between the farthest two for `bicycle` (250 km for `pedestrian`, 5 000 km for
`motorcycle`) — a longer route is refused by Stadia Maps, not split by us. Try a host's key
without printing it:

```bash
# A 401 on any path only says the key is missing or wrong; the path itself is /route/v1 (/route/v2 answers 404).
(set -a; . ./.env; set +a; curl -s https://api-eu.stadiamaps.com/route/v1 \
  -H "Authorization: Stadia-Auth $STADIAMAPS_API_KEY" -H 'Content-Type: application/json' \
  -d '{"locations":[{"lat":48.11,"lon":-1.68},{"lat":48.2,"lon":-1.6}],"costing":"bicycle"}' | head -c 300)
```

**Switching a host from Valhalla** (the repository switched on 2026-10-17; on a host, in this
order, because step 2's old backend still talks to `valhalla` until it is replaced):

1. add `STADIAMAPS_API_KEY` to `~/prod/.env` and `~/staging/.env`;
2. `scripts/deploy.sh` in each environment — the new backend needs no `valhalla`;
3. `scripts/deploy.sh --shared` from `~/shared` — the `valhalla` service leaves the stack;
   `tileserver` stays, and so do the `pedalons-shared` network and the backend's membership in it;
4. by hand, once `docker service ls` no longer lists `pedalons-shared_valhalla`: remove
   `~/shared/data/valhalla` (17 GB; its files are root's, so from a root context:
   `docker run --rm -v ~/shared/data:/d alpine rm -rf /d/valhalla`), drop `VALHALLA_TILE_URLS`
   from `~/shared/.env`, and delete the cold copy `OPS-9` had sent to the backup host
   (`pedalons-shared/` there).

### Store reviewers' demo data

`marketplace-tester@pedalons.fr`, the account given to the Apple, Google and Garmin reviewers, is a
member of two fictional clubs whose content is dated: its registrations pass, the commented ride the
App Review notes point to goes by. `mobile/screenshots/seed.py --target prod --refresh` brings them
back to date every day, without deleting anything (what it does, and why a full rebuild is the
exception: [mobile/screenshots/README.md](../mobile/screenshots/README.md#--refresh--les-données-ne-se-périment-pas)).
It only calls the public API, as the clubs' members, and needs nothing but `python3` (standard
library) on the host.

Its secrets stay outside the checkout, readable by `pedalons` only (`0600`), in
`~/.config/pedalons/store-demo.env`:

```bash
MARKETPLACE_TESTER_PASSWORD=...
SEED_ACCOUNTS=/home/pedalons/.config/pedalons/store-demo-accounts.json
STORE_DEMO_PING_URL=https://hc-ping.com/<uuid>     # optional; a daily check
```

`store-demo-accounts.json` is the `accounts.prod.local.json` a first refresh from a workstation
writes (it resets over SSH the passwords it doesn't know, which the host cannot do to itself):
copy it over once. Create the log directory (`mkdir -p ~/logs`): without it the redirection
fails and cron never starts the script, silently. Then, in `pedalons`'s crontab:

```
0 5 * * * cd /home/pedalons/prod && set -a && . /home/pedalons/.config/pedalons/store-demo.env && set +a && python3 mobile/screenshots/seed.py --target prod --refresh >> /home/pedalons/logs/store-demo.log 2>&1
```

The ping gets `/start`, then success, or `/fail` with the error. A run fails for good — and keeps
failing until someone acts — when the test account is no longer a member of a club (a reviewer left
it; a club admin can neither add nor invite it back, only a platform admin can) or was deleted. Add
it back by hand, or run the full rebuild from a workstation and copy the accounts file again if it
changed.

### Changing an environment's network topology

**On a host**, `docker stack deploy` never alters a network that already exists: change its driver,
its options or its labels and the deploy succeeds, reporting nothing, on the old network. For any
such change, remove the stack and wait for its network to be gone before deploying again:

```bash
docker stack rm "$ENV_NAME"    # never followed by `docker volume rm` — that is the data
while docker network inspect "${ENV_NAME}-net" >/dev/null 2>&1; do sleep 2; done
scripts/deploy.sh
```

**On a workstation**, renaming or re-declaring a network makes compose (v5.3.1) drop the old one and
create the new one *during* the run, then fail on `network X was found but has incorrect label
com.docker.compose.network` — it labels the network with the map key but validates against the
resolved name. The run aborts halfway and can leave a container attached to **no network**, which
then fails with a misleading DNS error rather than an obvious one. So for any such change, do not
rely on a single `up -d`:

```bash
docker compose down --remove-orphans   # never -v: it drops the postgres and minio volumes
docker compose up -d
```

After an aborted run, check what a container is actually attached to before believing its logs:

```bash
docker inspect <container> --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
docker compose up -d --force-recreate <service>
```

## Monitoring

A third stack beside the shared one, **`pedalons-monitoring`** (`docker-compose.monitoring.yml`),
deployed from the `~/shared` checkout. It watches every stack on the host; one thing it cannot
watch is the host itself going down, which is why two pieces live **elsewhere**: Healthchecks,
which expects the stack's `Watchdog` alert every 5 minutes, and Gatus on the backup host, which
probes the sites from outside.

| Service | What it does | Memory limit |
|---|---|---|
| prometheus | metrics, 15 days (4 GB at most); evaluates `services/monitoring/prometheus/rules/` | 512M |
| alertmanager | sends the alerts by e-mail, and the `Watchdog` to Healthchecks | 128M |
| node-exporter | the host: disks, memory, load, OOM kills | 64M |
| cadvisor | each container's CPU and memory, against its limit | 256M |
| loki | logs, **14 days** — as the Caddy access log it receives, see below | 512M |
| alloy | ships every stack's container logs and the Caddy access logs to Loki | 256M |
| grafana | dashboards; the only published port (3300) | 1G |

About 2.7 GB of ceilings, 1 GB or so resident. What Prometheus scrapes:

- **the host's Caddy** — requests, 5xx and latency per hostname, i.e. what visitors get, from every
  environment at once. It listens on the host, on `:2020`, and Prometheus reaches it through the
  gateway of `docker_gwbridge`, which `deploy.sh` looks up (`CADDY_METRICS_TARGET` to override);
- **each environment's backend**, `/q/metrics` (Micrometer: JVM, HTTP, the Agroal pool). Found
  through the Swarm API, one target per task — both during a rolling update — on
  `pedalons-shared`, and labelled `env` with the stack's name: a new environment needs no change.
  `/q` is not routed by traefik (only `/api` is), so the endpoint is not public;
- node-exporter, cadvisor, and the monitoring services themselves.

The backend logs **JSON** in `%prod` (`quarkus-logging-json`), so a stack trace is one Loki entry
rather than one per line, and its `level` a label. That holds on a workstation's full stack too,
which runs `%prod`: `docker logs` shows JSON there as well.

### Setting it up

In this order — **the firewall first**: Swarm publishes Grafana on every interface, like traefik.

```bash
# 1. firewall: the updated unit also drops Grafana (MONITORING_PORTS, 3300) and Caddy's metrics
#    (HOST_PORTS, 2020) on the public interface
install -m 755 scripts/pedalons-firewall.sh /usr/local/sbin/pedalons-firewall.sh
systemctl restart pedalons-firewall.service
iptables -S DOCKER-USER | grep 3300 && iptables -S INPUT | grep 2020     # ip6tables alike
```

2. **Caddy's metrics**, in the host's Caddyfile — the `metrics` global option (Caddy 2.8+), and a
   site of its own that serves them. No `log` in that site: Prometheus polls it every 30 s.

   ```caddyfile
   {
   	metrics {
   		per_host
   	}
   }

   :2020 {
   	metrics
   }
   ```

   `systemctl reload caddy`, then `curl -s localhost:2020/metrics | grep caddy_http_requests_total`
   lists one `host` per site. Never expose Caddy's **admin** endpoint (`:2019`) instead: it can
   rewrite the configuration.

3. **Healthchecks**: a new check, period 5 minutes, grace 10 minutes. Its ping URL is
   `ALERT_WATCHDOG_PING_URL`.

4. **The `.env` of `~/shared`**: the keys of `services/monitoring/env.example` (Grafana's admin
   password, the SMTP relay of the alerts, the Healthchecks URL). Then:

```bash
cd ~/shared && git pull && scripts/deploy.sh --monitoring
docker stack ps pedalons-monitoring
```

`deploy.sh --monitoring` renders Alertmanager's configuration into `data/monitoring/` (it reads no
environment; the SMTP password and the ping URL go beside it as files), writes Caddy's target,
deploys, and sends `SIGHUP` to the Prometheus, Alertmanager and Alloy that were already running so
that they reload their files. Loki and Grafana read theirs at start only: after changing
`loki.yml` or a provisioning file, `docker service update --force pedalons-monitoring_<service>`.
Dashboards under `services/monitoring/grafana/dashboards/` are picked up within a minute.

5. **Check from another machine**, as for traefik: `curl -m 5 http://<host>:3300` and
   `curl -m 5 http://<host>:2020/metrics` must both time out.

### Grafana

Through an SSH tunnel, never a public hostname:

```bash
ssh -L 3300:127.0.0.1:3300 <host>      # then http://localhost:3300, user admin
```

`GRAFANA_ADMIN_PASSWORD` is only read on Grafana's first start; change the password in Grafana
after. The **Pédalons — vue d'ensemble** dashboard comes from the repository (read-only in the UI:
edit the JSON), and so does **Quarkus Micrometer Prometheus registry** — the dashboard of Quarkus's
LGTM Dev Service, copied unchanged from `quarkusio/quarkus`
(`extensions/observability-devservices/testcontainers/src/main/resources/grafana-dashboard-quarkus-micrometer-prometheus.json`,
commit `94a2ecba6efe`, Apache 2.0): to update it, copy the file again rather than editing it. Its
`instance` variable is a task's IP, which changes with every deploy. Community dashboards import by ID from the UI (*Dashboards → New → Import*) and live
in Grafana's database: *Node Exporter Full* (1860), *JVM (Micrometer)* (4701). Logs are in
*Explore → Loki*: `{stack="pedalons-prod", service="backend"} | json`, or `{job="caddy"} | json |
status >= 500`.

### Alerts

All of them by e-mail, through `ALERT_SMTP_*` — preferably not the relay the application sends
through, whose outage would then silence its own alert. Severity only says how soon to look.

| Alert | Fires when | First look |
|---|---|---|
| `HighErrorRate` (critical) | over 5 % of a site's requests end in 5xx for 5 min | `docker stack ps`, backend logs in Loki |
| `SlowResponses` | a site's p95 above 3 s for 15 min (not `auth.pedalons.fr`: strava-auth-proxy's latency is Strava's) | the dashboard's CPU and connection pool panels |
| `OomKill` (critical) | the kernel killed a process in the last 10 min | `docker stack ps` (`exit (137)`), then [Memory](#memory) |
| `ContainerNearMemoryLimit` | a container's working set above 90 % of its limit for 30 min | raise that limit, or `VARNISH_SIZE` down |
| `DiskAlmostFull` (critical) | a filesystem under 15 % free | `docker system df`, `data/cache`, old images |
| `DiskFillingUp` | a filesystem full within 24 h at the last 6 h's rate | same |
| `HostLowMemory` | under 10 % of the host's memory available for 15 min | `docker stats` |
| `BackendHeapFull` | over 90 % of the heap still live after GC for 15 min | raise `BACKEND_MEMORY` |
| `BackendConnectionPoolExhausted` | requests waiting for a database connection for 5 min | slow queries, a stuck transaction |
| `BackendErrors` (Loki) | more than 10 `ERROR` lines in 10 min, for 5 min | the lines themselves, in Loki |
| `TargetDown` | a scrape target unreachable for 5 min | `docker stack ps` of its stack |
| `BackendMissing` (critical) | an environment scraped in the last day has no backend task for 5 min (`TargetDown` cannot see a target that is gone); resolves a day later — silence it after a deliberate teardown | `docker service ps <env>_backend` |
| `Watchdog` | always — its **absence** is the alert, at Healthchecks | the host, then this stack |

The rules are tested: `promtool test rules` (command at the top of
`services/monitoring/prometheus/tests/pedalons.test.yml`) — mostly for the label matching of the
ratios, where a mismatch makes an alert silently never fire. Backups are not among them: their own
Healthchecks check already covers them (see [Configuration](#configuration)).

### Gatus, on the backup host

The one monitor outside the application host: it probes `https://www.pedalons.fr/api/version`, the
home page, the bare-domain redirect and staging, and mails when one fails three times in a row or
when a certificate expires within 14 days. Its configuration lives in the repository
(`services/monitoring/gatus/`), in the same read-only checkout as `backup-prune.sh` — Gatus reloads it
when the nightly `git reset --hard` changes it:

```bash
cd /opt/pedalons-scripts && git sparse-checkout add services/monitoring/gatus
cd services/monitoring/gatus
cp env.example .env && $EDITOR .env      # GATUS_BIND=<backup-tunnel-ip>, or 127.0.0.1 + SSH tunnel
docker compose up -d && docker compose logs -f   # four "success=true" lines within a minute
```

Nothing watches Gatus itself: a glance at its page now and then (through the tunnel) is the check.

### Privacy

The Caddy access log is read **as Caddy wrote it**, already filtered (see
[Access logs](#access-logs)), and Loki keeps it, like everything else, **14 days** — the promise of
the privacy policy for that log. Don't raise `retention_period` in `loki.yml`, and never point Alloy
at an unfiltered source. The containers' own logs go through the same retention: 14 days, whatever
they may carry — except GoatCounter's lines that dump a hit, visitor IP included, which Alloy drops
(see [Web analytics](#web-analytics-goatcounter), « Logs »).

## Backup and restore

`scripts/backup.sh` pushes each run of a deployed environment into `incoming/` on the backup host;
`scripts/backup-promote.sh`, **on the backup host**, turns each complete push into a dated snapshot
that production can no longer touch; `scripts/restore.sh` brings an environment back from one, on
the same machine or a new one; `scripts/backup-prune.sh` expires old snapshots, on the backup host
too.

Production is backed up nightly to the backup host over a WireGuard tunnel (`<prod-tunnel-ip>` → `<backup-tunnel-ip>`).

### rsync is the only channel

The receiving account's key is restricted to `command="rrsync <root>",restrict,from="<prod-tunnel-ip>"`:
it accepts an `rsync --server` invocation and refuses everything else, confined to one directory.
A compromise of the production host therefore stops at its own backup tree — it cannot read the
other backups on the host — and, within it, at `incoming/` (ledger `SEC-32`): `<root>` and every dated
snapshot belong to `root:<backup-user>`, directories `0750` and files `0440`. The key reads them —
which is how a restore goes through it — but cannot write, delete, rename or re-permission one;
`rrsync` itself honours `rsync --delete`, and only `incoming/`, the account's own, is open to it.
Nor can it read them back in clear: the dump and the secrets are encrypted to a key it does not hold
([Encryption](#encryption)). Four consequences run through the scripts, and none of them are
incidental:

- **the dumps are staged locally** (`/var/backups/pedalons/<env>`) before being pushed — there is no
  remote `cat >`; they are encrypted as they are written, so nothing lands there in clear; the staging
  directory is removed once the run succeeds; a failed run leaves it (mode 700) until the next run
  wipes it on start;
- **production only ever writes `incoming/`**, a mirror it updates in place: `COMPLETE` is removed
  first and written last, holding the snapshot's name;
- **snapshots are made on the backup host** by `backup-promote.sh` (root's crontab, every 15
  minutes): once `incoming/COMPLETE` names the snapshot its `MANIFEST` describes, it copies
  `incoming/` hard-linked against the previous snapshot, owned by root and read-only, checks
  `SHA256SUMS`, and renames it into place. **At most one promotion per 20 hours**
  (`MIN_INTERVAL_HOURS`): the name comes from production and retention keeps a count, so without a
  floor a compromised host could push thirty snapshots in a night and have the prune expire every
  real one. A name must also be later than the last snapshot and not in the future. A manual extra
  run waits for the next window — `MIN_INTERVAL_HOURS=0 backup-promote.sh <backup-root>` promotes it
  at once;
- **retention lives on the backup host** (`backup-prune.sh`, root's crontab there), not in the
  backup script.

### What a snapshot holds

`<root>/<UTC timestamp>/`:

| File | Contents | Why it matters |
|------|----------|----------------|
| `postgres.dump.age` | `pg_dump -Fc` of `$POSTGRES_DB`, encrypted with age | Accounts, teams, rides, routes, posts |
| `minio/` | The object store, verbatim (not encrypted: see [Encryption](#encryption)) | Photos, GPX files, avatars, previews |
| `secrets.tar.gz.age` | `.env`, `data/keys` (JWT keys, FCM service account), `data/storage`, encrypted with age | The JWT keys sign every session and passkey; the service account sends every push; `ENCRYPTION_KEY` decrypts the stored Karoo/Garmin/Wahoo tokens and the per-domain GPS client secrets |
| `MANIFEST` | Timestamp, env, git commit, image tags, file names | Says which commit to rebuild before restoring |
| `SHA256SUMS` | Checksums of the two encrypted archives | Verified by `restore.sh` before it decrypts or destroys anything |
| `COMPLETE` | The snapshot's name, written last into `incoming/` | Promotion waits for it; a dated directory is renamed into place whole, so every snapshot has one |

Postgres is dumped **before** MinIO on purpose: `AssetService` uploads to S3 and only then persists
the row, so a file landing mid-backup leaves an orphan object rather than a row pointing at a
missing one. `pg_dump -Fc` is transactional, and MinIO renames objects into place, so neither needs
the stack stopped.

Only changed MinIO objects cross the wire into `incoming/`, and `backup-promote.sh` hard-links the
unchanged ones to the previous snapshot (`rsync --link-dest`): each dated directory reads as a full
copy but only costs its delta, plus `incoming/` itself — one more copy of the store. Measured on
production: a first snapshot takes ~60 s and 1.7 GB; the next takes ~18 s and near-zero disk.

`.minio.sys/tmp/` is excluded: MinIO stages every write there, so rsync catches files mid-flight and
fails the run with exit 23. The rest of `.minio.sys` is *not* excluded — without `format.json` MinIO
does not recognise its own data. A run that still trips 23/24 (an upload landing during the backup)
gets one more rsync pass before it is called failed.

**Not** in a snapshot, and to be rebuilt by hand: the Docker images (`./build.sh` at the MANIFEST's
commit), `data/cache` (regenerable, just slow), and the shared tileserver's data
(`data/tileserver`: a style and a config, tracked by git).
Nor, by choice, the **`goatcounter` database**: the web analytics are disposable statistics, and a
restore starts them again from empty (see [Web analytics](#web-analytics-goatcounter)). Backing
them up one day would mean rewriting the privacy policy's sentence on backups in the same commit.

### Encryption

The backup host sits at the controller's home, so every snapshot is encrypted at rest, in two
layers:

- **the dump and the secrets are encrypted on production**, with [age](https://age-encryption.org)
  to a public key (`BACKUP_AGE_RECIPIENT`). `pg_dump` and `tar` are piped straight into `age`: neither
  touches the staging disk in clear. The private key is kept **offline**, at
  `<offline-key-location>`: production can write a backup but cannot read one back, and neither can
  the backup host;
- **the whole backup root sits on a LUKS volume** on the backup host
  ([below](#luks-volume-on-the-backup-host)). That is what protects `minio/`: encrypting it on
  production would turn the object store into one opaque archive a night and lose the
  `--link-dest` incrementals.

`backup.sh` refuses to run without `age` or without a valid `BACKUP_AGE_RECIPIENT`: a run that cannot
encrypt fails (and Healthchecks says so) rather than pushing clear text. `restore.sh` restores only
this format — snapshots from before it (clear, or `secrets.tar.gz.gpg`) are not supported.

The key pair is generated **once, on a machine that is not production** (ideally offline):

```bash
age-keygen -o pedalons-backup.key      # prints "Public key: age1..."
```

- the private key (the whole `pedalons-backup.key`, `AGE-SECRET-KEY-1...`) goes to
  `<offline-key-location>`, then the file is deleted; lose it and no snapshot's database or secrets
  can be read again;
- the public key goes into `/root/pedalons-backup.env` on production as `BACKUP_AGE_RECIPIENT`
  (see [Configuration](#configuration)).

On production, `apt install age` (the Debian/Ubuntu package ships `age` and `age-keygen`). Check the
recipient before the first night — this must print nothing and exit 0:

```bash
age -r "$(sed -n 's/^BACKUP_AGE_RECIPIENT=//p' /root/pedalons-backup.env)" </dev/null >/dev/null
```

A new key pair takes effect from the next run; older snapshots stay readable only with the old
private key, so keep it until they have all been pruned (30 nights).

### Configuration

`BACKUP_*` lives in **`/root/pedalons-backup.env`**, not in `.env`: compose hands the whole `.env`
to the backend container (`env_file`), so the destination, the key path and the Healthchecks URL
would end up inside the application — and inside the backup of it. Override the location with
`BACKUP_ENV_FILE`.

```bash
BACKUP_REMOTE=<backup-user>@<backup-tunnel-ip>
BACKUP_REMOTE_PATH=/                     # relative to the rrsync root
BACKUP_SSH_KEY=/root/.ssh/id_pedalons_backup
BACKUP_PING_URL=https://hc-ping.com/<uuid>
BACKUP_AGE_RECIPIENT=age1...             # public key, required (see Encryption)
```

Retention is not set here: it is the second argument of `backup-prune.sh` on the backup host (30 in
the crontab below).

Reading the minio volume needs root, so the backup runs from root's crontab:

```
15 3 * * * cd /home/pedalons/prod && ./scripts/backup.sh >> /var/log/backup/pedalons-backup.log 2>&1
```

and on the backup host, after it — the checkout is refreshed in the same line, so the repository
stays the single source of truth instead of a copy that quietly drifts:

```
30 4 * * * cd /opt/pedalons-scripts && { git fetch -q --depth 1 origin develop && git reset -q --hard FETCH_HEAD ; } ; ./scripts/backup-prune.sh <backup-root> 30 >> /var/log/backup/pedalons-backup-prune.log 2>&1
```

`;` rather than `&&` between the two: a failed fetch must not skip the night's pruning, it just runs
the last version that landed. Promotion runs from the same checkout, every quarter of an hour:

```
*/15 * * * * /opt/pedalons-scripts/scripts/backup-promote.sh <backup-root> >> /var/log/backup/pedalons-backup-promote.log 2>&1
```

It reports to its own Healthchecks check, set in `/etc/default/pedalons-backup-promote` (root,
`0600`): `BACKUP_PROMOTE_PING_URL=https://hc-ping.com/<uuid>`, a daily check — a ping per promotion,
`/fail` when a push is refused. Nothing to promote pings nothing, so a night without a snapshot shows
up as a late check.

The checkout is read-only, shallow and sparse (5 MB, `scripts/` only):

```bash
git clone --depth 1 --single-branch --branch develop --no-checkout \
  https://github.com/glandais/pedalons.git /opt/pedalons-scripts
cd /opt/pedalons-scripts && git sparse-checkout set --no-cone scripts && git checkout develop
```

The obvious shortcut — having `backup.sh` push the prune script along with the snapshot, the way
another backup job on that host copies itself into its own backup — is a trap **here**: root's crontab on the
backup host would then execute a file the production host can overwrite, so a compromised production
host would get root execution on the backup host at 04:30. That is exactly what the `rrsync`
confinement exists to prevent. Pulling from the repository keeps the trust in git, where the
deployment already places it.

Both write into `/var/log/backup/`, which `scripts/pedalons-backup.logrotate` rotates daily and keeps
for 30 days — the same directory, glob and settings the backup host already uses for its other
backup logs, so one rule covers every machine:

```bash
mkdir -p /var/log/backup
install -m 644 scripts/pedalons-backup.logrotate /etc/logrotate.d/backup
logrotate -d /etc/logrotate.d/backup     # dry run
```

The scripts run with `BatchMode=yes` and never prompt, so an untrusted host key fails the run with a
bare `Host key verification failed`. Trust it once, as the user cron runs as.

`BACKUP_PING_URL` gets `/start` before the run and `/fail` (with the run log as the body) on error:
a backup nobody watches stops existing the day it starts failing.

### Setting up a new receiving account

On the backup host, as root — modelled on the host's other backup accounts (placeholders in `<…>`):

```bash
adduser --system --group --home /home/<backup-user> --shell /bin/bash <backup-user>
mkdir -p /home/<backup-user>/.ssh <backup-root>
echo 'from="<prod-tunnel-ip>",restrict,command="rrsync <backup-root>" ssh-ed25519 AAAA... backup-pedalons-prod' \
  > /home/<backup-user>/.ssh/authorized_keys
chown -R <backup-user>:<backup-user> /home/<backup-user>
chmod 700 /home/<backup-user>/.ssh && chmod 600 /home/<backup-user>/.ssh/authorized_keys
# The root and the snapshots are root's; the account writes incoming/ only (SEC-32).
chown root:<backup-user> <backup-root> && chmod 750 <backup-root>
mkdir -p <backup-root>/incoming && chown <backup-user>:<backup-user> <backup-root>/incoming && chmod 700 <backup-root>/incoming
```

Check the restriction actually bites — this must fail:

```bash
ssh -i /root/.ssh/id_pedalons_backup <backup-user>@<backup-tunnel-ip> 'ls /'
# /usr/bin/rrsync error: SSH_ORIGINAL_COMMAND does not run rsync
```

### LUKS volume on the backup host

`<backup-root>` is the mount point of a LUKS container: a file on the backup host's disk, never
unlocked at boot. As root on the backup host, once — `<backup-root>` must be empty and unmounted:

```bash
touch <backup-root>.luks && chattr +C <backup-root>.luks    # btrfs: no copy-on-write, before any data
fallocate -l 40G <backup-root>.luks
cryptsetup luksFormat --type luks2 <backup-root>.luks        # passphrase -> <offline-key-location>
cryptsetup open --allow-discards <backup-root>.luks pedalons-backup
mkfs.ext4 /dev/mapper/pedalons-backup
chattr +i <backup-root>                                      # the bare mount point: unwritable
mount /dev/mapper/pedalons-backup <backup-root>
chown root:<backup-user> <backup-root> && chmod 750 <backup-root>
mkdir <backup-root>/incoming && chown <backup-user>:<backup-user> <backup-root>/incoming && chmod 700 <backup-root>/incoming
cryptsetup luksHeaderBackup <backup-root>.luks --header-backup-file /root/pedalons-backup.luks-header
```

- **`chattr +i` on the bare mount point** is what keeps a locked volume from filling up in clear:
  while nothing is mounted there, the night's `rsync` fails instead of writing to the host disk;
- **`--allow-discards`** lets TRIM from ext4 reach the SSD, so deleted snapshots do not linger on
  it;
- **the header backup** goes to `<offline-key-location>` and is then deleted from the host: a damaged
  LUKS header makes the whole volume unreadable, passphrase or not.

There is deliberately **no `crypttab` or `fstab` entry**: the passphrase is never stored on the
host. After every reboot, unlock it by hand over SSH:

```bash
cryptsetup open --allow-discards <backup-root>.luks pedalons-backup && mount /dev/mapper/pedalons-backup <backup-root>
```

Until then each night's backup fails, and Healthchecks says so; `backup-prune.sh` finds an empty
directory and removes nothing, and `backup-promote.sh` finds no `incoming/`.

### Restoring

Everything but `--list` needs the private key. Bring it from `<offline-key-location>` into a file on
a RAM-backed filesystem, for the duration of the restore only, and point `BACKUP_AGE_IDENTITY` at
it:

```bash
install -m 600 /dev/null /dev/shm/pedalons-backup.key
$EDITOR /dev/shm/pedalons-backup.key         # paste the AGE-SECRET-KEY-1... line
export BACKUP_AGE_IDENTITY=/dev/shm/pedalons-backup.key

scripts/restore.sh --list                    # the promoted snapshots (not incoming/)
scripts/restore.sh                           # restore the newest complete one (asks to confirm)
scripts/restore.sh --snapshot 2026-07-24T031500Z

rm /dev/shm/pedalons-backup.key              # as soon as the restore is done
```

The restore pulls the snapshot to a local directory, verifies its checksums, then decrypts the
secrets and the whole dump once to prove the key matches — all **before** touching anything. Only
then does it take the stack down, drop the current postgres and minio volumes, and repopulate them;
the dump is decrypted in flight into `pg_restore` and never written in clear. It refuses a snapshot
with no `COMPLETE` marker, and refuses one from another `ENV_NAME` unless `--force`.

It follows the stack wherever it runs. On a host (a swarm) it removes the stack and redeploys it
through `scripts/deploy.sh --hold-app` — Swarm cannot start part of a stack, so backend and frontend
come back at zero replicas, or the backend would bootstrap a fresh Domain on the empty database
before the dump lands; goatcounter too, until `goatcounter-init.sh db` recreates its empty database
after `pg_restore`. On a workstation it is `docker compose down -v`, then `up`. **In production,
finish with `scripts/goatcounter-init.sh site`**, from a terminal: the analytics site and its
account are not in the backup.

It needs only `rsync`, `age` and `docker`, no root. The objects go back as `root:root` — the user
MinIO runs as — through `docker cp` on a workstation, and on a host, where a service scaled to zero
leaves no container to copy into, through a throwaway container mounting the volume. Writing into
`/var/lib/docker/volumes` directly would stamp them with the restoring account's uid.

On a **new host**, the order matters — you need `.env` before anything else can read its own config:

```bash
git clone <repo> ~/prod && cd ~/prod

# 0. age, and the private key on a RAM-backed file (see above)
apt install age
export BACKUP_AGE_IDENTITY=/dev/shm/pedalons-backup.key

# 1. secrets first: no .env yet, so pass the coordinates in the environment
BACKUP_REMOTE=<backup-user>@<backup-tunnel-ip> BACKUP_REMOTE_PATH=/ \
BACKUP_SSH_KEY=/root/.ssh/id_pedalons_backup \
  scripts/restore.sh --secrets-only

# 2. the firewall unit (see "Only Caddy may reach traefik"), the swarm, the shared stack, then
#    the images
docker swarm init
cd ~/shared && scripts/deploy.sh --shared
cd ~/prod && ./build.sh            # at the commit recorded in MANIFEST

# 3. the data, then drop the key
scripts/restore.sh
rm /dev/shm/pedalons-backup.key
```

`/root/pedalons-backup.env` is not in the snapshot: recreate it (with `BACKUP_AGE_RECIPIENT`) before
the next night's backup.

The script ends by printing row counts, the object count and the status of `GET /api/config`. The
last check is manual and the one that matters: open the site and confirm an existing photo renders —
that path goes MinIO → imgproxy → varnish, so it proves the objects came back, not just the rows.

**Objects older than the database keep their metadata.** Storage re-encodes every image on write,
and `AssetMetadataBackfill` re-encodes those stored before it did, one `assets.metadata_pending` row
at a time (ledger `API-43`). `restore.sh` takes the dump and the objects from the same snapshot, so
the flags match the files. If the MinIO volume ever comes from an older copy than the database — a
snapshot taken before the backfill had finished, laid under a database where it has — the photos
come back with their EXIF and GPS position, and nothing flags them again. Flag them by hand, and
the backfill (every 5 minutes) rewrites them:

```sql
UPDATE assets SET metadata_pending = true
WHERE content_type LIKE 'image/%' OR type IN ('LOGO', 'IMAGE', 'ATTACHMENT');
```

Not after an ordinary restore: each pass is a lossy re-encode, so an image already clean only loses
quality. GPX files need nothing — `GpxSanitizationBackfill`'s marker lives in the bucket, so a
restored bucket comes back without it and the next nightly pass checks them all again.

Flyway replays any migration newer than the dump on the next boot, so restoring an old snapshot
under a recent image works; the reverse does not, which is why the MANIFEST records the commit. An
image older than the snapshot fails at boot, in a crash loop, with:

```
FlywayValidateException: Detected applied migration not resolved locally: 26.
```

The restore itself succeeded in that case — the data is in place and the script correctly refuses to
report success, since `/api/config` never answers 200. Rebuild at the MANIFEST's commit
(`./build.sh`) and `scripts/deploy.sh`; nothing needs to be restored again.

#### Restore drill from another machine

The restricted key only allows the production host in (`from=`), so a drill elsewhere reads the same
store through an ordinary SSH account on the backup host — `BACKUP_REMOTE_PATH` is then the real
path instead of `/`. `--force` is what lets a `pedalons-prod` snapshot land in a differently-named
local environment:

```bash
cat > /tmp/drill.env <<'EOF'
BACKUP_REMOTE=root@<backup-host-lan-ip>
BACKUP_REMOTE_PATH=<backup-root>
EOF
BACKUP_ENV_FILE=/tmp/drill.env BACKUP_AGE_IDENTITY=/dev/shm/pedalons-backup.key scripts/restore.sh --force
```

The backup host's LUKS volume must be open, and the private key is needed here too — delete it
from `/dev/shm` afterwards.
