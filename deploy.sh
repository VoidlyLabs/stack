#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT_DIR"

# Keep Compose from building/pulling several heavy Node services at once on small VPSes.
export COMPOSE_PARALLEL_LIMIT="${COMPOSE_PARALLEL_LIMIT:-1}"

compose() {
  docker compose --env-file .env -f compose.yaml "$@"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed. On Ubuntu run: sudo sh scripts/ubuntu-prepare.sh"
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin is not installed. On Ubuntu run: sudo sh scripts/ubuntu-prepare.sh"
    exit 1
  fi
}

secret() {
  openssl rand -hex 32
}

ensure_env() {
  if [ ! -f .env ]; then
    if [ ! -f .env.example ]; then
      echo "Error: .env.example not found in $(pwd)"
      exit 1
    fi
    cp .env.example .env
    mongo_secret=$(secret)
    server_secret=$(secret)
    client_secret=$(secret)
    tmp_file=$(mktemp)
    initial_password=$(secret)
    if ! awk \
      -v mongo_secret="$mongo_secret" \
      -v server_secret="$server_secret" \
      -v client_secret="$client_secret" \
      -v initial_password="$initial_password" \
      '{
        gsub("change-me-mongo-password", mongo_secret);
        gsub("change-me-server-jwt-secret", server_secret);
        gsub("change-me-client-jwt-secret", client_secret);
        gsub("change-me-initial-password", initial_password);
        print;
      }' .env > "$tmp_file"; then
      echo "Error: Failed to generate .env file"
      rm -f "$tmp_file"
      exit 1
    fi
    if ! mv "$tmp_file" .env; then
      echo "Error: Failed to move .env file"
      rm -f "$tmp_file"
      exit 1
    fi
    echo "Created .env with generated secrets. Edit PUBLIC_CORE_URL and APP_PUBLIC_URL before testing from a browser."
  fi
}

warn_if_default_public_url() {
  if grep -Eq '^(PUBLIC_CORE_URL|ADMIN_PUBLIC_URL|APP_PUBLIC_URL)=http://SERVER_IP:' .env; then
    echo "Warning: .env still contains SERVER_IP placeholders. Replace them with your VPS IP or domain."
  fi
}

env_value() {
  name="$1"
  awk -F= -v name="$name" '
    $1 == name {
      value = substr($0, index($0, "=") + 1)
      gsub(/\r$/, "", value)
      print value
      exit
    }
  ' .env
}

ensure_data_dirs() {
  mongo_data_path=$(env_value MONGO_DATA_PATH)
  mongo_data_path=${mongo_data_path:-/var/lib/voidly/mongo}

  if [ ! -d "$mongo_data_path" ]; then
    if ! mkdir -p "$mongo_data_path"; then
      echo "Error: Cannot create MongoDB data directory: $mongo_data_path"
      echo "Create it manually with proper permissions or set MONGO_DATA_PATH in .env."
      exit 1
    fi
  fi
}

build_one() {
  service="$1"
  echo "Building $service..."
  compose build "$service"
}

build_services() {
  if [ "$#" -gt 0 ]; then
    for service in "$@"; do
      build_one "$service"
    done
  else
    build_one core
    build_one admin
    build_one app
  fi
}

up_all() {
  echo "Starting mongo..."
  compose up -d mongo

  build_one core
  echo "Starting core..."
  compose up -d core

  build_one admin
  echo "Starting admin..."
  compose up -d admin

  build_one app
  echo "Starting app..."
  compose up -d app

  compose ps
}

cmd="${1:-up}"
if [ $# -gt 0 ]; then shift; fi
require_docker
ensure_env

case "$cmd" in
  init)
    warn_if_default_public_url
    ;;
  up)
    warn_if_default_public_url
    ensure_data_dirs
    if [ "$#" -gt 0 ]; then
      build_services "$@"
      compose up -d "$@"
    else
      up_all
    fi
    ;;
  down)
    compose down "$@"
    ;;
  restart)
    compose restart "$@"
    ;;
  logs)
    compose logs -f "$@"
    ;;
  ps)
    compose ps "$@"
    ;;
  build)
    warn_if_default_public_url
    build_services "$@"
    ;;
  pull)
    compose pull "$@"
    ;;
  config)
    compose config "$@"
    ;;
  *)
    echo "Usage: sh deploy.sh [init|up|down|restart|logs|ps|build|pull|config] [service...]"
    exit 2
    ;;
esac
