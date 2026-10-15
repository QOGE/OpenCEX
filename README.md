<p align="center">
  <img alt="OpenCEX Logo" width="500" src="https://github.com/QOGE/OpenCEX/blob/master/logo.png">
</p>

<p align="center">
OpenCEX is a free and open source cryptocurrency exchange platform.<br>
This is the <strong>QOGE fork</strong> of unmaintained Polygant OpenCEX.
</p>

> [!NOTE]
> Installer clones backend, frontend, static, and admin from `github.com/QOGE/...` (`master` only).
> Live instance: [https://exchange.qoge.org](https://exchange.qoge.org).

> [!CAUTION]
> Upstream Polygant OpenCEX is not maintained. The original code is provided as-is under Apache License 2.0.

## Markets

**Bitcoin (BTC) is not supported.** The installer leaves `COMMON_TASKS_BTC=False`, does not run bitcoind, and does not ask for a BTC cold address.

Listed markets on this fork:

| Pair | Quote | Notes |
| --- | --- | --- |
| **QOGE-USDT** | USDT | The only USDT market. Default trade pair. |
| **ETH-QOGE** | QOGE | Inverted: price is QOGE per ETH. |
| **TRX-QOGE** | QOGE | Inverted: price is QOGE per TRX. |
| **BNB-QOGE** | QOGE | Inverted: price is QOGE per BNB. |

ETH, TRX, and BNB are quoted in QOGE. There is no ETH-USDT, TRX-USDT, BNB-USDT, or BTC-* book on this listing.

## Main features

- Custodial wallets for **QOGE**, ETH, BNB, TRX, and USDT (ERC-20, BEP-20, TRC-20). Deposit and withdrawal.
- QOGE custody talks to a **host Qogecoin Core** daemon (RPC 8332). The node is not a compose service.
- Order matching engine for the pairs above.
- Professional exchange interface for placing orders.
- Simplified interface for quick swap.
- KYT transaction verification (requires Scorechain keys).
- KYC verification of users (requires Sumsub keys).
- SMS 2FA for users (requires Twilio keys).

Staff console is the Vue app at `/admin/`, talking to `/apiadmin/`. Django contrib admin is not mounted.

## System requirements

<table>
<tr>
<td><b>Minimum</b></td>
<td><b>Recommended</b></td>
</tr>
<tr>
<td>CPU: 4 cores<br>RAM: 16 GB<br>Disks: 40 GB plus QOGE chain data on the host<br>OS: Ubuntu 22.04 or 24.04<br><br><a href="https://www.hetzner.com/cloud" target="_blank">https://www.hetzner.com/cloud</a></td>
<td>CPU: 8 cores<br>RAM: 64 GB<br>Disks: 2x1Tb NVMe SSD<br>OS: Ubuntu 22.04 or 24.04<br><br><a href="https://www.hetzner.com/dedicated-rootserver/ax51-nvme" target="_blank">https://www.hetzner.com/dedicated-rootserver/ax51-nvme</a></td>
</tr>
</table>

## The software used.

<table>
<tr><td>Docker</td><td>CE (installer-pinned compose images)</td><td>OS-level virtualization</td></tr>
<tr><td>NGINX</td><td>1.26.3-alpine</td><td>Web server (frontend/admin images)</td></tr>
<tr><td>Caddy</td><td>lucaslorentz/caddy-docker-proxy:2.13.1</td><td>TLS reverse proxy</td></tr>
<tr><td>Postgres</td><td>14</td><td>RDBMS (do not use postgres:latest)</td></tr>
<tr><td>Redis server</td><td>7.0.4</td><td>Cache / broker helper</td></tr>
<tr><td>RabbitMQ</td><td>3.9.22-management</td><td>Message-broker software (docker network only; 15672 is not published)</td></tr>
<tr><td>Python</td><td>3.8.18</td><td>Backend runtime (EOL; upgrade is a dedicated project)</td></tr>
<tr><td>Django</td><td>3.2.25</td><td>Backend framework (last 3.2.x; 4.2+ is a dedicated project)</td></tr>
<tr><td>VUE.JS</td><td>3.2.25</td><td>JS framework</td></tr>
<tr><td>NUXT.JS</td><td>2.15.7</td><td>JS framework (Node 14.18.1)</td></tr>
<tr><td>Qogecoin Core</td><td>host daemon</td><td>QOGE node on the host, not in compose</td></tr>
</table>

Python 3.8 and Django 3.2 are both end-of-life. This installer pins Python 3.8.18 and Django 3.2.25 (the last 3.2.x) so a new box matches the current QOGE stack. Moving to Python 3.12 / Django 4.2+ is a separate upgrade, not part of `opencex.sh`. The bundled TradingView charting library is CL v21.066 (2022-04-01) and is replaced only with a licensed newer build.

`opencex.sh` clones backend/frontend/static/admin at the commits listed at the top of the script (override with `BACKEND_COMMIT` and friends). It uses `postgres:14` rather than `postgres:latest`, `set -e`, `collectstatic --noinput`, and non-interactive `docker exec`. Data directories are mode 700. Do not regenerate `docker-compose.yml` on a running database (`FORCE_COMPOSE=1` is required to overwrite). Do not change the live Postgres image under an existing `postgresql_data` volume.

## Before installing

- Order a virtual or physical server, not below the minimum requirements. You will need full access to this server (root). Shared hosting will not work.
- Bind the IPv4 address you received when purchasing the server to your domain. If you don't have a domain yet, you can use [https://nip.io/](https://nip.io/) or [https://sslip.io/](https://sslip.io/).
- Run **Qogecoin Core on the host** before or right after install. Containers reach it as `host.docker.internal:8332`. Configure `rpcuser` / `rpcpassword` to match `QOGE_NODE_USER` / `QOGE_NODE_PASS` in `/app/opencex/backend/.env`, `rpcallowip` covering the Docker bridge (for example `172.16.0.0/12`), and a watch-only wallet named `opencex` (`disable_private_keys=true`).
- Sign up for a Google account and get reCAPTCHA V2 keys (invisible). [https://www.google.com/recaptcha/](https://www.google.com/recaptcha/)
- Get the SMTP server credentials for sending emails (any will do, i.e. [https://www.mailgun.com/](https://www.mailgun.com/)).
- Register an Infura account ([https://infura.io/](https://infura.io/)) and create an API key + secret (ETH deposits).
- Register an Etherscan account ([https://etherscan.io/](https://etherscan.io/)) and create an API key.
- You will need a **QOGE** cold address (legacy `q…`) and an **ETH** address to collect deposits. Optional: BNB and TRX cold addresses when those chains are enabled. A multi-currency wallet such as Trust Wallet is enough to generate ETH/BNB/TRX addresses.
- OPTIONAL. For BNB and BEP-20 support you will need Bscscan / Etherscan V2 credentials (https://bscscan.com/)
- OPTIONAL. For TRX and TRC-20 support you will need TronGrid credentials (https://www.trongrid.io/)
- OPTIONAL. For SMS verification you will need Twilio credentials ([https://twilio.com](https://twilio.com))
- OPTIONAL. For KYT you need Scorechain credentials ([https://www.scorechain.com/](https://www.scorechain.com/))
- OPTIONAL. For KYC you will need Sumsub credentials ([https://sumsub.com/](https://sumsub.com/))

Hummingbot is optional (`IS_HUMMINGBOT_ENABLED`). The matcher, wallets, and QOGE listing work without it.

## Installation

You need to SSH into your server as root and run the following command:

    mkdir /app ; 
    cd /app/ || exit ; 
    git clone https://github.com/QOGE/OpenCEX.git ./deploy ;
    cd deploy ; 
    chmod +x opencex.sh ;
    ./opencex.sh 2>&1 | tee /tmp/install.txt

Installation time ~ 5 minutes.

If something goes wrong you can clean the installation and try again

    cd /app/opencex && docker compose down ; 
    rm -rf /app ;
    docker system prune -a

The exchange is then available on your domain.

**After installation, copy any mode-600 files from `/app/opencex/backend/.handoff/` off the server and delete them. They hold keeper cosigner keys, the generated admin password, and (when created) the admin TOTP secret. Do not leave them on the host.**

Staff TOTP is provisioned out of band (`manage.py provision_admin_otp <username>` or the wizard handoff). First password login at `/apiadmin/login/` does not mint a QR. Restrict `/admin/` and `/apiadmin/` to operator IPs.

RabbitMQ management stays on the docker network (`rabbitmq:15672`). Reach it with an SSH tunnel.

Do not rotate `CRYPTO_KEY` on an existing database.

## License

Apache License, Version 2.0.

Original OpenCEX was developed by [Polygant](https://polygant.net). See `NOTICE` for upstream attribution.
