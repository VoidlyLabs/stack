# Voidly Stack

[English version](./README.md)

Voidly Stack - це репозиторій Docker Compose розгортання для self-hosted Voidly.

Він запускає повну платформу на вашому сервері:

- `traefik` - HTTPS reverse proxy з автоматичними сертифікатами Let's Encrypt;
- `mongo` - база даних MongoDB;
- `core` - backend API на NestJS;
- `admin` - адміністративна панель на Next.js;
- `app` - публічна вітрина магазину на Next.js.

Stack розрахований на доменне HTTPS розгортання. Traefik публікує порти `80` і `443`, маршрутизує traffic за hostnames і залишає application services приватними в Docker network.

## Структура Репозиторію

```text
compose.yaml              Docker Compose definition
deploy.sh                 основна обгортка для deployment команд
.env.example              шаблон змінних середовища
scripts/ubuntu-prepare.sh Ubuntu/Debian Docker installer
scripts/*.sh              короткі wrappers навколо deploy.sh
core/                     submodule backend API
admin/                    submodule адмін-панелі
app/                      submodule вітрини
docker/node/Dockerfile    спільний Node.js build image
```

Submodules налаштовані в `.gitmodules`:

| Шлях | Репозиторій |
| --- | --- |
| `core` | `https://github.com/VoidlyLabs/core.git` |
| `admin` | `https://github.com/VoidlyLabs/adminpanel.git` |
| `app` | `https://github.com/VoidlyLabs/app.git` |

## Сервіси

| Сервіс | Опис | Публічний доступ |
| --- | --- | --- |
| `traefik` | Reverse proxy і Let's Encrypt ACME client | `80`, `443` |
| `mongo` | База даних MongoDB 7 | лише внутрішній |
| `core` | NestJS API та Swagger docs | `https://CORE_HOST` |
| `admin` | Адміністративна панель Next.js | `https://ADMIN_HOST` |
| `app` | Вітрина Next.js | `https://APP_HOST` |

## Вимоги

- Ubuntu/Debian server або інший host з Docker Engine і Docker Compose plugin.
- Git із підтримкою submodules.
- OpenSSL для генерації secrets під час `deploy.sh init`.
- Мінімум 1 GB RAM для невеликого deployment. Для low-memory VPS додайте swap.
- DNS `A` або `AAAA` records для API, admin і storefront domains, які вказують на server.
- Відкриті inbound ports `80/tcp` і `443/tcp` для Traefik і Let's Encrypt HTTP-01 validation.

## 1. Склонуйте Stack

```sh
git clone --recurse-submodules https://github.com/VoidlyLabs/stack.git
cd stack
```

Якщо репозиторій було склоновано без submodules, ініціалізуйте їх пізніше:

```sh
git submodule update --init --recursive
```

## 2. Підготуйте Сервер

На Ubuntu/Debian встановіть Docker і Compose plugin:

```sh
sudo sh scripts/ubuntu-prepare.sh
```

Якщо ви працюєте на новому сервері, спочатку склонуйте репозиторій або скопіюйте лише цей script. Script встановлює `ca-certificates`, `curl`, `git`, `openssl`, Docker Engine, Buildx і Docker Compose plugin.

Відкрийте HTTP та HTTPS порти:

```sh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

Application ports напряму не публікуються. Запити мають входити через Traefik.

## 3. Створіть І Відредагуйте `.env`

Згенеруйте `.env` з `.env.example`:

```sh
sh deploy.sh init
```

`deploy.sh init` створює `.env`, якщо його ще немає, і замінює placeholder secrets для MongoDB, JWT та початкового admin password.

Відредагуйте файл:

```sh
nano .env
```

Найважливіші значення:

```env
# Назва проєкту для Docker Compose resources.
STACK_NAME=voidly

# Email для Let's Encrypt certificate notices.
TRAEFIK_ACME_EMAIL=admin@example.com

# Hostnames, які маршрутизує Traefik. DNS має вказувати на ваш server.
CORE_HOST=api.example.com
ADMIN_HOST=admin.example.com
APP_HOST=example.com

# Публічні browser-facing URLs. Для Traefik використовуйте HTTPS domains.
PUBLIC_CORE_URL=https://api.example.com
ADMIN_PUBLIC_URL=https://admin.example.com
APP_PUBLIC_URL=https://example.com

# Production вмикає Secure auth cookies. Використовуйте лише з HTTPS.
CORE_NODE_ENV=production

