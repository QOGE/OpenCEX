<p align="center">
  <a href="https://polygant.net/opencex/" target="_blank">
    <img alt="OpenCEX Logo" width="500" src="https://github.com/Polygant/OpenCEX/blob/master/logo.png">
  </a>
</p>

<p align="center">
OpenCEX is a free and open source cryptocurrency exchange platform.<br>
Developed by <a href="https://polygant.net" target="_blank">Polygant</a>.  

<p align="center">
<a href="https://polygant.notion.site/OpenCEX-Help-Center-8cf8c842bde947c3818a615a88ceef9c" target="_blank">OpenCEX documentation</a> | <a href="https://t.me/opencex" target="_blank">Telegram chat</a>
</p>

> [!NOTE]
> This is the QOGE fork of unmaintained Polygant OpenCEX (`master` only).
> Installer clones backend, frontend, static, and admin from `github.com/QOGE/...`.

> [!CAUTION]
> Upstream Polygant OpenCEX is not maintained.
> The original code is provided as-is.

## Main features.

-   Custodial wallet supporting BTC, ETH, BNB, TRX, USDT (ERC-20, BEP-20, TRC-20). Deposit and withdrawal.
-   Order matching engine. Trading pairs BTC-USDT, ETH-USDT, BNB-USDT, TRX-USDT.
-   Professional exchange interface for placing orders.    
-   Simplified interface for quick swap.
-   KYT transaction verification (requires Scorechain keys).
-   KYC verification of users (requires Sumsub keys).
-   SMS 2fa for users (requires Twilio keys).

## System requirements.

<table>
<tr>
<td><b>Minimum</b></td>
<td><b>Recommended</b></td>
</tr>
<tr>
<td>CPU: 4 cores<br>RAM: 16 GB<br>Disks: 40 GB<br>OS: Ubuntu 22.04<br><br><a href="https://www.hetzner.com/cloud" target="_blank">https://www.hetzner.com/cloud</a></td>
<td>CPU: 8 cores<br>RAM: 64 Gb<br>Disks: 2x1Tb NVMe SSD<br>OS: Ubuntu 22.04<br><br><a href="https://www.hetzner.com/dedicated-rootserver/ax51-nvme" target="_blank">https://www.hetzner.com/dedicated-rootserver/ax51-nvme</a></td>
</tr>
</table>

## The software used.

<table>
<tr><td>Docker</td><td>CE (installer-pinned compose images)</td><td>OS-level virtualization</td></tr>
<tr><td>NGINX</td><td>1.26.3-alpine</td><td>Web server (frontend/admin images)</td></tr>
<tr><td>Caddy</td><td>lucaslorentz/caddy-docker-proxy:2.13.1</td><td>TLS reverse proxy</td></tr>
<tr><td>Postgres</td><td>14</td><td>RDBMS (do not use postgres:latest)</td></tr>
<tr><td>Redis server</td><td>7.0.4</td><td>Cache / broker helper</td></tr>
<tr><td>RabbitMQ</td><td>3.9.22-management</td><td>Message-broker software</td></tr>
<tr><td>Python</td><td>3.8.18</td><td>Backend runtime (EOL; upgrade is a dedicated project)</td></tr>
<tr><td>Django</td><td>3.2.25</td><td>Backend framework (last 3.2.x; 4.2+ is a dedicated project)</td></tr>
<tr><td>VUE.JS</td><td>3.2.25</td><td>JS framework</td></tr>
<tr><td>NUXT.JS</td><td>2.15.7</td><td>JS framework (Node 14.18.1)</td></tr>
<tr><td>Qogecoin Core</td><td>host daemon</td><td>QOGE node on the host, not in compose</td></tr>
</table>

Python 3.8 and Django 3.2 are both end-of-life. This installer pins Python 3.8.18 and Django 3.2.25 (the last 3.2.x) so a new box matches the current QOGE stack. Moving to Python 3.12 / Django 4.2+ is a separate upgrade, not part of `opencex.sh`. The bundled TradingView charting library is CL v21.066 (2022-04-01) and is replaced only with a licensed newer build.

`opencex.sh` clones backend/frontend/static/admin at the commits listed at the top of the script (override with `BACKEND_COMMIT` and friends). It uses `postgres:14` rather than `postgres:latest`, `set -e`, `collectstatic --noinput`, and non-interactive `docker exec`. Data directories are mode 700. Do not regenerate `docker-compose.yml` on a running database (`FORCE_COMPOSE=1` is required to overwrite). Do not change the live Postgres image under an existing `postgresql_data` volume.

## Before installing:

-   Watch the installation video [https://youtu.be/c-WnQkvBwf0](https://youtu.be/c-WnQkvBwf0)
-   Order a virtual or physical server, not below the minimum requirements. You will need full access to this server (root). Shared hosting will not work.
-   Bind the IPv4 address you received when purchasing the server to your domain. If you don't have a domain yet, you can use [https://nip.io/](https://nip.io/) or [https://sslip.io/](https://sslip.io/).
-   Sign up for a Google account and get reCAPTCHA V2 keys (invisible). [https://www.google.com/recaptcha/](https://www.google.com/recaptcha/)
-   Get the SMTP server credentials for sending emails (any will do, i.e. [https://www.mailgun.com/](https://www.mailgun.com/)).
-   Register an Infura account ([https://infura.io/](https://infura.io/)) and create an API key + secret.
-   Register an Etherscan account ([https://etherscan.io/](https://etherscan.io/)) and create an API key.
-   You will need BTC, ETH addresses and BNB, TRX addresses(optional) to collect cryptocurrency deposits (cold addresses). If you don't have it yet, you can use any multi-currency wallet like Trust Wallet and generate BTC, ETH, BNB, TRX addresses.
-   OPTIONAL. For BNB и BEP-20 support you will need Bscscan credentials (https://bscscan.com/)
-   OPTIONAL. For TRX and TRC-20 support you will need Trondrid credentials (https://www.trongrid.io/)
-   OPTIONAL. For SMS verification you will need Twilio credentials ([https://twilio.com](https://twilio.com))
-   OPTIONAL. For KYT you need Scorechain credentials ([https://www.scorechain.com/](https://www.scorechain.com/))
-   OPTIONAL. For KYC you will need Sumsub credentials ([https://sumsub.com/](https://sumsub.com/))
    

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

🥳 Congratulations, the exchange has been successfully installed!  
You can open it by your domain name.

**After installation, copy any mode-600 files from `/app/opencex/backend/.handoff/` off the server and delete them. They hold keeper cosigner keys and the generated admin password. Do not leave them on the host.**

**Mind that BTC node will take up to 30 hours to fully sync. BTC transactions sent to user addresses in this period will be collected and credited only after a full sync.**

## Documentation
-   [OpenCEX Help Center](https://www.notion.so/polygant/OpenCEX-Help-Center-8cf8c842bde947c3818a615a88ceef9c)
-   [Admin panel Guide](https://docs.google.com/document/d/1VoBFEjzmGXzNHQYfvu8BYHvoSv9Sg73AV9wWGvsRJ04/edit#)

## Can I hire you guys?

You can request a consultation or order web and mobile development services by Polygant, just visit our site. 😎

Say hi: [hello@polygant.net](mailto:hello@polygant.net) . We will be happy to work with you!

## License
Apache License, Version 2.0
