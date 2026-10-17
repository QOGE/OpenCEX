#!/bin/bash
# C-15: pin source commits and image tags so a new install is reproducible.
# Python 3.8 / Django 3.2.25 stay until a dedicated Django 4.2+ / Python 3.12 upgrade.
# Vendored TradingView CL v21.066 (2022-04-01) stays until a licensed replacement.
# Override any pin with an environment variable before running this script.

BACKEND_REPO="${BACKEND_REPO:-https://github.com/QOGE/OpenCEX-backend.git}"
FRONTEND_REPO="${FRONTEND_REPO:-https://github.com/QOGE/OpenCEX-frontend.git}"
STATIC_REPO="${STATIC_REPO:-https://github.com/QOGE/OpenCEX-static.git}"
ADMIN_REPO="${ADMIN_REPO:-https://github.com/QOGE/OpenCEX-JS-admin.git}"
HUMMINGBOT_REPO="${HUMMINGBOT_REPO:-https://github.com/QOGE/hummingbot.git}"

BACKEND_COMMIT="${BACKEND_COMMIT:-2ad07f377a0b6fcf7f90448e2066a9cd0fe455ea}"
FRONTEND_COMMIT="${FRONTEND_COMMIT:-b511574c2288e1dbc6c3719d1a096567fd1c8c57}"
STATIC_COMMIT="${STATIC_COMMIT:-3631db2ec8de22c766f364c0ed8b6a3ee6f21794}"
ADMIN_COMMIT="${ADMIN_COMMIT:-886847619dcaaf22ef01fb485efc5c9d2b14b74d}"
HUMMINGBOT_COMMIT="${HUMMINGBOT_COMMIT:-f04f835e6f8618140eb32d10373aaa6c0ed63234}"

POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:14}"
REDIS_IMAGE="${REDIS_IMAGE:-redis:7.0.4}"
RABBITMQ_IMAGE="${RABBITMQ_IMAGE:-rabbitmq:3.9.22-management}"
CADDY_IMAGE="${CADDY_IMAGE:-lucaslorentz/caddy-docker-proxy:2.13.1}"
DOCKER_SOCKET_PROXY_IMAGE="${DOCKER_SOCKET_PROXY_IMAGE:-tecnativa/docker-socket-proxy:0.3.0}"

rand_alnum() {
    local n="${1:-32}"
    < /dev/urandom tr -dc '_A-Za-z0-9' | head -c "$n"
    echo
}

clone_at_commit() {
    local url="$1" dest="$2" sha="$3"
    if [ -d "$dest/.git" ]; then
        if [ "${OPENCEX_UPDATE_SOURCES:-0}" = "1" ]; then
            echo "Updating $dest to $sha"
            git -C "$dest" fetch origin
            git -C "$dest" checkout --detach "$sha"
        else
            echo "Keeping existing $dest ($(git -C "$dest" rev-parse --short HEAD)). Set OPENCEX_UPDATE_SOURCES=1 to check out $sha."
        fi
    else
        echo "Cloning $url into $dest at $sha"
        git clone "$url" "$dest"
        git -C "$dest" checkout --detach "$sha"
    fi
}

wait_for_postgres() {
    local i
    echo "Waiting for PostgreSQL..."
    for i in $(seq 1 60); do
        if docker exec postgresql pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; then
            echo "PostgreSQL is ready."
            return 0
        fi
        sleep 2
    done
    echo "PostgreSQL did not become ready." >&2
    return 1
}

