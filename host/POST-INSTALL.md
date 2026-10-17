# Post-install notes (Grok Build and operators)

This file is the tribal knowledge from the QOGE OpenCEX development install that is easy to miss in `README.md` and source. **Read it before SSH, before `./opencex.sh`, and again after the wizard.** A later Grok Build on a new VPS should treat this as required reading.

The development instance that produced these notes is `exchange.qoge.org`. That box is **not** a production template. Copy procedures, never its secrets, cold address, or compose file.

QOGE GitHub `master` already contains the numbered code patches (Codex C-01–C-15, Claude C-01–I-06) and the installer/host pieces for ops O-01–O-08. A new host still needs the **host overlays** below; `opencex.sh` does not install firewall, SSH allowlist, backups, or health cron by itself.

## Standing rules

- Keep secrets on the server. Never print or paste into chat: admin passwords, RPC passwords, GitHub PATs, TOTP secrets, `CRYPTO_KEY`, WIF, `.env`, `docker-compose.yml`, dump contents, keeper JSON.
- Independent code auditors get GitHub clones only. They do not get VPS SSH.
- Probe staff with a throwaway user, then delete it. Leave the live admin password unused in chat.
- No Go rewrite. Skip Hummingbot unless the operator asks (`IS_HUMMINGBOT_ENABLED=False`).
- A later OPEX evaluation belongs on a **separate** VPS. Never replace a running OpenCEX host with OPEX.
- Chart open-order lines were abandoned; do not iterate on them.
- Vue files: `npx --yes prettier@2.6.2 --write <file>` (project `yarn prettier` is often missing).
- Git author for this fork: `QOGE <iondns@gmail.com>`. Remotes are `github.com/QOGE/<repo>`, `master` only.

## Before `./opencex.sh`

### Hardware and DNS

- README minimum is 16 GiB RAM. An 8 GiB box only survives with an 8 GiB swapfile (`/swapfile` in fstab). On 8 GiB, build `frontend` and `nuxt` **one at a time**.
- Ubuntu 24.04 works. Caddy needs host ports 80 and 443 free.
- Point the DNS A record at the VPS before install so Caddy can obtain TLS.

### Bump installer pins

`opencex.sh` clones backend/frontend/static/admin at the `*_COMMIT` SHAs at the top of the script (detached HEAD). Those pins lag GitHub `master` unless someone just bumped them. **Before a new install**, set them to current `origin/master` of each QOGE repo, or export:

```bash
BACKEND_COMMIT=$(git ls-remote https://github.com/QOGE/OpenCEX-backend.git refs/heads/master | cut -f1)
FRONTEND_COMMIT=$(git ls-remote https://github.com/QOGE/OpenCEX-frontend.git refs/heads/master | cut -f1)
STATIC_COMMIT=$(git ls-remote https://github.com/QOGE/OpenCEX-static.git refs/heads/master | cut -f1)
ADMIN_COMMIT=$(git ls-remote https://github.com/QOGE/OpenCEX-JS-admin.git refs/heads/master | cut -f1)
```

After install, point each checkout at `origin` `https://github.com/QOGE/<repo>.git` and a real `master` branch (`git checkout master` after a detached clone). Admin in particular used to stay on Polygant `origin`; retarget it immediately.

### Qogecoin Core on the host

QOGE is **not** a compose service. Start (or be ready to start) a host daemon before workers can process deposits.

- RPC **8332** on loopback plus Docker bridges (`172.17.0.1`, `172.18.0.1`). Never on the public IP.
- P2P **42069** public when `listen=1`.
- `rpcallowip` must include `127.0.0.1` and `172.16.0.0/12`.
- Watch-only wallet named `opencex` (`disable_private_keys=true`). Descriptor nodes use `importdescriptors` `addr()`; `importaddress` fails with `-4`.
- `QOGE_ADDRESS_LEGACY=True` yields P2PKH `q…` deposit addresses. Cold address is a legacy `q…` you control.
- CLI is often **not on PATH**: `/root/qogecoin/src/qogecoin-cli -conf=/root/.qogecoin/qogecoin.conf`.
- If `qogecoind` starts **before** Docker creates `docker0`/`br-*`, `rpcbind` on `172.17.0.1` silently fails and only `127.0.0.1:8332` listens. Containers use `host.docker.internal` → **`172.17.0.1` even when the worker sits on the Caddy network `172.18.0.0/16`**. systemd: `After=docker.service` and an ExecStartPre that waits for `docker0`.
- Host INPUT policy DROP without a **new-connection** rule `172.16.0.0/12` → TCP 8332 is the O-01 failure mode: Docker looks fine, QOGE cursor stalls thousands of blocks. `host/opencex-apply-firewall.sh` already has that rule.
- **Never** `UPDATE cryptocoins_lastprocessedblock` by hand. QOGE is currency **21**. Confirmations **N=6**, so a gap of about 5 is healthy.

