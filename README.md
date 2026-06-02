# Voidly Stack

Docker Compose deployer for self-hosted Voidly. Services are exposed directly on configured ports — no reverse proxy included.

## Services

| Service | Description | Default port |
|---------|-------------|--------------|
| `mongo` | MongoDB | — |
| `core` | NestJS API | 3000 |
| `admin` | Next.js admin panel | 3001 |
| `app` | Next.js public app | 3002 |

---

## Deploy guide

### 1. Prepare the server

Install Docker and Compose plugin (Ubuntu/Debian):

```sh
sudo sh scripts/ubuntu-prepare.sh
```

Open firewall ports:

```sh
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp
sudo ufw allow 3002/tcp
```

### 2. Clone

```sh
git clone --recurse-submodules https://github.com/VoidlyLabs/stack.git
cd stack
```

### 3. Configure

```sh
sh deploy.sh init
nano .env
```

Required changes in `.env`:

```env
# Public URLs visible to browsers — use your VPS IP or domain
PUBLIC_CORE_URL=http://YOUR_IP:3000
APP_PUBLIC_URL=http://YOUR_IP:3002

# Initial admin account (created on first startup)
INITIAL_USER_USERNAME=admin
INITIAL_USER_PASSWORD=            # auto-generated, check .env after init
```

> `PUBLIC_CORE_URL` is baked into `admin` and `app` at build time. After changing it, rebuild: `sh deploy.sh up admin app`

### 4. Start

```sh
sh deploy.sh up
```

Builds and starts all services sequentially. First run takes a few minutes.

### 5. Verify

- API / Swagger: `http://YOUR_IP:3000/api`
- Admin panel: `http://YOUR_IP:3001`
- App: `http://YOUR_IP:3002`

---

## Commands

```sh
sh deploy.sh up              # build and start all services
sh deploy.sh up core         # rebuild and restart one service
sh deploy.sh build admin     # rebuild without restarting
sh deploy.sh restart app     # restart without rebuild
sh deploy.sh logs            # follow all logs
sh deploy.sh logs core       # follow one service logs
sh deploy.sh ps              # show running containers
sh deploy.sh down            # stop and remove containers (volumes kept)
sh deploy.sh config          # print resolved compose config
```

> Do not use `docker compose up --build` directly — `deploy.sh up` builds services one by one to avoid OOM on small VPSes.

---

## Updating

```sh
git pull --recurse-submodules
sh deploy.sh build core      # rebuild changed services
sh deploy.sh restart core    # apply without downtime
```

Volumes are preserved across restarts and rebuilds.

---

## HTTPS

Keep `CORE_NODE_ENV=development` while testing over plain HTTP — auth cookies are marked `Secure` in production mode and won't work without HTTPS.

Once you put a reverse proxy with TLS in front:

```env
PUBLIC_CORE_URL=https://api.example.com
APP_PUBLIC_URL=https://example.com
CORE_NODE_ENV=production
```

Then rebuild: `sh deploy.sh up admin app core`

---

## Memory

Default build memory cap is `768 MB`. Adjust in `.env`:

```env
NODE_BUILD_MEMORY_MB=512   # for 1 GB VPS
NODE_BUILD_MEMORY_MB=1024  # if Next.js build fails with OOM
```

If the VPS is still swapping, add a swapfile:

```sh
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## Volumes

| Volume | Contents |
|--------|----------|
| `voidly_mongo_data` | MongoDB data |
| `voidly_core_uploads` | Uploaded files served at `/uploads` |