# Optional cookie scope для auth між subdomains.
COOKIE_DOMAIN=.example.com

# Початковий admin account. Створюється під час першого startup, якщо його ще немає.
INITIAL_USER_USERNAME=admin
INITIAL_USER_PASSWORD=<generated-or-custom-password>
```

Залишайте `COOKIE_DOMAIN` порожнім для IP-based experiments або непов'язаних domains. Для subdomains під одним root domain використовуйте значення з крапкою на початку, наприклад `.example.com`.

`PUBLIC_CORE_URL`, `ADMIN_PUBLIC_URL` і `APP_PUBLIC_URL` використовуються browser-side кодом та передаються у frontend builds. Якщо зміните їх пізніше, перебудуйте frontend services:

```sh
sh deploy.sh up admin app
```

## 4. Запустіть Платформу

Побудуйте і запустіть всі сервіси:

```sh
sh deploy.sh up
```

`deploy.sh up` запускає MongoDB, потім по черзі будує та запускає `core`, `admin`, `app` і `traefik`. Послідовний build зроблено навмисно: він зменшує memory pressure на невеликих VPS.

Перший startup може тривати кілька хвилин, бо всі Node.js dependencies встановлюються і всі сервіси будуються всередині Docker. Traefik також може потребувати трохи часу для отримання Let's Encrypt certificates після правильного DNS setup.

## 5. Перевірте Розгортання

Відкрийте ці URL у браузері:

| Ціль | URL |
| --- | --- |
| API / Swagger | `https://api.example.com/api` |
| Адмін-панель | `https://admin.example.com` |
| Вітрина | `https://example.com` |

Перевірте containers:

```sh
sh deploy.sh ps
```

Дивіться logs:

```sh
sh deploy.sh logs
sh deploy.sh logs core
```

## Команди

```sh
sh deploy.sh init             # створити .env із generated secrets, якщо його немає
sh deploy.sh up               # побудувати і запустити mongo, core, admin та app послідовно
sh deploy.sh up core          # перебудувати і перезапустити один application service
sh deploy.sh build admin      # перебудувати без restart інших сервісів
sh deploy.sh restart app      # restart без rebuild
sh deploy.sh logs             # logs сервісів, які обробляє deploy.sh
sh deploy.sh logs core        # logs одного сервісу
sh deploy.sh ps               # показати containers, які обробляє deploy.sh
sh deploy.sh down             # зупинити і видалити containers, volumes залишити
sh deploy.sh config           # вивести resolved Compose config
sh deploy.sh pull             # pull image-based services, де це застосовно
```

Не використовуйте `docker compose up --build` напряму для всіх сервісів на малих VPS. `deploy.sh up` будує важкі Node.js services по одному і за замовчуванням задає `COMPOSE_PARALLEL_LIMIT=1`.

## Довідник Змінних Середовища

| Змінна | Призначення |
| --- | --- |
| `STACK_NAME` | Compose project name і Docker resource prefix. |
| `MONGO_VERSION` | Версія MongoDB image. За замовчуванням: `7`. |
| `NODE_BUILD_MEMORY_MB` | Memory cap для Node.js build через `--max-old-space-size`. |
| `CORE_PATH` | Build context backend service. |
| `ADMIN_PATH` | Build context admin panel service. |
| `APP_PATH` | Build context storefront service. |
| `CORE_DOCKERFILE` | Dockerfile path відносно `CORE_PATH`. |
| `ADMIN_DOCKERFILE` | Dockerfile path відносно `ADMIN_PATH`. |
| `APP_DOCKERFILE` | Dockerfile path відносно `APP_PATH`. |
| `TRAEFIK_ACME_EMAIL` | Email для Let's Encrypt ACME registration і expiry notices. |
| `CORE_HOST`, `ADMIN_HOST`, `APP_HOST` | Hostnames, за якими Traefik маршрутизує API, admin і storefront traffic. |
| `PUBLIC_CORE_URL` | Публічний API URL для admin, app, cookies і uploaded file URLs. |
| `ADMIN_PUBLIC_URL` | Публічний URL адмін-панелі, який передається у admin frontend. |
| `APP_PUBLIC_URL` | Публічний URL вітрини для storefront build/runtime. |
| `CORE_NODE_ENV` | Runtime mode backend. Використовуйте `production` з HTTPS; `development` лише для plain HTTP testing. |
| `COOKIE_DOMAIN` | Optional cookie domain для auth між subdomains, наприклад `.example.com`. |
| `MONGO_DATA_PATH` | MongoDB data directory на Linux host. За замовчуванням: `/var/lib/voidly/mongo`. |
| `MONGO_USERNAME`, `MONGO_PASSWORD`, `MONGO_DATABASE` | MongoDB credentials і database name. |
| `INITIAL_USER_USERNAME`, `INITIAL_USER_PASSWORD` | Початковий admin account, який створюється на першому startup, якщо відсутній. |
| `SERVER_JWT_SECRET`, `CLIENT_JWT_SECRET` | JWT signing secrets. |
| `PASSWORD_SALT_ROUNDS` | bcrypt password hashing cost. |
| `CLIENT_TOKEN_MAX_AGE_HRS`, `USER_TOKEN_MAX_AGE_HRS` | Cookie/JWT lifetime values. |
| `USER_TOKEN_COOKIE`, `CLIENT_TOKEN_COOKIE` | Cookie names для admin і customer auth flows. |