Installer writes a **random** `QOGE_NODE_PASS` into `.env` and sets `QOGE_NODE_USER=opencex`, `QOGE_NODE_HOST=host.docker.internal`. After `.env` exists, copy those values into `qogecoin.conf` (`rpcuser` / `rpcpassword`) and restart the daemon once Docker is up. A TCP connect with HTTP 401 still means the passwords differ.

### Credentials to have in hand

- reCAPTCHA v2 Invisible site + secret.
- SMTP: the installer has `EMAIL_USE_TLS` only. Use port **587 + TLS**. Port 465/SSL has no mapping.
- Infura key+secret, Etherscan key (ETH).
- Your **own** QOGE cold `q…` and ETH `0x`. Optional BNB/TRX cold addresses if those chains are enabled.
- `QOGE_SAFE_ADDR` has **no** default. An earlier installer default was a development cold wallet; never reuse it.

Skip Telegram, Hummingbot, Twilio, Sumsub, Scorechain, Polygon unless asked. BNB (BEP-20 USDT) is the usual extra chain.

## Installer traps

`opencex.sh` is twelve `read` steps plus `y/n`. It needs a TTY. `docker exec` is without `-it`; `collectstatic` is `--noinput`. Feed answers from a file only if every prompt line is present (a short file aborts mid-run).

- `.env` is created **only when `/app/opencex/backend/.env` is missing**. A partial tree blocks re-entry of the questionnaire. Move `.env` aside to re-prompt; deleting it on a live DB is a custody event.
- `docker-compose.yml` is kept if present. `FORCE_COMPOSE=1` overwrites it. **Never** set that on a host that already has `postgresql_data`.
- **Never rerun** `./opencex.sh` against an existing database. `/app/deploy` is the installer checkout; `git merge --ff-only` new installer commits, then stop.
- Clean retry (`compose down`, `rm -rf /app`, `docker system prune -a`) destroys the ledger.
- `ADMIN_USER` prompt says email (`admin@exchange.net`). Whatever you type becomes the staff username. Length-5 `admin` works.
- **`ADMIN_MASTERPASS` is not the admin login password.** It authorizes staff balance credit/debit. Wizard writes a **random** login password into `.handoff`.
- `postgres:14` is required. `postgres:latest` (PG 18) crash-loops on `./postgresql_data`.
- `CRYPTO_KEY` is 32 chars; **never rotate** it on an existing database (every encrypted wallet key becomes unreadable).
- `SECRET_KEY` is 64 chars from `.env`. Rotating it invalidates JWTs.
- Empty RabbitMQ Caddy labels used to break TLS. RabbitMQ stays on the docker network; management `15672` is an SSH tunnel, never published.
- Alertbot / `plgdev.com` POST is gone. Leave it gone.
- Compose contains DB/AMQP secrets. `chmod 600` the file. Never `cat` it into a transcript.

## Right after the wizard

1. Copy `/app/opencex/backend/.handoff/` (mode 600) **off the host**, then delete the copies under `/app`. That directory holds keeper OWNER/MANAGER shares, the generated admin password, bot password, and TOTP secret when present. Historical `save_to_self_and_delete*.txt` and `/root/qoge-keeper-*.txt` go to `/root/opencex-custody/` (dir 0700, files 0600). Do not open them in chat. Do not copy them back into `/app`.
2. If GasKeeper wrap wrote `.handoff/gas_keeper_password`, **leave that file** (mode 600). Unwrap reads `KEEPER_HANDOFF_DIR` or `BASE_DIR/.handoff`. Copy the wrap JSON off-host; keep the password file for the running process. Restart gas / accumulation / celery / block workers after a wrap so in-process caches reload.
3. Sync `qogecoin.conf` with `.env` `QOGE_NODE_*`. Restart `qogecoind` after Docker. Confirm from the worker:

   ```bash
   docker exec opencex-qoge python -c "import socket; s=socket.socket(); s.settimeout(4); s.connect(('host.docker.internal',8332)); s.close(); print('tcp_ok')"
   ```

