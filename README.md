# Voidly Stack

[Українська версія](./README.uk.md)

Voidly Stack is the Docker Compose deployment repository for self-hosted Voidly.

It runs the complete platform on your server:

- `traefik` - HTTPS reverse proxy with automatic Let's Encrypt certificates;
- `mongo` - MongoDB database;
- `core` - NestJS backend API;
- `admin` - Next.js administrative panel;
- `app` - Next.js public storefront.

The stack is designed for domain-based HTTPS deployment. Traefik publishes ports `80` and `443`, routes traffic by hostnames, and keeps application services private on the Docker network.

## Repository Layout

```text
compose.yaml              Docker Compose definition
deploy.sh                 main deployment command wrapper
.env.example              environment template
scripts/ubuntu-prepare.sh Ubuntu/Debian Docker installer
scripts/*.sh              small wrappers around deploy.sh
core/                     backend API submodule
admin/                    admin panel submodule
app/                      storefront submodule
docker/node/Dockerfile    shared Node.js build image
```

Submodules are configured in `.gitmodules`:

| Path | Repository |
| --- | --- |
| `core` | `https://github.com/VoidlyLabs/core.git` |
| `admin` | `https://github.com/VoidlyLabs/adminpanel.git` |
| `app` | `https://github.com/VoidlyLabs/app.git` |

## Services

| Service | Description | Public access |
| --- | --- | --- |
| `traefik` | Reverse proxy and Let's Encrypt ACME client | `80`, `443` |
| `mongo` | MongoDB 7 database | internal only |
| `core` | NestJS API and Swagger docs | `https://CORE_HOST` |
| `admin` | Next.js admin panel | `https://ADMIN_HOST` |
| `app` | Next.js storefront | `https://APP_HOST` |

## Requirements

- Ubuntu/Debian server or another host with Docker Engine and Docker Compose plugin.
- Git with submodule support.
- OpenSSL for generated secrets during `deploy.sh init`.
- At least 1 GB RAM for small deployments. Add swap for low-memory VPSes.
- DNS `A` or `AAAA` records for API, admin, and storefront domains pointing to the server.
- Open inbound ports `80/tcp` and `443/tcp` for Traefik and Let's Encrypt HTTP-01 validation.

## 1. Clone The Stack

```sh
git clone --recurse-submodules https://github.com/VoidlyLabs/stack.git
cd stack
```

If you cloned without submodules, initialize them later:

```sh
git submodule update --init --recursive
```

## 2. Prepare The Server

On Ubuntu/Debian, install Docker and the Compose plugin:

```sh
sudo sh scripts/ubuntu-prepare.sh
```

If you are running the script from a fresh server, clone the repository first or copy only the script. The script installs `ca-certificates`, `curl`, `git`, `openssl`, Docker Engine, Buildx, and Docker Compose plugin.

Open HTTP and HTTPS ports:

```sh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

Application ports are not published directly. Requests should enter through Traefik.

## 3. Create And Edit `.env`

Generate `.env` from `.env.example`:

```sh
sh deploy.sh init
```

`deploy.sh init` creates `.env` if it does not exist and replaces placeholder secrets for MongoDB, JWT, and the initial admin password.

Edit the file:

```sh
nano .env
```

The most important values are:

```env
# Project name used by Docker Compose resources.
STACK_NAME=voidly

# Email used by Let's Encrypt for certificate notices.
TRAEFIK_ACME_EMAIL=admin@example.com

# Hostnames routed by Traefik. DNS must point these names to your server.
CORE_HOST=api.example.com
ADMIN_HOST=admin.example.com
APP_HOST=example.com

# Public browser-facing URLs. Use HTTPS domains when Traefik is enabled.
PUBLIC_CORE_URL=https://api.example.com
ADMIN_PUBLIC_URL=https://admin.example.com
APP_PUBLIC_URL=https://example.com

# Production enables Secure auth cookies. Use it only with HTTPS.
CORE_NODE_ENV=production