if [ $(dpkg-query -W -f='${Status}' docker-ce 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Docker not found, install docker..."
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null 2>&1
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io git docker-compose-plugin > /dev/null 2>&1
    sudo systemctl enable docker > /dev/null 2>&1
    sudo systemctl start docker > /dev/null 2>&1
    echo "Docker has been successfully installed."
else
    echo "Docker already installed."
fi

set -e

mkdir /app/opencex -p
cd /app/opencex || exit
clone_at_commit "$BACKEND_REPO" ./backend "$BACKEND_COMMIT"
clone_at_commit "$FRONTEND_REPO" ./frontend "$FRONTEND_COMMIT"
clone_at_commit "$STATIC_REPO" ./nuxt "$STATIC_COMMIT"
clone_at_commit "$ADMIN_REPO" ./admin "$ADMIN_COMMIT"

echo "`cat <<YOLLOPUKKI


 000000\                                 000000\  00000000\ 00\   00\ 
00  __00\                               00  __00\ 00  _____|00 |  00 |
00 /  00 | 000000\   000000\  0000000\  00 /  \__|00 |      \00\ 00  |
00 |  00 |00  __00\ 00  __00\ 00  __00\ 00 |      00000\     \0000  / 
00 |  00 |00 /  00 |00000000 |00 |  00 |00 |      00  __|    00  00<  
00 |  00 |00 |  00 |00   ____|00 |  00 |00 |  00\ 00 |      00  /\00\ 
 000000  |0000000  |\0000000\ 00 |  00 |\000000  |00000000\ 00 /  00 |
 \______/ 00  ____/  \_______|\__|  \__| \______/ \________|\__|  \__|
          00 |                                                        
          00 |                                                        
          \__|  

Hello! This is OpenCEX Setup. Please enter parameters for your exchange.
If you make a mistake when entering a parameter, don't worry, 
at the end of each parameter block you will have the opportunity 
to re-enter the parameters.

* is for the required field. 
		  
YOLLOPUKKI`"

read -p "Press enter to continue"

cd /app/opencex/backend || exit
FILE=/app/opencex/backend/.env
if test ! -f "$FILE"; then

echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 1 OF 12. PROJECT VARIABLES
===========================================================

PROJECT_NAME* - name of your exchange
DOMAIN* - base domain of your exchange
ADMIN_BASE_URL* - URL of the admin panel, added to DOMAIN
ADMIN_USER* - email of the user that would have admin rights 
ADMIN_MASTERPASS* - master password, used to create 
   balance accrual/debit transactions
SUPPORT_EMAIL - email address of support

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "PROJECT_NAME* (i.e. SuperExchange): "
read PROJECT_NAME
export PROJECT_NAME

echo -n "DOMAIN* (i.e. test.com): "
read DOMAIN
export DOMAIN

echo -n "ADMIN_BASE_URL* (i.e: admin): "
read ADMIN_BASE_URL
export ADMIN_BASE_URL

echo -n "ADMIN_USER* (i.e: admin@exchange.net): "
read ADMIN_USER
export ADMIN_USER

echo -n "ADMIN_MASTERPASS*: "
read ADMIN_MASTERPASS
export ADMIN_MASTERPASS

echo -n "SUPPORT_EMAIL: "
read SUPPORT_EMAIL
export SUPPORT_EMAIL

#TELEGRAM - telegram chat URL (i.e. opencex)
#FACEBOOK - facebook page URL
#TWITTER - twitter page URL
#LINKEDIN - linkedin page URL

TELEGRAM=opencex
FACEBOOK=polygant
TWITTER=polygant
LINKEDIN=polygant
LOGO=

export TELEGRAM
export FACEBOOK
export TWITTER
export LINKEDIN
export LOGO

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done


echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 2 OF 12. COMMON SERVICES
===========================================================

RECAPTCHA* - Google Captcha site key
RECAPTCHA_SECRET* - Google Captcha secret key
TELEGRAM_CHAT_ID - used to send alerts to Telegram
TELEGRAM_ALERTS_CHAT_ID - monitoring collection and the state of collectors
TELEGRAM_BOT_TOKEN - token for the Alert bot

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "RECAPTCHA*: "
read RECAPTCHA
export RECAPTCHA

echo -n "RECAPTCHA_SECRET*: "
read RECAPTCHA_SECRET
export RECAPTCHA_SECRET

echo -n "TELEGRAM_CHAT_ID: "
read TELEGRAM_CHAT_ID
export TELEGRAM_CHAT_ID

echo -n "TELEGRAM_ALERTS_CHAT_ID: "
read TELEGRAM_ALERTS_CHAT_ID
export TELEGRAM_ALERTS_CHAT_ID

echo -n "TELEGRAM_BOT_TOKEN: "
read TELEGRAM_BOT_TOKEN
export TELEGRAM_BOT_TOKEN

# CAPTCHA_ALLOWED_IP_MASK=172\.\d{1,3}\.\d{1,3}\.\d{1,3}
# export CAPTCHA_ALLOWED_IP_MASK

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done


echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 3 OF 12. BLOCKCHAIN SERVICES
===========================================================

INFURA_API_KEY* - used for the ETH blockchain data
INFURA_API_SECRET* - used for the ETH blockchain data

ETHERSCAN_KEY* - used for the ETH blockchain data

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "INFURA_API_KEY*: "
read INFURA_API_KEY
export INFURA_API_KEY

echo -n "INFURA_API_SECRET*: "
read INFURA_API_SECRET
export INFURA_API_SECRET

echo -n "ETHERSCAN_KEY*: "
read ETHERSCAN_KEY
export ETHERSCAN_KEY

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done


echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 4 OF 12. SAFE ADDRESSES
===========================================================

QOGE_SAFE_ADDR* - Qogecoin legacy (q...) cold wallet. All QOGE deposits are swept there
ETH_SAFE_ADDR* - ethereum address. All ETH and ERC-20 deposits go there

Bitcoin is disabled on this fork (Qogecoin uses RPC 8332).

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "QOGE_SAFE_ADDR* (legacy q... cold address you control): "
read QOGE_SAFE_ADDR
if [ -z "$QOGE_SAFE_ADDR" ]; then
  echo "QOGE_SAFE_ADDR is required. Use a cold wallet you control."
  continue
fi
export QOGE_SAFE_ADDR

echo -n "ETH_SAFE_ADDR*: "
read ETH_SAFE_ADDR
export ETH_SAFE_ADDR

BTC_SAFE_ADDR=
export BTC_SAFE_ADDR

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done


echo "`cat <<YOLLOPUKKI

=======================================================================================
     STEP 5 of 12. BINANCE BSC BLOCKCHAIN, BNB and USDT BEP-20 SUPPORT. (optional)
=======================================================================================

You can set ENABLED_BNB: False or leave it blank to turn it off.

BSCSCAN_KEY* - used for the BSC blockchain data
BNB_SAFE_ADDR* - binance smart chain address. All BNB and BEP-20 deposits go there

---------------------------------------------------------------------------------------
YOLLOPUKKI`"


while true; do

echo -n "ENABLED_BNB (True/False): "
read ENABLED_BNB
export ENABLED_BNB

if [ "$ENABLED_BNB" = "True" ]; then

echo -n "BSCSCAN_KEY*: "
read BSCSCAN_KEY
export BSCSCAN_KEY

echo -n "BNB_SAFE_ADDR*: "
read BNB_SAFE_ADDR
export BNB_SAFE_ADDR


fi

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done





echo "`cat <<YOLLOPUKKI

=======================================================================================
     STEP 6 of 12. TRON BLOCKCHAIN, TRX and USDT TRC-20 SUPPORT. (optional)
=======================================================================================

You can set ENABLED_TRON: False or leave it blank to turn it off.

TRONGRID_API_KEY* - used for the Tron blockchain data
TRX_SAFE_ADDR* - tron address. All TRX and TRC-20 deposits go there

---------------------------------------------------------------------------------------

YOLLOPUKKI`"


while true; do

echo -n "ENABLED_TRON (True/False): "
read ENABLED_TRON
export ENABLED_TRON

if [ "$ENABLED_TRON" = "True" ]; then

echo -n "TRONGRID_API_KEY*: "
read TRONGRID_API_KEY
export TRONGRID_API_KEY

echo -n "TRX_SAFE_ADDR*: "
read TRX_SAFE_ADDR
export TRX_SAFE_ADDR


fi

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done


echo "`cat <<YOLLOPUKKI

=======================================================================================
 STEP 7 of 12. POLYGON BLOCKCHAIN, MATIC and USDT MATIC SUPPORT. (optional)
=======================================================================================

You can set ENABLED_MATIC: False or leave it blank to turn it off.

POLYGONSCAN_KEY* - used for the Polygon blockchain data
MATIC_SAFE_ADDR* - Polygon address. All MATIC and ERC-20 (MATIC) deposits go there
---------------------------------------------------------------------------------------

YOLLOPUKKI`"


while true; do

echo -n "ENABLED_MATIC (True/False): "
read ENABLED_MATIC
export ENABLED_MATIC
COMMON_TASKS_MATIC=false
export COMMON_TASKS_MATIC
if [ "$ENABLED_MATIC" = "True" ]; then

COMMON_TASKS_MATIC=true
export COMMON_TASKS_MATIC

echo -n "POLYGONSCAN_KEY*: "
read POLYGONSCAN_KEY
export POLYGONSCAN_KEY

echo -n "MATIC_SAFE_ADDR*: "
read MATIC_SAFE_ADDR
export MATIC_SAFE_ADDR

fi

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done



echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 8 OF 12. EMAIL SERVICE
===========================================================

Used for sending notifications and alerts.

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "EMAIL_HOST*: "
read EMAIL_HOST
export EMAIL_HOST

echo -n "EMAIL_HOST_USER*: "
read EMAIL_HOST_USER
export EMAIL_HOST_USER

echo -n "EMAIL_HOST_PASSWORD*: "
read EMAIL_HOST_PASSWORD
export EMAIL_HOST_PASSWORD

echo -n "EMAIL_PORT*: "
read EMAIL_PORT
export EMAIL_PORT

echo -n "EMAIL_USE_TLS* (True/False): "
read EMAIL_USE_TLS
export EMAIL_USE_TLS

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done


echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 9 OF 12. SMS SERVICE TWILIO (optional)
===========================================================

Used for sending notifications and alerts. 
You can set IS_SMS_ENABLED: False or leave it blank
to turn it off.

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "IS_SMS_ENABLED (True/False): "
read IS_SMS_ENABLED
export IS_SMS_ENABLED

if [ "$IS_SMS_ENABLED" = "True" ]; then
echo -n "TWILIO_ACCOUNT_SID: "
read TWILIO_ACCOUNT_SID
export TWILIO_ACCOUNT_SID

echo -n "TWILIO_AUTH_TOKEN: "
read TWILIO_AUTH_TOKEN
export TWILIO_AUTH_TOKEN

echo -n "TWILIO_VERIFY_SID: "
read TWILIO_VERIFY_SID
export TWILIO_VERIFY_SID

echo -n "TWILIO_PHONE: "
read TWILIO_PHONE
export TWILIO_PHONE
echo ""
fi

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done

echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 10 OF 12. KYC PROVIDER SUMSUB (OPTIONAL)
===========================================================

Used for KYC. 
You can set IS_KYC_ENABLED: False or leave it blank
to turn it off.

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "IS_KYC_ENABLED (True/False): "
read IS_KYC_ENABLED
export IS_KYC_ENABLED

if [ "$IS_KYC_ENABLED" = "True" ]; then
echo -n "SUMSUB_SECRET_KEY: "
read SUMSUB_SECRET_KEY
export SUMSUB_SECRET_KEY

echo -n "SUMSUB_APP_TOKEN: "
read SUMSUB_APP_TOKEN
export SUMSUB_APP_TOKEN

echo -n "SUMSUM_CALLBACK_VALIDATION_SECRET: "
read SUMSUM_CALLBACK_VALIDATION_SECRET
export SUMSUM_CALLBACK_VALIDATION_SECRET
fi

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done


echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 11 OF 12. KYT PROVIDER SCORECHAIN (OPTIONAL)
===========================================================

Used for KYT. 
You can set IS_KYT_ENABLED: False or leave it blank
to turn it off.

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "IS_KYT_ENABLED (True/False): "
read IS_KYT_ENABLED
export IS_KYT_ENABLED

if [ "$IS_KYT_ENABLED" = "True" ]; then

echo -n "SCORECHAIN_BITCOIN_TOKEN: "
read SCORECHAIN_BITCOIN_TOKEN
export SCORECHAIN_BITCOIN_TOKEN

echo -n "SCORECHAIN_ETHEREUM_TOKEN: "
read SCORECHAIN_ETHEREUM_TOKEN
export SCORECHAIN_ETHEREUM_TOKEN

echo -n "SCORECHAIN_TRON_TOKEN: "
read SCORECHAIN_TRON_TOKEN
export SCORECHAIN_TRON_TOKEN

echo -n "SCORECHAIN_BNB_TOKEN: "
read SCORECHAIN_BNB_TOKEN
export SCORECHAIN_BNB_TOKEN

fi

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done

echo "`cat <<YOLLOPUKKI

===========================================================
     STEP 12 OF 12. MARKET MAKING BOT - HUMMINGBOT (OPTIONAL)
===========================================================

Used for market making and other strategies.
You can set IS_HUMMINGBOT_ENABLED: False or leave it blank
to turn it off.

-----------------------------------------------------------
YOLLOPUKKI`"

while true; do

echo -n "IS_HUMMINGBOT_ENABLED (True/False): "
read IS_HUMMINGBOT_ENABLED
export IS_HUMMINGBOT_ENABLED

echo "-----------------------------------------------------------"
    read -p "IS EVERYTHING CORRECT? (y or n)" YESORNO
    case $YESORNO in
        [Yy]* ) break;;
        [Nn]* ) echo "Re-enter the parameters.";;
        * ) break;;
    esac
done

#echo "Instance name"
INSTANCE_NAME='opencex'
export INSTANCE_NAME

#echo "Postgres credentials - user, database name, password, server address and port"
DB_NAME=opencex
DB_USER=opencex
DB_PASS=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c12)
DB_HOST=postgresql
DB_PORT=5432
export DB_NAME
export DB_USER
export DB_PASS
export DB_HOST
export DB_PORT

#echo "RabbitMQ credentials - user, password, server address and port"
AMQP_USER=opencex
AMQP_PASS=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c12)
AMQP_HOST=rabbitmq
AMQP_PORT=5672
export AMQP_USER
export AMQP_PASS
export AMQP_HOST
export AMQP_PORT

# Bitcoin is disabled; dummy values keep .env.template substitution working.
BTC_NODE_USER=opencex
BTC_NODE_PASS=unused
BTC_NODE_PORT=8333
BTC_NODE_HOST=127.0.0.1
export BTC_NODE_USER
export BTC_NODE_PASS
export BTC_NODE_PORT
export BTC_NODE_HOST
export COMMON_TASKS_BTC=False

# Qogecoin node on the host (RPC 8332). Containers use host.docker.internal.
QOGE_NODE_USER=opencex
QOGE_NODE_PASS=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c12)
QOGE_NODE_PORT=8332
QOGE_NODE_HOST=host.docker.internal
QOGE_NODE_WALLET=opencex
QOGE_NODE_COOKIE_FILE=
QOGE_ADDRESS_LEGACY=True
COMMON_TASKS_QOGE=True
export QOGE_NODE_USER
export QOGE_NODE_PASS
export QOGE_NODE_PORT
export QOGE_NODE_HOST
export QOGE_NODE_WALLET
export QOGE_NODE_COOKIE_FILE
export QOGE_ADDRESS_LEGACY
export COMMON_TASKS_QOGE

#echo "Redis credentials - server address and port"
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASS=
export REDIS_HOST
export REDIS_PORT
export REDIS_PASS

#echo "the address where bots can directly access the django instance"
BOTS_API_BASE_URL=http://opencex:8080
export BOTS_API_BASE_URL

# Django / JWT signing key (must not be the public OpenCEX default)
SECRET_KEY=$(rand_alnum 64)
export SECRET_KEY

# AES-CBC wallet-key encryption passphrase (hashed to 32 bytes in AESCoderDecoder)
CRYPTO_KEY=$(rand_alnum 32)
export CRYPTO_KEY

# bot user password
BOT_PASSWORD=$(rand_alnum 24)
export BOT_PASSWORD

envsubst < /app/opencex/backend/.env.template > /app/opencex/backend/.env

fi

source /app/opencex/backend/.env
set -a
cd /app/opencex/frontend || exit
FILE=/app/opencex/frontend/src/local_config

if test ! -f "$FILE"; then
envsubst < /app/opencex/frontend/src/example.local_config.js > /app/opencex/frontend/src/local_config
### save to env

cat << EOF >> /app/opencex/backend/.env


#opencex frontend values
RECAPTCHA=$RECAPTCHA
TELEGRAM=$TELEGRAM
TG_NEWS=$TG_NEWS
SUPPORT_EMAIL=$SUPPORT_EMAIL
FACEBOOK=$FACEBOOK
TWITTER=$TWITTER
LINKEDIN=$LINKEDIN
EOF

fi

##################
# START BUILDING!
##################


# build front
mkdir -p /app/opencex/frontend/deploy/
cp /app/deploy/frontend/Dockerfile /app/opencex/frontend/deploy/Dockerfile
cp /app/deploy/frontend/default.conf /app/opencex/frontend/deploy/default.conf
cp /app/deploy/frontend/nginx.conf /app/opencex/frontend/deploy/nginx.conf
sed -i "s/ADMIN_BASE_URL/$ADMIN_BASE_URL/g" /app/opencex/frontend/deploy/default.conf
sed -i "s/DOMAIN/$DOMAIN/g" /app/opencex/frontend/deploy/default.conf
docker build -t frontend -f deploy/Dockerfile .

# build nuxt
mkdir -p /app/opencex/nuxt/deploy/
cd /app/opencex/nuxt || exit
cp /app/deploy/nuxt/.env.template /app/opencex/nuxt/
cp /app/deploy/nuxt/Dockerfile /app/opencex/nuxt/deploy/Dockerfile
envsubst < /app/opencex/nuxt/.env.template > /app/opencex/nuxt/.env
docker build -t nuxt -f deploy/Dockerfile .

# build admin
mkdir -p /app/opencex/admin/deploy/
cd /app/opencex/admin || exit
cp /app/deploy/admin/Dockerfile /app/opencex/admin/deploy/Dockerfile
cp /app/deploy/admin/default.conf /app/opencex/admin/deploy/default.conf
cp /app/deploy/admin/.env.template /app/opencex/admin/
sed -i "s/ADMIN_BASE_URL/$ADMIN_BASE_URL/g" /app/opencex/admin/deploy/default.conf
envsubst < /app/opencex/admin/.env.template > /app/opencex/admin/src/local_config.js
docker build -t admin -f deploy/Dockerfile .


# build backend
cd /app/opencex/backend/ || exit
chmod +x /app/opencex/backend/manage.py
docker build -t opencex .


### install Caddy

mkdir /app/opencex -p
cd /app/opencex || exit
mkdir caddy_data postgresql_data redis_data rabbitmq_data rabbitmq_logs -p
mkdir -p /app/opencex/backend/media /app/opencex/backend/staticfiles
chmod 700 caddy_data postgresql_data redis_data rabbitmq_data rabbitmq_logs
# Official postgres/redis/rabbitmq images run as uid 999.
chown 999:999 postgresql_data redis_data rabbitmq_data rabbitmq_logs
docker network inspect caddy >/dev/null 2>&1 || docker network create caddy

WRITE_COMPOSE=1
if [ -f docker-compose.yml ] && [ "${FORCE_COMPOSE:-0}" != "1" ]; then
  echo "Keeping existing docker-compose.yml (set FORCE_COMPOSE=1 to regenerate)."
  WRITE_COMPOSE=0
fi

if [ "$WRITE_COMPOSE" = "1" ]; then
cat << EOF > docker-compose.yml
version: "3.7"
networks:
  caddy:
    external: true
services:
    opencex:
     container_name: opencex
     image: opencex:latest
     command: gunicorn  exchange.wsgi:application   -b 0.0.0.0:8080 -w 2 --access-logfile - --error-logfile -
#     entrypoint: tail -f /dev/null
     extra_hosts:
      - "host.docker.internal:host-gateway"
     restart: always
     healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8080/api/public/v1/ticker', headers={'Host':'$DOMAIN'}), timeout=4)"]
      interval: 30s
      timeout: 8s
      retries: 3
      start_period: 45s
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy


    opencex-wss:
     container_name: opencex-wss
     image: opencex:latest
     command: daphne -b 0.0.0.0 exchange.asgi:application  --ping-interval 600 --ping-timeout 600
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-cel:
     container_name: opencex-cel
     image: opencex:latest
     command: celery -A exchange worker -l info -n general -B -s /tmp/cebeat.db -X btc,qoge,eth_new_blocks,eth_deposits,eth_payouts,eth_check_balances,eth_accumulations,eth_tokens_accumulations,eth_send_gas,bnb_new_blocks,bnb_deposits,bnb_payouts,bnb_check_balances,bnb_accumulations,bnb_tokens_accumulations,bnb_send_gas,trx_new_blocks,trx_deposits,trx_payouts,trx_check_balances,trx_accumulations,trx_tokens_accumulations,matic_new_blocks,matic_deposits,matic_payouts,matic_check_balances,matic_accumulations,matic_tokens_accumulations
     extra_hosts:
      - "host.docker.internal:host-gateway"
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-stack:
     container_name: opencex-stack
     image: opencex:latest
     command: python bin/stack.py
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-qoge:
     container_name: opencex-qoge
     image: opencex:latest
     command: /app/manage.py qogeworker
     restart: always
     extra_hosts:
      - "host.docker.internal:host-gateway"
     healthcheck:
      test: ["CMD", "python", "-c", "import socket; s=socket.socket(); s.settimeout(4); s.connect(('host.docker.internal',8332)); s.close()"]
      interval: 30s
      timeout: 6s
      retries: 3
      start_period: 20s
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-eth-blocks:
     container_name: opencex-eth-blocks
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n eth_new_blocks -Q eth_new_blocks -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-bnb-blocks:
     container_name: opencex-bnb-blocks
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n bnb_new_blocks -Q bnb_new_blocks -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-trx-blocks:
     container_name: opencex-trx-blocks
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n trx_new_blocks -Q trx_new_blocks -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-matic-blocks:
     container_name: opencex-matic-blocks
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n matic_new_blocks -Q matic_new_blocks -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-deposits:
     container_name: opencex-deposits
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n deposits -Q trx_deposits,bnb_deposits,eth_deposits,matic_deposits -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-payouts:
     container_name: opencex-payouts
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n payouts -Q trx_payouts,eth_payouts,bnb_payouts,matic_payouts -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-balances:
     container_name: opencex-balances
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n check_balances -Q trx_check_balances,bnb_check_balances,eth_check_balances,matic_check_balances -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-coin-accumulations:
     container_name: opencex-coin-accumulations
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n coin_accumulations -Q trx_accumulations,bnb_accumulations,eth_accumulations,matic_accumulations -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-token-accumulations:
     container_name: opencex-token-accumulations
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n tokens_accumulations -Q trx_tokens_accumulations,bnb_tokens_accumulations,eth_tokens_accumulations,matic_tokens_accumulations -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    opencex-gas:
     container_name: opencex-gas
     image: opencex:latest
     command: bash -c "celery -A exchange worker -l info -n send_gas -Q trx_send_gas,bnb_send_gas,eth_send_gas,matic_send_gas -c 1 "
     restart: always
     volumes:
      - /app/opencex/backend:/app
     networks:
      - caddy
     depends_on:
      - postgresql
      - redis
      - rabbitmq
      - frontend
      - nuxt
      - caddy
      - opencex

    frontend:
     image: frontend:latest
     container_name: frontend
     restart: always
     healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1/"]
      interval: 30s
      timeout: 5s
      retries: 3
     volumes:
     - /app/opencex/backend/staticfiles:/app/staticfiles:ro
     - /app/opencex/backend/media:/app/media:ro
     networks:
     - caddy
     labels:
      caddy: $DOMAIN
      caddy.reverse_proxy: "{{upstreams 80}}"
    nuxt:
     image: nuxt:latest
     container_name: nuxt
     restart: always
     networks:
     - caddy
    admin:
     image: admin:latest
     container_name: admin
     restart: always
     networks:
     - caddy
    docker-socket-proxy:
      image: $DOCKER_SOCKET_PROXY_IMAGE
      container_name: docker-socket-proxy
      restart: always
      environment:
        CONTAINERS: 1
        NETWORKS: 1
        TASKS: 1
        SERVICES: 1
        INFO: 1
        VERSION: 1
        POST: 0
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock:ro
      networks:
        - caddy
    caddy:
      image: $CADDY_IMAGE
      restart: always
      ports:
        - 80:80
        - 443:443
      environment:
        - CADDY_INGRESS_NETWORKS=caddy
        - DOCKER_HOST=tcp://docker-socket-proxy:2375
      networks:
        - caddy
      volumes:
        - ./caddy_data:/data
      depends_on:
        - docker-socket-proxy

    postgresql:
     container_name: postgresql
     hostname: postgresql
     restart: always
     image: $POSTGRES_IMAGE
     shm_size: 1g
     healthcheck:
       test: ["CMD-SHELL", "pg_isready -U $DB_USER -d $DB_NAME"]
       interval: 30s
       timeout: 5s
       retries: 3
       start_period: 20s
     volumes:
        - ./postgresql_data:/var/lib/postgresql/data
     environment:
       POSTGRES_USER: "$DB_USER"
       POSTGRES_PASSWORD: "$DB_PASS"
       POSTGRES_DB: "$DB_NAME"
     networks:
      - caddy

    redis:
     container_name: redis
     restart: always
     image: $REDIS_IMAGE
     user: "999:999"
     volumes:
         - ./redis_data:/data
     healthcheck:
       test: ["CMD", "redis-cli", "ping"]
       interval: 30s
       timeout: 5s
       retries: 3
     networks:
       - caddy
    rabbitmq:
     hostname: rabbitmq
     container_name: rabbitmq
     restart: always
     image: $RABBITMQ_IMAGE
     volumes:
         - ./rabbitmq_data/:/var/lib/rabbitmq/
         - ./rabbitmq_logs/:/var/log/rabbitmq/
     environment:
         RABBITMQ_DEFAULT_USER: $AMQP_USER
         RABBITMQ_DEFAULT_PASS: $AMQP_PASS
         RABBITMQ_DEFAULT_VHOST: /
     networks:
       - caddy
     # Management UI stays on the docker network (rabbitmq:15672).
     # Reach it with an SSH tunnel; do not attach a public Caddy hostname.
EOF
fi

# build hummingbot
if [ "$IS_HUMMINGBOT_ENABLED" = "True" ]; then
cd /app/opencex || exit
clone_at_commit "$HUMMINGBOT_REPO" ./hmbot "$HUMMINGBOT_COMMIT"
cd ./hmbot
docker build -t hummingbot:latest -f Dockerfile --target=release .
if [ "$WRITE_COMPOSE" = "1" ]; then
cat << EOF >> /app/opencex/docker-compose.yml
    hummingbot:
     container_name: hummingbot
     hostname: hummingbot
     restart: always
     image: hummingbot:latest
     volumes:
       - /app/opencex/hmbot/conf:/home/hummingbot/conf
       - /app/opencex/hmbot/conf/connectors:/home/hummingbot/conf/connectors
       - /app/opencex/hmbot/conf/strategies:/home/hummingbot/conf/strategies
       - /app/opencex/hmbot/logs:/home/hummingbot/logs
       - /app/opencex/hmbot/data:/home/hummingbot/data
       - /app/opencex/hmbot/scripts:/home/hummingbot/scripts
     networks:
       - caddy
     tty: true
     stdin_open: true
EOF
fi
fi
cd /app/opencex
docker compose up -d

docker stop opencex-cel opencex-wss || true
sleep 5
wait_for_postgres
docker exec opencex python ./manage.py migrate --noinput
docker exec opencex python ./manage.py collectstatic --noinput
docker compose up -d



cd /app/opencex || exit
docker compose stop
docker compose up -d
sleep 30
wait_for_postgres
if [ -f /app/opencex/backend/.wizard_complete ]; then
  echo "Skipping wizard (found /app/opencex/backend/.wizard_complete)."
else
  docker exec opencex python wizard.py
  touch /app/opencex/backend/.wizard_complete
fi
cd /app/opencex || exit
docker compose stop
docker compose up -d

echo "Host qogecoind must accept Docker RPC on 8332:"
echo "  rpcuser/rpcpassword = QOGE_NODE_USER / QOGE_NODE_PASS in /app/opencex/backend/.env"
echo "  rpcallowip covering the Docker bridge (e.g. 172.16.0.0/12)"
echo "  wallet=opencex (watch-only, disable_private_keys=true)"

# cleanup
# cd /app/opencex && docker compose down
# rm -rf /app
# docker system prune -a
