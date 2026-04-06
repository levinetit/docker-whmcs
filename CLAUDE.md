# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build imagine locala (amd64 only, fara push)
docker buildx bake image-local

# Build cu versiune PHP specifica
docker buildx bake image-local --set image.args.PHP_RELEASE=8.2

# Build si push multi-platform (amd64 + arm64) pe GHCR
docker buildx bake publish

# Build cu versiune WHMCS specifica (default: auto-detect latest stable)
docker buildx bake image-local --set image.args.WHMCS_RELEASE=8.13.0
```

## Arhitectura

### Flux de build
1. **Dockerfile** — construieste imaginea bazata pe `lscr.io/linuxserver/baseimage-ubuntu:noble` (s6-overlay init system)
2. **docker-bake.hcl** — defineste targete de build: `image-local` (test local) si `publish` (multi-platform amd64+arm64)
3. **GitHub Actions** (`.github/workflows/build.yml`) — triggerat la push pe `main` sau tag `v*`; foloseste GHA cache pentru build-uri rapide dupa prima rulare

### Structura `root/` → copiata in `/` in container
```
root/
├── defaults/                    # Fisiere default copiate in /config/ la primul start
│   ├── cron/whmcs               # Crontab WHMCS (rulat ca abc user via s6-setuidgid)
│   ├── fpm/{90-default.conf, 95-www.conf}
│   ├── nginx/
│   │   ├── nginx.conf           # Config global nginx (user abc, include sites-enabled/*)
│   │   ├── conf.d/{php,admin-auth,admin-noauth}
│   │   └── sites-available/whmcs  # Vhost principal WHMCS
│   └── php/90-default.ini       # PHP: memory 512M, upload 25M, opcache
└── etc/
    ├── cont-init.d/             # Scripturi init s6, rulate in ordine numerica
    │   ├── 40-php               # Copiaza configs FPM din defaults/ → /config/ → /etc/php/
    │   ├── 50-nginx             # Injecteaza WHMCS_SERVER_IP/URL, configureaza htpasswd
    │   ├── 60-whmcs             # Extrage WHMCS zip, seteaza symlink-uri, permisiuni
    │   └── 70-cron              # Configureaza crontab din /config/crontabs/
    ├── cont-finish.d/60-whmcs   # La oprire: backup configuration.php → /config/whmcs/
    └── services.d/{cron,nginx,php-fpm}/run  # Procese supervizate de s6
```

### Logica init container (ordinea conteaza)
- `40-php`: copiaza `defaults/php/*` si `defaults/fpm/*` in `/etc/php/${PHP_VERSION}/`; creeaza `/config/php/99-local.ini` si `/config/fpm/99-local.conf` pentru override-uri user
- `50-nginx`: injecteaza `WHMCS_SERVER_IP` in `conf.d/php` (fastcgi_param SERVER_ADDR); injecteaza `WHMCS_SERVER_URL` in `sites-available/whmcs`; daca `AUTH_USER`/`AUTH_PASS` sunt setate → genereaza `.htpasswd` si activeaza `admin-auth`, altfel `admin-noauth`
- `60-whmcs`: extrage `/whmcs/whmcs.zip` (baked in imagine) in `/config/www/whmcs` doar daca `index.php` nu exista; sincronizeaza `configuration.php` intre `/config/whmcs/` si `/config/www/whmcs/`
- `70-cron`: copiaza crontab din `/config/crontabs/whmcs` → `/etc/cron.d/whmcs`; suporta si `/config/crontabs/root` pentru cron-uri custom root

### Volum persistent `/config`
```
/config/
├── whmcs/configuration.php      # Config WHMCS (backup automat la oprire)
├── www/whmcs/                   # Fisierele WHMCS (symlink ← /var/www/whmcs)
├── www/whmcs_storage/           # Storage WHMCS (symlink ← /var/www/whmcs_storage)
├── nginx/                       # Config nginx editabila de user
├── php/99-local.ini             # Override php.ini
├── fpm/99-local.conf            # Override php-fpm pool
└── crontabs/whmcs               # Crontab editabil
```

### PHP Loaders (baked in imagine, nu downloadate la runtime)
- **ionCube**: `/usr/lib/php/ioncube/ioncube_loader_lin_${PHP_VERSION}.so`
- **SourceGuardian**: `/usr/lib/php/sourceguardian/ixed.${PHP_VERSION}.lin`
- Ambele activate via symlink in `fpm/conf.d/` si `cli/conf.d/`

## Variabile de mediu

| Variabila | Obligatorie | Descriere |
|-----------|-------------|-----------|
| `WHMCS_SERVER_IP` | DA | IP public host Docker (validare licenta WHMCS) |
| `WHMCS_SERVER_URL` | DA | Domeniu WHMCS (ex: `whmcs.example.com`) |
| `AUTH_USER` / `AUTH_PASS` | Nu | Protejeaza `/admin` cu htpasswd (bcrypt) |
| `PUID` / `PGID` | Nu | User/group ID (default 1000) |
| `TZ` | Nu | Timezone (default UTC) |

## Customizare dupa start

- **PHP**: editeaza `/config/php/99-local.ini` → restart container
- **PHP-FPM pool**: editeaza `/config/fpm/99-local.conf` → restart container
- **Nginx vhost**: editeaza `/config/nginx/sites-available/whmcs` → `docker exec whmcs nginx -s reload`
- **Crontab**: editeaza `/config/crontabs/whmcs` → restart container
- **Cron custom root**: creeaza `/config/crontabs/root`

## Versiuni suportate

- PHP: **8.2** (default), compatibil si cu 8.3
- WHMCS: **9.0+** (necesita PHP 8.2+); versiunea se auto-detecteaza din API la build daca `WHMCS_RELEASE` e gol
- Arhitecturi: `linux/amd64`, `linux/arm64`