# Optional cross-subdomain cookie scope.
COOKIE_DOMAIN=.example.com

# Initial admin account. It is created on first startup if it does not exist.
INITIAL_USER_USERNAME=admin
INITIAL_USER_PASSWORD=<generated-or-custom-password>
```

Use an empty `COOKIE_DOMAIN` for IP-based experiments or unrelated domains. For subdomains under the same root domain, use a leading-dot value such as `.example.com`.

`PUBLIC_CORE_URL`, `ADMIN_PUBLIC_URL`, and `APP_PUBLIC_URL` are used by browser-side code and are passed into frontend builds. If you change them later, rebuild the frontend services:

```sh
sh deploy.sh up admin app
```

## 4. Start The Platform

Build and start the application services:

```sh
sh deploy.sh up
```

`deploy.sh up` starts MongoDB, then builds and starts `core`, `admin`, and `app` one by one. Sequential builds are intentional: they reduce memory pressure on small VPSes.

First startup can take several minutes because all Node.js dependencies are installed and all services are built inside Docker. Traefik may also need a short time to request Let's Encrypt certificates after DNS is correct.

## 5. Verify The Deployment

Open these URLs in your browser:

| Target | URL |
| --- | --- |
| API / Swagger | `https://api.example.com/api` |
| Admin panel | `https://admin.example.com` |
| Storefront | `https://example.com` |

Check containers:

```sh
sh deploy.sh ps
```

Follow logs:

```sh
sh deploy.sh logs
sh deploy.sh logs core
```

## Commands

```sh
sh deploy.sh init             # create .env with generated secrets if missing
sh deploy.sh up               # build and start mongo, core, admin, and app sequentially
sh deploy.sh up core          # rebuild and restart one application service
sh deploy.sh build admin      # rebuild without restarting other services
sh deploy.sh restart app      # restart without rebuild
sh deploy.sh logs             # follow logs for all services known to deploy.sh
sh deploy.sh logs core        # follow logs for one service
sh deploy.sh ps               # show containers known to deploy.sh
sh deploy.sh down             # stop and remove containers, keep volumes
sh deploy.sh config           # print resolved Compose config
sh deploy.sh pull             # pull image-based services where applicable
```

Do not use `docker compose up --build` directly on small VPSes for all services. `deploy.sh up` builds heavy Node.js services one by one and sets `COMPOSE_PARALLEL_LIMIT=1` by default.

## Environment Reference

| Variable | Purpose |
| --- | --- |
| `STACK_NAME` | Compose project name and Docker resource prefix. |
| `MONGO_VERSION` | MongoDB image version. Default: `7`. |
| `NODE_BUILD_MEMORY_MB` | Node.js build memory cap passed to `--max-old-space-size`. |
| `CORE_PATH` | Build context for the backend service. |
| `ADMIN_PATH` | Build context for the admin panel service. |
| `APP_PATH` | Build context for the storefront service. |
| `CORE_DOCKERFILE` | Dockerfile path relative to `CORE_PATH`. |
| `ADMIN_DOCKERFILE` | Dockerfile path relative to `ADMIN_PATH`. |
| `APP_DOCKERFILE` | Dockerfile path relative to `APP_PATH`. |
| `TRAEFIK_ACME_EMAIL` | Email used by Let's Encrypt ACME registration and expiry notices. |
| `CORE_HOST`, `ADMIN_HOST`, `APP_HOST` | Hostnames Traefik uses to route API, admin, and storefront traffic. |
| `PUBLIC_CORE_URL` | Public API URL used by admin, app, cookies, and uploaded file URLs. |
| `ADMIN_PUBLIC_URL` | Public admin panel URL passed to the admin frontend. |
| `APP_PUBLIC_URL` | Public storefront URL used by the storefront build/runtime. |
| `CORE_NODE_ENV` | Backend runtime mode. Use `production` with HTTPS; `development` is only for plain HTTP testing. |
| `COOKIE_DOMAIN` | Optional cookie domain for cross-subdomain auth, for example `.example.com`. |
| `MONGO_DATA_PATH` | MongoDB data directory on the Linux host. Default: `/var/lib/voidly/mongo`. |
| `MONGO_USERNAME`, `MONGO_PASSWORD`, `MONGO_DATABASE` | MongoDB credentials and database name. |
| `INITIAL_USER_USERNAME`, `INITIAL_USER_PASSWORD` | Initial admin account created on first startup if missing. |
| `SERVER_JWT_SECRET`, `CLIENT_JWT_SECRET` | JWT signing secrets. |
| `PASSWORD_SALT_ROUNDS` | bcrypt password hashing cost. |
| `CLIENT_TOKEN_MAX_AGE_HRS`, `USER_TOKEN_MAX_AGE_HRS` | Cookie/JWT lifetime values. |
| `USER_TOKEN_COOKIE`, `CLIENT_TOKEN_COOKIE` | Cookie names used by admin and customer auth flows. |

