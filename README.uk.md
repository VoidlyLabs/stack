# Voidly Stack

[English version](./README.md)

Voidly Stack - це репозиторій Docker Compose розгортання для self-hosted Voidly.

Він запускає повну платформу на вашому сервері:

- `mongo` - база даних MongoDB;
- `core` - backend API на NestJS;
- `admin` - адміністративна панель на Next.js;
- `app` - публічна вітрина магазину на Next.js.

Stack публікує сервіси напряму на налаштованих портах. Reverse proxy не входить до складу репозиторію. Додайте Nginx, Caddy, Traefik або інший TLS proxy окремо, якщо потрібні HTTPS і власні домени.

## Структура Репозиторію

```text
compose.yaml             Docker Compose definition
deploy.sh                основна обгортка для deployment команд
.env.example             шаблон змінних середовища
scripts/ubuntu-prepare.sh Ubuntu/Debian Docker installer
scripts/*.sh             короткі wrappers навколо deploy.sh
core/                    submodule backend API
admin/                   submodule адмін-панелі
app/                     submodule вітрини
docker/node/Dockerfile   спільний Node.js build image
```

Submodules налаштовані в `.gitmodules`:

| Шлях | Репозиторій |
| --- | --- |
| `core` | `https://github.com/VoidlyLabs/core.git` |
| `admin` | `https://github.com/VoidlyLabs/adminpanel.git` |
| `app` | `https://github.com/VoidlyLabs/app.git` |

## Сервіси

| Сервіс | Опис | Порт за замовчуванням |
| --- | --- | --- |
| `mongo` | База даних MongoDB 7 | лише внутрішній |
| `core` | NestJS API та Swagger docs | `3000` |
| `admin` | Адміністративна панель Next.js | `3001` |
| `app` | Вітрина Next.js | `3002` |

## Вимоги

- Ubuntu/Debian server або інший host з Docker Engine і Docker Compose plugin.
- Git із підтримкою submodules.
- OpenSSL для генерації secrets під час `deploy.sh init`.
- Мінімум 1 GB RAM для невеликого deployment. Для low-memory VPS додайте swap.
- Відкриті inbound ports для опублікованих сервісів або reverse proxy перед ними.

## 1. Підготуйте Сервер

На Ubuntu/Debian встановіть Docker і Compose plugin:

```sh
sudo sh scripts/ubuntu-prepare.sh
```

Якщо ви працюєте на новому сервері, спочатку склонуйте репозиторій або скопіюйте лише цей script. Script встановлює `ca-certificates`, `curl`, `git`, `openssl`, Docker Engine, Buildx і Docker Compose plugin.

Відкрийте прямі порти сервісів, якщо не використовуєте reverse proxy:

```sh
sudo ufw allow 3000/tcp
sudo ufw allow 3001/tcp
sudo ufw allow 3002/tcp
```

Якщо TLS завершується на reverse proxy, публічно відкривайте лише `80` і `443`, а Voidly services прив'яжіть до localhost у `.env`.

## 2. Склонуйте Stack

```sh
git clone --recurse-submodules https://github.com/VoidlyLabs/stack.git
cd stack
```

Якщо репозиторій було склоновано без submodules, ініціалізуйте їх пізніше:

```sh
git submodule update --init --recursive
```

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

# Публічний browser-facing API URL. Використовуйте IP вашого VPS або API domain.
PUBLIC_CORE_URL=http://YOUR_IP:3000

# Публічний browser-facing URL вітрини.
APP_PUBLIC_URL=http://YOUR_IP:3002

