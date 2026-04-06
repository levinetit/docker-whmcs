WHMCS Docker Image
==================

Ready to use docker image for WHMCS environment, including MariaDB.

## Features

* PHP 8.2 (required for WHMCS 9.0+)
* ionCube loader ready
* SourceGuardian loader ready
* Nginx server configuration for WHMCS
* MariaDB 11 included in docker-compose stack
* Auto-configuration of `configuration.php` from environment variables
* OPcache disabled (recommended by WHMCS)
* Installed default cron for WHMCS
* Persistent storage via `/config` volume
* Multi-arch image supporting both `x86-64` & `arm64`
* Optional htpasswd protection for `/admin` pages

## Supported Architectures

| Architecture | Available |
| :----: | :----: |
| x86-64 | ✅ |
| arm64 | ✅ |

## Quick Start

```bash
git clone https://github.com/levinetit/docker-whmcs.git
cd docker-whmcs
cp .env.example .env
# Editeaza .env cu datele tale
docker compose pull && docker compose up -d
```

Dupa pornire, mergi la `http://your-domain/install/install.php` pentru setup initial.

## docker-compose (recommended)

```yaml
services:
  db:
    image: mariadb:11
    container_name: whmcs-db
    env_file: .env
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ./db:/var/lib/mysql
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  whmcs:
    image: ghcr.io/levinetit/whmcs:latest
    container_name: whmcs
    env_file: .env
    volumes:
      - ./data:/config
    depends_on:
      db:
        condition: service_healthy
    ports:
      - 8043:80
    restart: unless-stopped
```

## Parameters

| Parameter | Function |
| --- | --- |
| `-p 80` | WHMCS webUI (proxiabil via Nginx/Traefik/Caddy pentru SSL) |
| `-e PUID=1000` | UserID |
| `-e PGID=1000` | GroupID |
| `-e TZ=UTC` | Timezone (ex: `Europe/Bucharest`) |
| `-e WHMCS_LICENSE` | Cheia de licenta WHMCS |
| `-e WHMCS_SERVER_IP` | IP-ul public al serverului (necesar pentru validarea licentei) |
| `-e WHMCS_SERVER_URL` | Domeniul WHMCS (necesar pentru validarea licentei) |
| `-e DB_HOST` | Hostname baza de date (default: `whmcs-db`) |
| `-e DB_PORT` | Port baza de date (default: `3306`) |
| `-e DB_USER` | Username baza de date |
| `-e DB_PASSWORD` | Parola baza de date |
| `-e DB_NAME` | Numele bazei de date (default: `whmcs`) |
| `-e MYSQL_ROOT_PASSWORD` | Parola root MariaDB |
| `-e CC_ENCRYPTION_HASH` | Hash 64 caractere pentru criptarea datelor (generat automat daca lipseste) |
| `-e AUTH_USER` (optional) | Username htpasswd pentru protectia paginii `/admin` |
| `-e AUTH_PASS` (optional) | Parola htpasswd pentru protectia paginii `/admin` |
| `-v ./data:/config` | Locatia datelor WHMCS |
| `-v ./db:/var/lib/mysql` | Locatia datelor MariaDB |

## Reinstalare de la zero

```bash
cd /path/to/whmcs
docker compose down -v   # opreste si sterge volumele
rm -rf data/ db/         # sterge datele
docker compose pull      # trage imaginea noua
docker compose up -d     # porneste din nou
```

## After Install

Dupa finalizarea wizard-ului de instalare, sterge directorul `install` din securitate:

```bash
docker exec whmcs rm -rf /var/www/whmcs/install
```