## HTTPS And Traefik

Traefik reads Docker labels from `compose.yaml`, creates HTTPS routers for `CORE_HOST`, `ADMIN_HOST`, and `APP_HOST`, and stores Let's Encrypt certificates in the `traefik_certs` Docker volume.

Before starting Traefik, confirm that:

- DNS records for all configured hostnames point to this server.
- Ports `80` and `443` are reachable from the internet.
- `TRAEFIK_ACME_EMAIL` is set to a real email address.
- `PUBLIC_CORE_URL`, `ADMIN_PUBLIC_URL`, and `APP_PUBLIC_URL` use the same public HTTPS domains.

In production mode, auth cookies are marked `Secure`. They will not work over plain HTTP. Keep `CORE_NODE_ENV=production` for normal Traefik deployments.

## Memory Tuning

The default build memory cap is `768 MB`:

```env
NODE_BUILD_MEMORY_MB=768
```

For a 1 GB VPS, try:

```env
NODE_BUILD_MEMORY_MB=512
```

If a Next.js build fails with out-of-memory errors and the server has enough RAM or swap, raise it:

```env
NODE_BUILD_MEMORY_MB=1024
```

## Updating

Update the stack and submodules:

```sh
git pull --recurse-submodules
git submodule update --init --recursive
```

Rebuild changed application services:

```sh
sh deploy.sh build core
sh deploy.sh restart core
```

For frontend changes or changed public URLs:

```sh
sh deploy.sh up admin app
```

MongoDB data, uploads, and Traefik certificates are preserved across rebuilds and restarts.

## Data And Volumes

| Storage | Contents |
| --- | --- |
| `MONGO_DATA_PATH` (`/var/lib/voidly/mongo` by default) | MongoDB database files stored on the Linux host. |
| `voidly_core_uploads` | Uploaded files served by the API at `/uploads`. |
| `voidly_traefik_certs` | Let's Encrypt certificates managed by Traefik. |

`sh deploy.sh down` removes containers but keeps Docker volumes. MongoDB is stored outside Docker volumes, so `docker compose down -v`, `docker volume prune`, and `docker volume rm` do not remove the database files. To remove MongoDB data, delete `MONGO_DATA_PATH` explicitly and only after taking a backup.

## Troubleshooting

If Traefik does not issue certificates, check DNS, firewall rules, and Traefik logs:

```sh
docker compose --env-file .env -f compose.yaml logs -f traefik
```

If the browser cannot reach the API, check `CORE_HOST`, `PUBLIC_CORE_URL`, firewall rules, and whether `core` is healthy:

```sh
sh deploy.sh ps
sh deploy.sh logs core
```

If images do not load, verify that `LOCAL_STORAGE_BASE_URL` inside `core` resolves to the same public API URL. In the stack this is derived from `PUBLIC_CORE_URL`.

If admin or storefront still points to an old API URL, rebuild the frontend services:

```sh
sh deploy.sh up admin app
```

If authentication fails between subdomains, confirm that `COOKIE_DOMAIN` matches the shared parent domain and that all public URLs use HTTPS.