# Початковий admin account. Створюється під час першого startup, якщо його ще немає.
INITIAL_USER_USERNAME=admin
INITIAL_USER_PASSWORD=<generated-or-custom-password>
```

`PUBLIC_CORE_URL` використовується browser-side кодом і URL зображень. Він передається в `admin` та `app` під час build. Якщо зміните його пізніше, перебудуйте обидва frontend services:

```sh
sh deploy.sh up admin app
```

## 4. Запустіть Платформу

```sh
sh deploy.sh up
```

Ця команда запускає MongoDB, потім по черзі будує та запускає `core`, `admin` і `app`. Послідовний build зроблено навмисно: він зменшує memory pressure на невеликих VPS.

Перший startup може тривати кілька хвилин, бо всі Node.js dependencies встановлюються і всі сервіси будуються всередині Docker.

## 5. Перевірте Розгортання

Відкрийте ці URL у браузері:

| Ціль | URL |
| --- | --- |
| API / Swagger | `http://YOUR_IP:3000/api` |
| Адмін-панель | `http://YOUR_IP:3001` |
| Вітрина | `http://YOUR_IP:3002` |

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
sh deploy.sh up               # побудувати і запустити всі сервіси послідовно
sh deploy.sh up core          # перебудувати і перезапустити один сервіс
sh deploy.sh build admin      # перебудувати без restart інших сервісів
sh deploy.sh restart app      # restart без rebuild
sh deploy.sh logs             # logs усіх сервісів
sh deploy.sh logs core        # logs одного сервісу
sh deploy.sh ps               # показати containers
sh deploy.sh down             # зупинити і видалити containers, volumes залишити
sh deploy.sh config           # вивести resolved Compose config
sh deploy.sh pull             # pull image-based services, де це застосовно
```

Не використовуйте `docker compose up --build` напряму на малих VPS. `deploy.sh up` будує важкі Node.js services по одному і за замовчуванням задає `COMPOSE_PARALLEL_LIMIT=1`.

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
| `CORE_BIND`, `ADMIN_BIND`, `APP_BIND` | Host interface для published ports. Використовуйте `127.0.0.1` за reverse proxy. |
| `CORE_PORT`, `ADMIN_PORT`, `APP_PORT` | Published host ports. |
| `PUBLIC_CORE_URL` | Публічний API URL для admin, app, cookies і uploaded file URLs. |
| `APP_PUBLIC_URL` | Публічний URL вітрини для storefront build/runtime. |
| `CORE_NODE_ENV` | Runtime mode backend. Залишайте `development` для plain HTTP cookie testing. |
| `MONGO_DATA_PATH` | MongoDB data directory на Linux host. За замовчуванням: `/var/lib/voidly/mongo`. |
| `MONGO_USERNAME`, `MONGO_PASSWORD`, `MONGO_DATABASE` | MongoDB credentials і database name. |
| `INITIAL_USER_USERNAME`, `INITIAL_USER_PASSWORD` | Початковий admin account, який створюється на першому startup, якщо відсутній. |
| `SERVER_JWT_SECRET`, `CLIENT_JWT_SECRET` | JWT signing secrets. |
| `PASSWORD_SALT_ROUNDS` | bcrypt password hashing cost. |
| `CLIENT_TOKEN_MAX_AGE_HRS`, `USER_TOKEN_MAX_AGE_HRS` | Cookie/JWT lifetime values. |
| `USER_TOKEN_COOKIE`, `CLIENT_TOKEN_COOKIE` | Cookie names для admin і customer auth flows. |

## HTTPS І Reverse Proxy

Для прямого HTTP testing залишайте:

```env
CORE_NODE_ENV=development
PUBLIC_CORE_URL=http://YOUR_IP:3000
APP_PUBLIC_URL=http://YOUR_IP:3002
```

У production mode auth cookies мають прапорець `Secure`. Вони не працюватимуть через plain HTTP. Після встановлення TLS reverse proxy перед сервісами використовуйте HTTPS URLs:

```env
PUBLIC_CORE_URL=https://api.example.com
APP_PUBLIC_URL=https://example.com
CORE_NODE_ENV=production
```

Якщо reverse proxy працює на тому самому host, прив'яжіть сервіси до localhost:

```env
CORE_BIND=127.0.0.1
ADMIN_BIND=127.0.0.1
APP_BIND=127.0.0.1
```

Після цього перебудуйте і перезапустіть сервіси, які використовують ці значення:

```sh
sh deploy.sh up core admin app
```

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

Додайте swap на малих VPS:

```sh
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Оновлення

Оновіть stack і submodules:

```sh
git pull --recurse-submodules
git submodule update --init --recursive
```

Перебудуйте змінені сервіси:

```sh
sh deploy.sh build core
sh deploy.sh restart core
```

Для frontend changes або зміни public URLs:

```sh
sh deploy.sh up admin app
```

MongoDB data і Docker volumes зберігаються між rebuilds і restarts.

## Дані Та Volumes

| Storage | Вміст |
| --- | --- |
| `MONGO_DATA_PATH` (`/var/lib/voidly/mongo` за замовчуванням) | Файли бази даних MongoDB на Linux host. |
| `voidly_core_uploads` | Uploaded files, які API віддає на `/uploads`. |

`sh deploy.sh down` видаляє containers, але залишає Docker volumes. MongoDB зберігається поза Docker volumes, тому `docker compose down -v`, `docker volume prune` і `docker volume rm` не видаляють файли бази даних. Щоб видалити MongoDB data, видаліть `MONGO_DATA_PATH` явно і лише після backup.

## Troubleshooting

Якщо browser не може підключитися до API, перевірте `PUBLIC_CORE_URL`, firewall rules і health статус `core`:

```sh
sh deploy.sh ps
sh deploy.sh logs core
```

Якщо зображення не завантажуються, перевірте, що `LOCAL_STORAGE_BASE_URL` всередині `core` відповідає публічному API URL. У stack це значення береться з `PUBLIC_CORE_URL`.

Якщо admin або storefront досі використовує старий API URL, перебудуйте frontend services:

```sh
sh deploy.sh up admin app
```

Якщо authentication працює локально, але ламається після переходу в production mode, переконайтесь, що API доступний через HTTPS і `PUBLIC_CORE_URL` починається з `https://`.
