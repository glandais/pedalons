# Pédalons Frontend

Web client of the Pédalons cycling team management platform, server-side rendered (see [docs/SSR.md](docs/SSR.md)). Built with TypeScript, React 19, Vite, and Mantine UI.

## Prerequisites

- Node.js 22+ (Vite 8 requires ^20.19 or >=22.12)
- pnpm 11 — pinned by `packageManager` in `package.json`; `corepack enable` honours it
- An API to talk to — either the staging API (default, no setup) or a local backend on `localhost:8080` (see root [README](../README.md)) with Docker infrastructure up (`docker compose up -d` from repo root)

## Getting Started

```bash
pnpm install
pnpm dev
```

The dev server starts at https://localhost:5173 and proxies `/api` requests to the API target.

### API Target

The dev/preview server proxies `/api` to a configurable target, controlled by the `VITE_API_TARGET` env var:

- **No `.env` file** → defaults to the staging API `https://staging.pedalons.fr`. No backend needed locally.
- **Local backend** → copy `.env.example` to `.env` and set the target:

  ```bash
  cp .env.example .env
  # then in .env:
  VITE_API_TARGET=http://localhost:8080
  ```

The proxy derives `X-Forwarded-Host` / `X-Forwarded-Proto` from the target URL so multi-tenant domain resolution stays correct. `.env` is git-ignored; `.env.example` is committed.

### HTTPS Setup (required for WebAuthn/passkeys)

Vite serves HTTPS only when it finds `localhost+2.pem` and `localhost+2-key.pem` in this folder, and
plain HTTP otherwise. Generate them with [mkcert](https://github.com/FiloSottile/mkcert) — three
hosts, since that is what names the files `localhost+2`:

```bash
mkcert -install                            # one time: install local CA
mkcert localhost 127.0.0.1 <your LAN IP>   # generates localhost+2.pem and localhost+2-key.pem
```

## Scripts

| Script | Description |
|--------|-------------|
| `pnpm dev` | Dev server with HMR (client-side rendering only) |
| `pnpm dev:ssr` | SSR dev server (`node server.js`, localhost:3000) — see [docs/SSR.md](docs/SSR.md) |
| `pnpm build` | Production build, client + SSR bundle (no type checking) |
| `pnpm typecheck` | TypeScript check (`tsc -b`) |
| `pnpm preview` | Preview production build locally |
| `pnpm serve:ssr` | Build, then run the SSR server in production mode |
| `pnpm generate-api` | Regenerate API client from OpenAPI contract |
| `pnpm generate-routes` | Regenerate path builders + deeplinks from `../contracts/routes.yaml` |
| `pnpm generate-brand-colors` | Regenerate the business colour code (web + mobile) from `../contracts/brand-colors.yaml` |
| `pnpm generate-icons` | Regenerate PWA icons |
| `pnpm lint` | oxlint |
| `pnpm format` | Sort the translation catalogues (i18next-cli extract), then Prettier |
| `pnpm test` | Vitest (watch mode) |
| `pnpm test:coverage` | Vitest with coverage report |
| `pnpm e2e` | Playwright against the e2e stack — see [e2e/README.md](e2e/README.md) |
| `pnpm i18n:check` | Translation catalogues sorted and complete, `t()` params, English vs French — see CLAUDE.md « i18n » |
| `pnpm check` | Install, regenerate, format, typecheck, lint, i18n:check and build |

## API Client Generation

The API layer is generated from the backend's OpenAPI contract using [Orval](https://orval.dev/):

```bash
# 1. Generate OpenAPI spec (from backend/)
cd ../backend && mvn package -DskipTests

# 2. Generate TypeScript client (from frontend/)
pnpm generate-api
```

This produces React Query hooks, TypeScript DTOs, and Zod schemas in `src/api/`. **Do not edit generated files.**

## Stack

| Concern | Library |
|---------|---------|
| UI Components | [Mantine](https://mantine.dev/) 9 |
| Routing | React Router 7 |
| Server State | TanStack React Query 5 |
| Client State | Zustand 5 |
| Forms | Mantine Form + Zod validation |
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

Runtime app config comes from the `/api/config` endpoint — no `.env` files for app config. The only
`.env` var is `VITE_API_TARGET`, which just points the dev-server proxy at an API (see
[API Target](#api-target)).
