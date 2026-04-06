# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build multi-platform image locally (amd64 + arm64)
docker buildx bake image-local --set image.args.PHP_RELEASE=8.2

# Build and push to GHCR (requires login)
docker buildx bake publish --set image.args.PHP_RELEASE=8.2

# Test locally with docker compose
cp .env.example .env
docker compose up -d

# Verify PHP version inside container
docker exec whmcs php -v

# Check ionCube and SourceGuardian loaders
docker exec whmcs php -m | grep -E 'ionCube|SourceGuardian'
```

## Architecture

This is a **single Docker image** (`ghcr.io/levinetit/whmcs`) that bundles:
- **Nginx** (from `ppa:ondrej/nginx`, package `nginx-full` — required for `sites-available/sites-enabled` structure used by init scripts)
- **PHP 8.2-FPM** (from `ppa:ondrej/php`)
- **ionCube Loader** + **SourceGuardian** (Zend extensions loaded at PHP startup)
- **WHMCS** zip downloaded at build time to `/whmcs/whmcs.zip` (extracted at runtime)

Base image: `lscr.io/linuxserver/baseimage-ubuntu:noble` — uses the linuxserver.io lifecycle:
- `root/etc/cont-init.d/` — startup scripts (numbered, run in order): `40-php`, `50-nginx`, `60-whmcs`, `70-cron`
- `root/etc/services.d/` — supervised services: `nginx`, `php-fpm`, `cron`
- `root/etc/cont-finish.d/` — shutdown scripts
- `root/defaults/` — default config files copied to `/config` on first run

## Key Design Patterns

**Persistent storage via `/config` volume:**
- `/config/whmcs/configuration.php` — WHMCS config (auto-generated from env vars if `DB_HOST` is set)
- `/config/www/whmcs/` — WHMCS web root (symlinked to `/var/www/whmcs`)
- `/config/www/whmcs_storage/` — writable dirs: `templates_c`, `attachments`, `downloads` (symlinked to `/var/www/whmcs_storage`)

**Auto-configuration** (`root/etc/cont-init.d/60-whmcs`): if `DB_HOST` env var is set and `configuration.php` doesn't exist, it's generated automatically. `CC_ENCRYPTION_HASH` is auto-generated if not provided.

**PHP config:** `root/defaults/php/90-default.ini` is applied to both FPM and CLI. OPcache is intentionally disabled (WHMCS requirement).

**Nginx admin block:** `root/defaults/nginx/conf.d/admin` — symlinked from either `admin-auth` (htpasswd) or `admin-noauth` by the `50-nginx` init script based on `AUTH_USER`/`AUTH_PASS` env vars.

## Critical Constraints

- **PHP version**: Must stay at **8.2** — WHMCS 9.0 requires 8.2+; ionCube/SourceGuardian loader files are version-specific (`ixed.8.2.lin`, `ioncube_loader_lin_8.2.so`)
- **nginx package**: Must use `nginx-full` from `ppa:ondrej/nginx` — the official nginx.org package lacks `sites-available/sites-enabled` and is missing features the init scripts depend on
- **MariaDB**: Deploy with `conf/mariadb.cnf` to disable strict `sql_mode` (`NO_ENGINE_SUBSTITUTION`) and set `utf8mb4` charset — WHMCS is incompatible with MySQL strict mode
- **OPcache**: Keep `opcache.enable = 0` in PHP ini — WHMCS explicitly requires OPcache disabled
- **Secrets**: Do NOT add `ENV` instructions for `AUTH_USER`, `AUTH_PASS`, or any credentials — pass via `env_file` at runtime only

## CI/CD

`.github/workflows/build.yml` — triggers on push to `main` or version tags (`v*`). Uses `docker/bake-action` with `docker-bake.hcl`. GHA cache (`type=gha`) is configured for faster rebuilds. The `publish` target in `docker-bake.hcl` builds both `linux/amd64` and `linux/arm64`.

Skip CI for a commit by including `[ci-skip]` in the commit message.
