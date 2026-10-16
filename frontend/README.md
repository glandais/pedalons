# Pédalons Frontend

Web client of the Pédalons cycling team management platform, server-side rendered (see [docs/SSR.md](docs/SSR.md)). Built with TypeScript 7, React 19, Vite 8 and Mantine UI 9.

## Prerequisites

- Node.js — the version CI uses is pinned in [`.nvmrc`](.nvmrc); Vite 8 itself needs ^20.19 or >=22.12
- pnpm — pinned by `packageManager` in `package.json`; `corepack enable` honours it
- An API to talk to: the staging API (the default, no setup) or a local backend on `localhost:8080`,
  started as in the root [Quick Start](../README.md#quick-start)

## Getting Started

```bash
pnpm install
pnpm dev
```

The dev server starts at https://localhost:5173 (plain HTTP without the certificates below) and
proxies `/api` to the API target.

### API Target

`pnpm dev` and `pnpm preview` proxy `/api` to `VITE_API_TARGET`, read from `frontend/.env`
(git-ignored; `.env.example` is the template):

- **unset** → the staging API, `https://staging.pedalons.fr`. No backend needed locally.
- **local backend** → `VITE_API_TARGET=http://localhost:8080` in `.env`.

The proxy sets `X-Forwarded-Host` / `X-Forwarded-Proto` from the target URL, so the backend resolves
the target's tenant. `pnpm dev:ssr` does not read it: its server takes `API_BASE_URL` from the
environment (default `http://localhost:8080`), e.g. `API_BASE_URL=https://staging.pedalons.fr pnpm dev:ssr`.

Runtime app config comes from the `/api/config` endpoint, not from `.env` files.

### HTTPS Setup (required for WebAuthn/passkeys)

Vite serves HTTPS only when it finds `localhost+2.pem` and `localhost+2-key.pem` in this folder
(git-ignored), and plain HTTP otherwise. Generate them with [mkcert](https://github.com/FiloSottile/mkcert) —
three hosts, since that is what names the files `localhost+2`:

```bash
mkcert -install                            # one time: install local CA
mkcert localhost 127.0.0.1 <your LAN IP>   # generates localhost+2.pem and localhost+2-key.pem
```

## Scripts

| Script | Description |
|--------|-------------|
| `pnpm dev` | Dev server with HMR (client-side rendering only) |
| `pnpm dev:ssr` | SSR dev server (`node server.js`, localhost:3000) — see [docs/SSR.md](docs/SSR.md) |
| `pnpm build` | Production build, client (`dist/client`) + SSR bundle (`dist/server`), no type checking |
| `pnpm typecheck` | TypeScript check (`tsc -b`) |
| `pnpm preview` | Preview the production build locally |
| `pnpm serve:ssr` | Build, then run the SSR server in production mode |
| `pnpm generate-api` | Regenerate the API client from `../contracts/openapi.json` |
| `pnpm generate-routes` | Regenerate path builders + deeplinks from `../contracts/routes.yaml` ([docs/APP_LINKS.md](../docs/APP_LINKS.md)) |
| `pnpm generate-brand-colors` | Regenerate the business colour code (web + mobile) from `../contracts/brand-colors.yaml` |
| `pnpm generate-icons` | Regenerate PWA icons from `public/icon.svg` |
| `pnpm lint` | oxlint (`lint:fix` to apply fixes) |
| `pnpm format` | Sort the translation catalogues (i18next-cli extract), then Prettier (`format:check` to only check) |
| `pnpm test` | Vitest (watch mode; `test:coverage` for a single run with coverage) |
| `pnpm e2e` | Playwright against the e2e stack — see [e2e/README.md](e2e/README.md) |
| `pnpm i18n:check` | Translation catalogues sorted and complete, `t()` params, English vs French — see [CLAUDE.md](CLAUDE.md) « i18n » |
| `pnpm check` | Install, regenerate, format, typecheck, lint, i18n:check and build |

`predev` and `prebuild` copy `../privacy/*.md` into `src/assets/legal/` (`pnpm copy-legal`). The
remaining scripts are in `package.json`.

## API Client Generation

The API layer is generated with [Orval](https://orval.dev/) from the contract the backend build
writes to `../contracts/`:

```bash
cd ../backend && mvn package -DskipTests   # writes contracts/openapi.{json,yaml}
cd ../frontend && pnpm generate-api
```

It produces React Query hooks, TypeScript DTOs and Zod schemas in `src/api/`, which it wipes first.
**Do not edit generated files.**

## Stack

| Concern | Library |
|---------|---------|
| UI Components | [Mantine](https://mantine.dev/) 9 |
| Routing | React Router 7 |
| Server State | TanStack React Query 5 |
| Client State | Zustand 5 |
| Forms | Mantine Form + Zod 4 validation |
| Rich Text | Tiptap 3 |
| Maps | MapLibre GL + react-map-gl |
| Charts | Chart.js + react-chartjs-2 |
| Calendar | @mantine/schedule 9 |
| i18n | i18next (French default) |
| Icons | @tabler/icons-react |

## Architecture and conventions

The source layout, the routing, the stores and the rules the code follows (paths, confirmations,
icons, i18n, forms, dates) are in [CLAUDE.md](CLAUDE.md), which is kept up to date with the code.
Topic notes: [docs/SSR.md](docs/SSR.md), [docs/SSR-data-loading.md](docs/SSR-data-loading.md),
[docs/URL_FILTERS.md](docs/URL_FILTERS.md), [docs/LINK_PREVIEW.md](docs/LINK_PREVIEW.md), and
[docs/APP_LINKS.md](../docs/APP_LINKS.md) for adding a route.
