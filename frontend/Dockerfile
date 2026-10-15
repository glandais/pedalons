####
# Base: node + pnpm via corepack (shared by all stages)
# The Node version is the one in frontend/.nvmrc, which the CI reads: change both together
# (here and in the runtime stage below).
####
FROM node:26.11.1-alpine AS base

WORKDIR /app

# pnpm 11 only reads pnpm_config_* variables (npm_config_* is ignored). The update
# notifier is noise in a build: the version is the one pinned by packageManager.
ENV pnpm_config_store_dir=/pnpm-store \
    pnpm_config_update_notifier=false

RUN npm install --global --force corepack@latest && \
    corepack enable

# Manifests only — this layer (and the installs below) stay cached until a
# dependency actually changes, independent of any source edit.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Fetches the pnpm version pinned by packageManager in package.json.
RUN corepack install

####
# Production dependencies only — keyed solely on the manifests above, so the
# runtime node_modules layer is reused across source-only rebuilds.
####
FROM base AS prod-deps

RUN --mount=type=cache,id=pnpm-store,target=/pnpm-store \
    pnpm install --prod --frozen-lockfile

####
# Build: full dependency tree, then compile the client + server bundles.
####
FROM base AS build

RUN --mount=type=cache,id=pnpm-store,target=/pnpm-store \
    pnpm install --frozen-lockfile

# Copy source last (legal markdown files pre-copied by build.sh). Everything
# above is dependency-only, so editing source never busts the install layers.
COPY . .

# Sourcemaps are opt-in per environment (staging: true, prod: false/unset) — see build.sh.
ARG VITE_BUILD_SOURCEMAP=false
ENV VITE_BUILD_SOURCEMAP=$VITE_BUILD_SOURCEMAP

# The build context is frontend/ only, so vite.config.ts's loadEnv() of the root .env finds nothing
# in here — forward it as a build-arg instead (vite's loadEnv also merges matching process.env vars).
# Opt-in per environment, same as VITE_BUILD_SOURCEMAP above — see build.sh.
ARG FRONTEND_PREFETCH_AUDIT=false
ENV FRONTEND_PREFETCH_AUDIT=$FRONTEND_PREFETCH_AUDIT

# Build client + server bundles (dist/client + dist/server)
RUN pnpm build

####
# Runtime stage with Node.js for SSR
####
FROM node:26.11.1-alpine

WORKDIR /app
ENV NODE_ENV=production

# Copy layers least- to most-frequently-changing so registry pulls reuse the
# heavy node_modules layer whenever only source (dist/server.js) changed.
COPY --from=prod-deps /app/node_modules/ ./node_modules/
COPY --from=build /app/package.json ./
COPY --from=build /app/server.js ./
COPY --from=build /app/server/ ./server/
COPY --from=build /app/dist/ ./dist/

EXPOSE 3000

USER node

CMD ["node", "server.js"]