4. `ENABLE_OTP_ADMIN` must stay **True** in `exchange/settings/admin.py` (committed value). Setting it False to “debug login” was live drift (O-03). First `POST /apiadmin/login/` does **not** mint a QR. Provision with `manage.py provision_admin_otp <username>` or the wizard handoff. `/apiadmin/token/` is 403; staff JWT must come from `/apiadmin/login/` with `otp_verified`.
5. Install host overlays from this directory (see checklist below).
6. Frontend `src/local_config` is gitignored. Installer `envsubst`s it once from `example.local_config.js`. Later git pulls will not refresh API URLs. Confirm they are `https://<DOMAIN>`.
7. `tokens.json` is gitignored; if present keep it `{}` mode 600.
8. Create the watch-only RPC wallet `opencex` if wizard did not.

## Host overlays to copy (O-01, O-04–O-08)

`opencex.sh` does not install these. Copy from `host/` on a new box:

| Install as | Source |
| --- | --- |
| `/usr/local/sbin/opencex-apply-firewall.sh` | `opencex-apply-firewall.sh` |
| `/etc/systemd/system/opencex-ssh-allow.service` | `opencex-ssh-allow.service` |
| `/etc/ssh/sshd_config.d/00-opencex-ssh.conf` | `00-opencex-ssh.conf` |
| `/etc/opencex/ssh-allow.ipv4` | `ssh-allow.ipv4.example` (your `/32` only) |
| `/etc/opencex/nginx-admin-allow.conf` | generated by the firewall script |
| `/usr/local/sbin/opencex-backup.sh` + `/etc/cron.d/opencex-backup` | `opencex-backup.sh` at 03:15 UTC |
| `/usr/local/sbin/opencex-health.sh` + `/etc/cron.d/opencex-health` | `opencex-health.sh` / `opencex-health.cron` |

Also mount `frontend/default.conf` into the frontend container (`/admin` + `include /etc/nginx/admin-allow.conf`). Recreating frontend without that mount opens `/admin` and `/apiadmin` to the world.

Firewall notes:

- Write your operator IPv4 into `ssh-allow.ipv4` **before** applying INPUT DROP. Provider console is lockout recovery.
- Residential IPs move. Use a `/32`, never a wide ISP range. Keep IPv6 SSH dropped until you have a stable prefix.
- Leave UFW inactive (it fights Docker).
- Public TCP: 80, 443, QOGE P2P 42069, allowlisted 22. RPC 8332, Postgres, Redis, RabbitMQ, Caddy admin 2019 stay closed from the internet.
- The script also allows Docker-bridge 8332. That rule is load-bearing for deposits.
- sshd: key-only, `PermitRootLogin prohibit-password`.
- Do not add FTP or a chroot SFTP into the live Nuxt tree. Temporary transfer accounts were an audit finding (O-04).

Compose hardening the installer now emits (confirm after first `up`):

- Redis `user: "999:999"`, data dir mode 700. A custom `command: redis-server` makes Redis root again; leave the official image entrypoint.
- Frontend volumes: **only** `staticfiles` and `media` `:ro`. Mounting the whole backend tree exposes `.env`.
- Caddy talks to `tecnativa/docker-socket-proxy` with `POST=0`. A `:ro` docker.sock mount does **not** make the Docker API read-only. Do not publish proxy port 2375 on the host.

## Custody and money flow

- This is a **custodial ledger**. The UI balance is the database. Coins sit on deposit addresses, then sweep to cold or keeper.
- QOGE deposits credit after 6 confirmations, then accumulation. Empty `keeper_accumulation` limit sends almost everything to cold and starves withdrawals. Set keeper accumulation to a few days of expected payouts.
- QOGE keeper is **2-of-3**. SITE is CRYPTO_KEY-encrypted in the DB. Admin “Process withdrawals” needs OWNER or MANAGER compressed WIF (**52 characters starting with E**). SITE, the keeper address, `ADMIN_MASTERPASS`, and the Django login password all fail that serializer.
- GasKeeper needs a little **native** gas (BNB/ETH/TRX) before token sweeps. Fund the GasKeeper, not the cold address.
- `BNB_SAFE_ADDR` / `ETH_SAFE_ADDR` are public receive addresses. The exchange does not hold those keys.
- EVM/TRX `withdraw_coin` still broadcasts then saves (known leftover). QOGE/BTC payouts persist hex then broadcast.
- `create_new_wallet/` queues on Celery `qoge` and waits ~30s for `importdescriptors`. UI failures can look like a no-op.
- Matcher `UserFee` defaults are still 0.001/0.002 unless changed in the DB. The SPA fees page showing 0% is display-only.

**Do not take outside deposits** until: worker TCP/RPC to 8332 works, `LastProcessedBlock` for currency 21 is catching up on its own, admin OTP is on, handoff files are off the web tree, firewall and admin allowlist are in place, and a controlled operator deposit has credited.

## Day-2 operations that repeatedly bite

### Docker

