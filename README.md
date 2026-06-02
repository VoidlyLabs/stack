# Voidly Stack

Docker Compose deployer for self-hosted Voidly on Ubuntu/VPS. No reverse proxy is included: services are exposed directly on configured ports. Domains, redirects, and TLS certificates are handled outside this repo.

## Services

- `mongo`: MongoDB with persistent Docker volume.
- `core`: NestJS API, default host port `3000`.
- `admin`: Next.js admin panel, default host port `3001`.
- `app`: Next.js public app, default host port `3002`.

## Ubuntu VPS Setup

Install Docker and Compose plugin:

```sh
sudo sh scripts/ubuntu-prepare.sh
```

Expected repo layout:

```text
~/VoidlyLabs/
  stack/
  core/
  admin/
  app/
```

Example clone flow:

```sh
mkdir -p ~/VoidlyLabs
cd ~/VoidlyLabs
git clone https://github.com/VoidlyLabs/stack.git
git clone https://github.com/VoidlyLabs/core.git
git clone https://github.com/VoidlyLabs/admin.git
git clone https://github.com/VoidlyLabs/app.git
cd stack
```

If your admin repo is named `adminpanel`, set `ADMIN_PATH=../adminpanel` in `.env`.

## First Run

```sh
cd ~/VoidlyLabs/stack
sh deploy.sh init
nano .env
sh deploy.sh up
```

Before `up`, replace these in `.env`:

```env
PUBLIC_CORE_URL=http://YOUR_SERVER_IP:3000
APP_PUBLIC_URL=http://YOUR_SERVER_IP:3002
```

Open firewall ports if needed:

```sh
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp
sudo ufw allow 3002/tcp
```

Then test:

- Core API / Swagger: `http://YOUR_SERVER_IP:3000/api`
- Admin: `http://YOUR_SERVER_IP:3001`
- App: `http://YOUR_SERVER_IP:3002`

## Commands

```sh
sh deploy.sh up            # sequential build/start all services
sh deploy.sh up core       # rebuild/start one service
sh deploy.sh build admin   # rebuild one service
sh deploy.sh logs          # follow all logs
sh deploy.sh logs core     # follow one service logs
sh deploy.sh ps            # show containers
sh deploy.sh restart app   # restart one service
sh deploy.sh down          # stop and remove containers, keep volumes
sh deploy.sh config        # render compose config
```

Do not use `docker compose up --build` on a small VPS. `deploy.sh up` builds services one by one and sets `COMPOSE_PARALLEL_LIMIT=1`.

## Memory

Build memory cap:

```env
NODE_BUILD_MEMORY_MB=768
```

If the VPS starts swapping hard, try `512`. If Next.js build fails with out-of-memory, raise to `1024` or add swap:

```sh
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## HTTP vs HTTPS

Keep this while testing direct HTTP ports:

```env
CORE_NODE_ENV=development
```

Current `core` marks auth cookies as `Secure` when `NODE_ENV=production`; browsers will not send Secure cookies over plain HTTP.

When you later put HTTPS in front, switch to external HTTPS URLs and production mode:

```env
PUBLIC_CORE_URL=https://api.example.com
APP_PUBLIC_URL=https://example.com
CORE_NODE_ENV=production
```

## Rebuild Rule

`PUBLIC_CORE_URL` is baked into `admin` and `app` during Next.js build. After changing it:

```sh
sh deploy.sh up admin app
```

## Data

Persistent volumes:

- `voidly_mongo_data`: MongoDB data.
- `voidly_core_uploads`: uploaded files served by `core` from `/uploads`.