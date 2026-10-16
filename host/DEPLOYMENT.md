# Live deployment reconstruction (O-07)

Do **not** rerun `opencex.sh` against an existing database. Do **not** set `FORCE_COMPOSE=1` on a custody host. The installer writes `/app/opencex/docker-compose.yml` with secrets; the live file stays on the host (mode 600 copies under `/root/opencex-backups/`).

## Git checkouts

| Tree | Remote | Notes |
| --- | --- | --- |
| `/app/deploy` | `github.com/QOGE/OpenCEX` | Installer only. Never a substitute for the live compose file. |
| `/app/opencex/backend` | `github.com/QOGE/OpenCEX-backend` | Bind-mounted into app containers. |
| `/app/opencex/frontend` | `github.com/QOGE/OpenCEX-frontend` | Vue SPA. `src/local_config` is host-local (no secrets). |
| `/app/opencex/nuxt` | `github.com/QOGE/OpenCEX-static` | Landing. |
| `/app/opencex/admin` | `github.com/QOGE/OpenCEX-JS-admin` | Staff UI. |

`ENABLE_OTP_ADMIN` must stay **True** in `exchange/settings/admin.py` (committed value).

## Pinned infrastructure images (live)

These are the images that were running when tags were pinned. Redis is **8.10.2**; do not replace it with installer `redis:7.0.4` (RDB would not load).

| Service | Pin |
| --- | --- |
| redis | `redis@sha256:718f745deb7dfefeac6eed7041fc7ec9476b50e61b247932682457c41adafa0e` |
| caddy | `lucaslorentz/caddy-docker-proxy@sha256:4c14f2ddb9c259903c464ac0423c936b10757bda7c57f8eb34b93efa903c8b8d` |
| docker-socket-proxy | `tecnativa/docker-socket-proxy@sha256:9e4b9e7517a6b660f2cc903a19b257b1852d5b3344794e3ea334ff00ae677ac2` |
| postgresql | `postgres@sha256:816cf7d06ec33116c8f54cf14197085be89f25291686229485ee7d53a785b901` (do not recreate the volume) |
| rabbitmq | `rabbitmq@sha256:93fa1d9f5ad2e77ec2e36c6115186c378a86be7dbfbb143cbeb2226b51c8284d` |

Application images (`opencex`, `frontend`, `nuxt`, `admin`) are built locally and stay `:latest` on this box.

New installs from `opencex.sh` still use `postgres:14`, `redis:7.0.4`, `rabbitmq:3.9.22-management`, `lucaslorentz/caddy-docker-proxy:2.13.1`.

## Host files

| Live path | This repo |
| --- | --- |
| `/usr/local/sbin/opencex-apply-firewall.sh` | `host/opencex-apply-firewall.sh` |
| `/etc/systemd/system/opencex-ssh-allow.service` | `host/opencex-ssh-allow.service` |
| `/etc/ssh/sshd_config.d/00-opencex-ssh.conf` | `host/00-opencex-ssh.conf` |
| `/etc/opencex/ssh-allow.ipv4` | `host/ssh-allow.ipv4.example` |
| `/etc/opencex/nginx-admin-allow.conf` | `host/nginx-admin-allow.conf.example` |
| `/usr/local/sbin/opencex-backup.sh` | `host/opencex-backup.sh` |
| frontend nginx overlay | `frontend/default.conf` (`/admin` + `admin-allow.conf`) |

## Overlays that stay host-local

- `/app/opencex/docker-compose.yml` (secrets)
- `/app/opencex/backend/.env` (secrets)
- `/app/opencex/frontend/src/local_config` (site URLs; see `OpenCEX-frontend/src/example.local_config.js`)
- `/root/opencex-custody/` and `/root/opencex-backups/` (mode 700)