- Recreating **gunicorn** (`opencex`): wait until `https://<DOMAIN>/api/public/v1/ticker` is 200. In-container HTTP to `127.0.0.1:8080` needs header `Host: <DOMAIN>` or Django returns 400.
- Recreating gunicorn can 502 admin/nginx until `frontend` / `admin` / `nuxt` restart (stale Docker DNS).
- Recreating **postgresql**: same image **and** the same `postgresql_data` bind. Wait `pg_isready`. Recreating the volume destroys the ledger.
- Skip live **rabbitmq** recreate (Celery workers flap).
- Healthchecks require a container recreate. Cursor stall is **only** in `opencex-health.sh` (fail if gap > 50 **and** the cursor did not move).
- Application images stay locally built `:latest`. Python packages live in the image; backend source is bind-mounted at `/app`. A Django bump needs an image rebuild or a layered `pip install`, then recreate app containers. Leave Postgres alone.
- If someone pulled `redis:latest` onto a live box, the RDB may be Redis 8. Installer still uses `redis:7.0.4` for **new** installs. Never point a Redis 8 volume at 7.0.4.
- `docker exec` without `-i`. Prefer `python -c`. `python /tmp/script.py` puts `/tmp` on `sys.path`; use `PYTHONPATH=/app`.
- `django.setup()` in cron prints web3 init noise. Health uses `qogecoin-cli` + `psql`.
- `extra_hosts: host.docker.internal:host-gateway` is required on `opencex`, `opencex-cel`, and `opencex-qoge`.
- `opencex-qoge` runs `qogeworker`. `opencex-cel` excludes the `qoge` queue.
- After a backend pull, restart at least `opencex`, `opencex-wss`, `opencex-stack`, `opencex-cel`, `opencex-qoge`, and the chain workers you actually run. Restart `opencex-stack` after pair changes. `Pair.objects.get_or_create` needs Currency objects, not raw strings.

### Git deploy

```text
commit/push origin master
# on the VPS:
git fetch && git merge --ff-only origin/master
docker restart …   # backend bind-mount
# frontend / nuxt / admin: docker build -t <name> -f deploy/Dockerfile . then compose up -d
```

On 8 GiB RAM, sequential builds only.

Keep gitignored overlays: `frontend/src/local_config`, `frontend/deploy/`, `nuxt/deploy/`, `backend/tokens.json`. `git checkout -- .gitignore` if a pull is blocked by a local ignore edit. Do not `git stash pop` onto `exchange/settings/admin.py`.

### Routing

Caddy reverse-proxies the domain to `frontend:80` only. Frontend nginx:

| Path | Upstream |
| --- | --- |
| `/admin` | `admin:80` (allowlist) |
| `/apiadmin`, `/api` | `opencex:8080` (allowlist on `/apiadmin`) |
| `/wsapi` | `opencex-wss:8000` |
| `/account` | Vue SPA `try_files` |
| `/` | `nuxt:3000` |

`/trade` and `/exchange` 404 at nginx (they are not the SPA). Trading URL is `/account/trade/QOGE-USDT`. New Nuxt image filenames 404 until a `docker build` / generate.

### Backups

Daily `pg_dump -Fc` into `/root/opencex-backups/` (700/600) plus dated `.env` and compose copies. 7-day rotation. Script never touches `/root/opencex-custody/`.

Restore into a **throwaway** `postgres:14 --network none`. Never restore over live `postgresql_data`. Keep one dump off-host.

## Minimum probe after install

- `https://<DOMAIN>/` 200, `/account/` 200, `/api/public/v1/ticker` 200.
- `/admin/` 403 from a non-allowlisted IP; 200 from the operator IP.
- Worker TCP to `host.docker.internal:8332` succeeds; `qogecoin-cli getblockcount` vs `block_id` for currency 21; gap about 5 is fine.
- `ENABLE_OTP_ADMIN` True; missing OTP on `/apiadmin/login/` returns `otp_required` with no access token.
- `/usr/local/sbin/opencex-health.sh` prints `HEALTH_OK`.
- No wizard dumps under `/app` web trees.
- Redis is uid 999; frontend does not mount `/app/opencex/backend` as a whole.

## Known leftovers (only if the operator asks)

App workers still run as root with the backend tree `:rw`. EVM/TRX payouts still send-then-save. Global Celery pickle serializers remain. Python 3.8 / Django 3.2.25 / TradingView CL v21.066 stay until a dedicated upgrade. `BrowsableAPIRenderer` is on. Matcher fees are independent of the SPA 0% table.

See `host/DEPLOYMENT.md` for live image-digest pins on the development box (those digests are **that** host, not a new install).