## HTTPS І Traefik

Traefik читає Docker labels з `compose.yaml`, створює HTTPS routers для `CORE_HOST`, `ADMIN_HOST` і `APP_HOST`, та зберігає Let's Encrypt certificates у Docker volume `traefik_certs`.

Перед запуском Traefik перевірте, що:

- DNS records для всіх налаштованих hostnames вказують на цей server.
- Ports `80` і `443` доступні з internet.
- `TRAEFIK_ACME_EMAIL` містить реальну email address.
- `PUBLIC_CORE_URL`, `ADMIN_PUBLIC_URL` і `APP_PUBLIC_URL` використовують ті самі public HTTPS domains.

У production mode auth cookies мають прапорець `Secure`. Вони не працюватимуть через plain HTTP. Для звичайного Traefik deployment залишайте `CORE_NODE_ENV=production`.

## Налаштування Пам'яті

Default build memory cap - `768 MB`:

```env
NODE_BUILD_MEMORY_MB=768
```

Для VPS з 1 GB RAM спробуйте:

```env
NODE_BUILD_MEMORY_MB=512
```

Якщо Next.js build падає через out-of-memory і сервер має достатньо RAM або swap, збільшіть значення:

```env
NODE_BUILD_MEMORY_MB=1024
```

## Оновлення

Оновіть stack і submodules:

```sh
git pull --recurse-submodules
git submodule update --init --recursive
```

Оновіть Traefik за потреби:

```sh
docker compose --env-file .env -f compose.yaml pull traefik
docker compose --env-file .env -f compose.yaml up -d traefik
```

Перебудуйте змінені application services:

```sh
sh deploy.sh build core
sh deploy.sh restart core
```

Для frontend changes або зміни public URLs:

```sh
sh deploy.sh up admin app
```

MongoDB data, uploads і Traefik certificates зберігаються між rebuilds і restarts.

## Дані Та Volumes

| Storage | Вміст |
| --- | --- |
| `MONGO_DATA_PATH` (`/var/lib/voidly/mongo` за замовчуванням) | Файли бази даних MongoDB на Linux host. |
| `voidly_core_uploads` | Uploaded files, які API віддає на `/uploads`. |
| `voidly_traefik_certs` | Let's Encrypt certificates, якими керує Traefik. |

`sh deploy.sh down` видаляє containers, але залишає Docker volumes. MongoDB зберігається поза Docker volumes, тому `docker compose down -v`, `docker volume prune` і `docker volume rm` не видаляють файли бази даних. Щоб видалити MongoDB data, видаліть `MONGO_DATA_PATH` явно і лише після backup.

## Troubleshooting

Якщо Traefik не випускає certificates, перевірте DNS, firewall rules і Traefik logs:

```sh
docker compose --env-file .env -f compose.yaml logs -f traefik
```

Якщо browser не може підключитися до API, перевірте `CORE_HOST`, `PUBLIC_CORE_URL`, firewall rules і health статус `core`:

```sh
sh deploy.sh ps
sh deploy.sh logs core
```

Якщо зображення не завантажуються, перевірте, що `LOCAL_STORAGE_BASE_URL` всередині `core` відповідає публічному API URL. У stack це значення береться з `PUBLIC_CORE_URL`.

Якщо admin або storefront досі використовує старий API URL, перебудуйте frontend services:

```sh
sh deploy.sh up admin app
```

Якщо authentication між subdomains не працює, переконайтесь, що `COOKIE_DOMAIN` відповідає спільному parent domain і всі public URLs використовують HTTPS.
