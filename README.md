# Voidly Stack

[Українська версія](./README.uk.md)

Voidly Stack is the Docker Compose deployment repository for self-hosted Voidly.

It runs the complete platform on your server:

- `mongo` - MongoDB database;
- `core` - NestJS backend API;
- `admin` - Next.js administrative panel;
- `app` - Next.js public storefront.

The stack exposes services directly on configured ports. It does not include a reverse proxy. Add Nginx, Caddy, Traefik, or another TLS proxy separately when you need HTTPS and custom domains.

## Repository Layout

```text
compose.yaml             Docker Compose definition
deploy.sh                main deployment command wrapper
.env.example             environment template
scripts/ubuntu-prepare.sh Ubuntu/Debian Docker installer
scripts/*.sh             small wrappers around deploy.sh
core/                    backend API submodule
admin/                   admin panel submodule
app/                     storefront submodule
docker/node/Dockerfile   shared Node.js build image
```

Submodules are configured in `.gitmodules`:

| Path | Repository |
| --- | --- |
| `core` | `https://github.com/VoidlyLabs/core.git` |
| `admin` | `https://github.com/VoidlyLabs/adminpanel.git` |
| `app` | `https://github.com/VoidlyLabs/app.git` |

## Services

| Service | Description | Default published port |
| --- | --- | --- |
| `mongo` | MongoDB 7 database | internal only |
| `core` | NestJS API and Swagger docs | `3000` |
| `admin` | Next.js admin panel | `3001` |
| `app` | Next.js storefront | `3002` |

## Requirements

- Ubuntu/Debian server or another host with Docker Engine and Docker Compose plugin.
- Git with submodule support.
- OpenSSL for generated secrets during `deploy.sh init`.
- At least 1 GB RAM for small deployments. Add swap for low-memory VPSes.
- Open inbound ports for the published services or a reverse proxy in front of them.

## 1. Prepare The Server

On Ubuntu/Debian, install Docker and the Compose plugin:

```sh
sudo sh scripts/ubuntu-prepare.sh
```

If you are running the script from a fresh server, clone the repository first or copy only the script. The script installs `ca-certificates`, `curl`, `git`, `openssl`, Docker Engine, Buildx, and Docker Compose plugin.

Allow direct service ports when you do not use a reverse proxy:

```sh
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp
sudo ufw allow 3002/tcp
```

If a reverse proxy terminates TLS, expose only ports `80` and `443` publicly and bind Voidly services to localhost in `.env`.

## 2. Clone The Stack

```sh
git clone --recurse-submodules https://github.com/VoidlyLabs/stack.git
cd stack
```

If you cloned without submodules, initialize them later:

```sh
git submodule update --init --recursive
```

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

# Public browser-facing API URL. Use your VPS IP or API domain.
PUBLIC_CORE_URL=http://YOUR_IP:3000

# Public browser-facing storefront URL.
APP_PUBLIC_URL=http://YOUR_IP:3002

# Initial admin account. It is created on first startup if it does not exist.
INITIAL_USER_USERNAME=admin
INITIAL_USER_PASSWORD=<generated-or-custom-password>
```

`PUBLIC_CORE_URL` is used by browser-side code and image URLs. It is passed into `admin` and `app` at build time. If you change it later, rebuild both frontend services:

```sh
sh deploy.sh up admin app
```

## 4. Start The Platform

```sh
sh deploy.sh up
```

This command starts MongoDB, then builds and starts `core`, `admin`, and `app` one by one. Sequential builds are intentional: they reduce memory pressure on small VPSes.

First startup can take several minutes because all Node.js dependencies are installed and all services are built inside Docker.

## 5. Verify The Deployment

Open these URLs in your browser:

| Target | URL |
| --- | --- |
| API / Swagger | `http://YOUR_IP:3000/api` |
| Admin panel | `http://YOUR_IP:3001` |
| Storefront | `http://YOUR_IP:3002` |

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
sh deploy.sh up               # build and start all services sequentially
sh deploy.sh up core          # rebuild and restart one service
sh deploy.sh build admin      # rebuild without restarting other services
sh deploy.sh restart app      # restart without rebuild
sh deploy.sh logs             # follow logs for all services
sh deploy.sh logs core        # follow logs for one service
sh deploy.sh ps               # show containers
sh deploy.sh down             # stop and remove containers, keep volumes
sh deploy.sh config           # print resolved Compose config
sh deploy.sh pull             # pull image-based services where applicable
```

Do not use `docker compose up --build` directly on small VPSes. `deploy.sh up` builds heavy Node.js services one by one and sets `COMPOSE_PARALLEL_LIMIT=1` by default.

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
| `CORE_BIND`, `ADMIN_BIND`, `APP_BIND` | Host interface for published ports. Use `127.0.0.1` behind a reverse proxy. |
| `CORE_PORT`, `ADMIN_PORT`, `APP_PORT` | Published host ports. |
| `PUBLIC_CORE_URL` | Public API URL used by admin, app, cookies, and uploaded file URLs. |
| `APP_PUBLIC_URL` | Public storefront URL used by the storefront build/runtime. |
| `CORE_NODE_ENV` | Backend runtime mode. Keep `development` for plain HTTP cookie testing. |
| `MONGO_DATA_PATH` | MongoDB data directory on the Linux host. Default: `/var/lib/voidly/mongo`. |
| `MONGO_USERNAME`, `MONGO_PASSWORD`, `MONGO_DATABASE` | MongoDB credentials and database name. |
| `INITIAL_USER_USERNAME`, `INITIAL_USER_PASSWORD` | Initial admin account created on first startup if missing. |
| `SERVER_JWT_SECRET`, `CLIENT_JWT_SECRET` | JWT signing secrets. |
| `PASSWORD_SALT_ROUNDS` | bcrypt password hashing cost. |
| `CLIENT_TOKEN_MAX_AGE_HRS`, `USER_TOKEN_MAX_AGE_HRS` | Cookie/JWT lifetime values. |
| `USER_TOKEN_COOKIE`, `CLIENT_TOKEN_COOKIE` | Cookie names used by admin and customer auth flows. |

## HTTPS And Reverse Proxy

For direct HTTP testing, keep:

```env
CORE_NODE_ENV=development
PUBLIC_CORE_URL=http://YOUR_IP:3000
APP_PUBLIC_URL=http://YOUR_IP:3002
```

In production mode, auth cookies are marked `Secure`. They will not work over plain HTTP. After placing a TLS reverse proxy in front of the services, use HTTPS URLs:

```env
PUBLIC_CORE_URL=https://api.example.com
APP_PUBLIC_URL=https://example.com
CORE_NODE_ENV=production
```

If the reverse proxy is on the same host, bind services to localhost:

```env
CORE_BIND=127.0.0.1
ADMIN_BIND=127.0.0.1
APP_BIND=127.0.0.1
```

Then rebuild and restart services that consume these values:

```sh
sh deploy.sh up core admin app
```

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

Add swap on small VPSes:

```sh
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Updating

Update the stack and submodules:

```sh
git pull --recurse-submodules
git submodule update --init --recursive
```

Rebuild changed services:

```sh
sh deploy.sh build core
sh deploy.sh restart core
```

For frontend changes or changed public URLs:

```sh
sh deploy.sh up admin app
```

MongoDB data and Docker volumes are preserved across rebuilds and restarts.

## Data And Volumes

| Storage | Contents |
| --- | --- |
| `MONGO_DATA_PATH` (`/var/lib/voidly/mongo` by default) | MongoDB database files stored on the Linux host. |
| `voidly_core_uploads` | Uploaded files served by the API at `/uploads`. |

`sh deploy.sh down` removes containers but keeps Docker volumes. MongoDB is stored outside Docker volumes, so `docker compose down -v`, `docker volume prune`, and `docker volume rm` do not remove the database files. To remove MongoDB data, delete `MONGO_DATA_PATH` explicitly and only after taking a backup.

## Troubleshooting

If the browser cannot reach the API, check `PUBLIC_CORE_URL`, firewall rules, and whether `core` is healthy:

```sh
sh deploy.sh ps
sh deploy.sh logs core
```

If images do not load, verify that `LOCAL_STORAGE_BASE_URL` inside `core` resolves to the same public API URL. In the stack this is derived from `PUBLIC_CORE_URL`.

If admin or storefront still points to an old API URL, rebuild the frontend services:

```sh
sh deploy.sh up admin app
```

If authentication works locally but fails after switching to production mode, confirm that the API is served over HTTPS and `PUBLIC_CORE_URL` uses `https://`.
