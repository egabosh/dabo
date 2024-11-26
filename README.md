# Dabo (crypto bot)

The software provided here is called dabo (crypto bot).

## Warning / Disclaimer
The software provided here does not guarantee any profits or function as well as sufficient security. Use at your own risk!!!
This is a private project, which is based on amateur knowledge. Trading cryptocurrencies involves an enormous amount of risks and is considered highly speculative. 
It is strongly recommended to deal intensively with the subject and this bot before using it. Also, when using the possibility should be considered that due to an unfavorable market development, technical errors, bugs or other reasons, the entire invested capital can be lost. This software should therefore only be used if it is justifiable to lose the entire invested capital!

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

It is still under development and is currently only partially functional.

## Copyright / License

Copyright (c) 2022-2024 Oliver Bohlen (aka olli/egabosh)

The software provided here is called dabo (crypto bot)

dabo is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

dabo is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty ofMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with dabo (see COPYING file). If not, see <http://www.gnu.org/licenses/>.

## Data sources
Various data sources such as finance.yahoo.com and crypto exchanges available via ccxt are used. Please check whether this is legal in your region before use.
- query1.finance.yahoo.com (economic data,...)
- api.coinmarketcap.com (crypto data)
- api.bls.gov (CPI, unemployment rate)
- fred.stlouisfed.org (fed funds rate)
- 30rates.com (forecast)
- fapi.binance.com (OpenInterest,...)
- api.alternative.me (Fear and Greed)
- production.dataviz.cnn.io (Fear and Greed CNN)
- https://unpkg.com/lightweight-charts/dist/lightweight-charts.standalone.production.js (TradingView Lightweitgt Charts)
- ...

## dependencies to other software
- CCXT (https://www.ccxt.com | https://github.com/ccxt/ccxt)
- TradingView Lightweitgt Charts (https://www.tradingview.com/lightweight-charts/ | https://github.com/tradingview/lightweight-charts)
- bash, python
- several default linux programs like bc, wget,...
- gaboshlib (https://github.com/egabosh/gaboshlib)
- ...

## Objective
The dabo-bot is intended to help make and execute timely buy and sell decisions automatically in the fast-paced crypto environment.

These decisions are made using one or more self-definable strategies.
Various market data are available as a basis for decision-making, such as price trends, RSI, MACD and EMA indicators of various time intervals, Fear and Greed Index, S&P500 data,... 

## Naming
The name Dabo comes from the Star Trek universe.
Dabo was a roulette-style game of chance developed by the Ferengi.
More information here:
https://memory-alpha.fandom.com/wiki/Dabo
I thought this fits quite well to the cryptotrading world and that's why I chose this name ;-)

## Structure
The Bot is splitted in the following parts:

- dabo-bot: Basic Bot with buy and sell decisions based on self-definable strategies
- dabo-symbols_ticker: Ticker for current symbols and prices
- dabo-ohlcv-candles: Continuously collect OHLCV data
- dabo-indicators: Continuously calculate indicators and other data
- dabo-orders: Continuously collect current orders placed by bot and others
- dabo-transaction-history: Continuously creates overview of historic trades
- dabo-webpage: Continuously creates webpage overview (readonly)
- dabo-web: Webserver for webpage overview

Each part runs parallel to the others in its own docker-container.

## Features
### General:
- theoretically compatible to supported CCXT exchanges. Tested with Phemex Contract trading. Please let me know your experiences with other exchanges.
- parallel processing in separate non-root docker containers
- Notifications via Matrix Messenger to groups

### Dabo Bot
- place limit and market orders and supports ...
- ... leverage trading
- ... short trades
- ... margins cross and isolated
- ... stoploss and takeprofit
- multiple different strategies possible at the same time
### Dabo Symbol Ticker
- automatically finds all supported tokens and pairs and fetches continiously ...
- ... symbols
- ... and prices
### Dabo OHLCV Candle data
OHLCV = Open, High, Low, Close and Volume of a time unit
- time units 1w, 1d, 4h, 1h, 15m and 5m
- 4h, 1h, 15m and 5m from the respective stock exchange
- 1d and 1w data from coinmarketcap to have longer terms
- economic data from yahoo finance
### Dabo Indicators
- data per time unit
- time units 1w, 1d, 4h, 1h, 15m and 5m 
- self-calculated EMA12, 26 ,50, 100, 200, 400 and 800
- self-calculated RSI5, 14, 21 
- self-calculated MACD
- self-calculated significant levels (support/resist)
### Dabo Market Data
- Yahoo Finance
- CoinMarketCap
- BLS.gov
- alternative.me
- CNN
- Fed
### Dabo Orders
### Dabo Transaction History
- Support of additional Exchnages/Brokers JustTrade (CSV-Import) and Bitpanda (API+CSV-Import)
- German tax calculation
### Dabo Webpage
- ReadOnly Overview

## Why bash?
Yes, bash is not a language in which you write something like this in a normal way.

To be honest, I'm more of a Linux admin than a programmer, so I do a lot of my work using bash.
Simply it's the language I'm most familiar with.

Originally this project was supposed to be a simple script to monitor prices of equities and ETFs and set alarms at certain marks. Over time it has expanded a lot and a complete rewrite in another language would have meant a lot of additional work. So it has stayed that way until now.

Finally, it's a hobby project and I have to see how and when I can find time for it, because there also has to be time for family, friends, work and other hobbies.
If there is someone who would like to rewrite this bot in e.g. Python, I would be happy to support them as best I can with this task. Just let me know.

## How to use/install (basic Linux knowledge required!)

Should run on every system with docker.

### 1: Operating System 
Tested and running with Debian 12 (Bookworm).
https://www.debian.org/download
https://www.raspberrypi.com/software/operating-systems/

### 2: Run Ansible Playbooks
On a clean Debian 12 system ypu can run my Ansible Playbooks to use the same environment the bot is developed and running.
Please have a look what exactly the playbooks are doing if you are unsure.

#### 2.1 Download basic install script
```
wget https://github.com/egabosh/linux-setups/blob/main/debian/install.sh
```
#### 2.2 define Playbooks
- debian/basics/basics.yml (https://github.com/egabosh/linux-setups/tree/main/debian/basics) - Basic Debian configuration
- Optional: debian/firewall/firewall.yml (https://github.com/egabosh/linux-setups/tree/main/debian/firewall) - Firewall for the server based on ufw
- Optional: debian/runchecks/runchecks.yml (https://github.com/egabosh/linux-setups/tree/main/debian/runchecks) - System checks and notification
- Optional: debian/backup/backup.yml (https://github.com/egabosh/linux-setups/tree/main/debian/backup) - Backup framework
- Optional: debian/autoupdate/autoupdate.yml (https://github.com/egabosh/linux-setups/tree/main/debian/autoupdate) - Automatic System Updates
- debian/docker/docker.yml (https://github.com/egabosh/linux-setups/tree/main/debian/docker) - Docker Installation
- debian/traefik.server/traefik.yml (https://github.com/egabosh/linux-setups/tree/main/debian/traefik.server) - Traefik Reverse Proxy for Web UI and Letsencrypt Certs
- Optional: debian/turn.server/turn.yml (https://github.com/egabosh/linux-setups/tree/main/debian/turn.server) - Turn Server fpr Audio/Video conferences in Matrix
- Optional: debian/matrix.server/matrix.yml (https://github.com/egabosh/linux-setups/tree/main/debian/matrix.server) - Notifications with own Martix Server
- https://github.com/egabosh/dabo/raw/refs/heads/main/dabo-ansible.yml: The Bot itself

for example:
```
PLAYBOOKS="debian/basics/basics.yml
 debian/firewall/firewall.yml
 debian/runchecks/runchecks.yml
 debian/backup/backup.yml
 debian/autoupdate/autoupdate.yml
 debian/docker/docker.yml 
 debian/traefik.server/traefik.yml 
 debian/turn.server/turn.yml
 debian/matrix.server/matrix.yml
 https://github.com/egabosh/dabo/raw/refs/heads/main/dabo-ansible.yml"
export PLAYBOOKS
```
#### 2.3 Install ansible and run Playbooks
```
bash install.sh
```
### Download
Not necessary if you use the dabo Playbook
```
git clone https://github.com/egabosh/dabo.git
cd dabo
```

### Build container
Not necessary if you use the dabo Playbook
```
docker -l warn compose --ansi never build --progress=plain --pull --no-cache --force-rm
```

### 3. Configuration
Edit docker-compose.yml or create docker-compose.override.yml to fit yout needs e.g. domain and network settings or basic auth, e.g. for traefik and letsencrypt:
```
echo '
services:

  dabo-bot:
    networks:
      - YOURNETWORK

  dabo-web:
    labels:
      - traefik.enable=true
      # DOMAIN
      - traefik.http.routers.dabo-YOURINSTANCENAME.rule=Host(`YOURDOMAIN`)
      - traefik.http.routers.dabo-YOURINSTANCENAME.entrypoints=https
      - traefik.http.routers.dabo-YOURINSTANCENAME.tls=true
      # Proxy to service-port
      - traefik.http.services.dabo-YOURINSTANCENAME.loadbalancer.server.port=80
      - traefik.http.routers.dabo-YOURINSTANCENAME.service=dabo-YOURINSTANCENAME
      # cert via letsencrypt
      - traefik.http.routers.dabo-YOURINSTANCENAME.tls.certresolver=letsencrypt
      # activate secHeaders@file & basic auth
      - traefik.http.routers.dabo-YOURINSTANCENAME.middlewares=secHeaders@file,dabo-YOURINSTANCENAME-basicauth
      # Generate crypted password string with: echo $(htpasswd -nB YOURUSER) | sed -e s/\\$/\\$\\$/g
      - traefik.http.middlewares.dabo-YOURINSTANCENAME-basicauth.basicauth.users=YOURUSER:YOUR-GENERATED-CRYPTED-PASSWORD-STRING
      # Traefik network
      - traefik.docker.network=traefik
    networks:
      - traefik

networks:
  YOURNETWORK:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: YOURBRIDGE
  traefik:
    external: true

' >docker-compose.override.yml
```


Optional: If you use matrix/matrix-commander (https://github.com/egabosh/linux-setups/tree/main/debian/matrix.server) and want do receive Matrix-Messages from the bot you can create an SSH-Key to allow sending Matrix-Messages e.g.:
Automatically done by playbooks.
```
mkdir -p home/.ssh
ssh-keygen -f home/.ssh/id_ed25519 -N "" -t ed25519
chmod 700 home/.ssh
cat home/.ssh/id_ed25519.pub
```
and add Key on your matrix-Server to the authorized_keys of the matrix-User


Create Secrets file for your API Key(s)

- file: dabo/.CCXT-ID-secrets

CCXI-ID see: https://github.com/ccxt/ccxt


Examples:
```
# for Phemex 
echo 'local API_SECRET="YOUR_API_SECRET_FROM_PHEMEX"
local API_KEY="YOUR_API_KEY_FROM_PHEMEX"' >dabo/.phemex-secrets
chmod 400 dabo/.phemex-secrets

# for Binance
echo 'local API_SECRET="YOUR_API_SECRET_FROM_BINANCE"
local API_KEY="YOUR_API_KEY_FROM_BINANCE"' >dabo/.binance-secrets
chmod 400 dabo/.binance-secrets
```

Create Config
Especially set URL, STOCK_EXCHANGE, FEE, CURRENCY,... to fit your needs.
```
vim dabo-bot.conf
```
Defaults in dabo/dabo-bot.conf


### 4. Prepare/Create a stretegy

IMPORTANT!!! 

THE DEFAULT STRATEGY MAY NOT FIT YOUR NEEDS OR WORK PROPERLY. SO YOU CAN LOOSE ALL YOUR MONEY!!! USE ON YOUR OWN RISK!!!

TEST YOUR OWN STRATEGY COMPREHENSIVELY AND OVER A LOGNER PERIOD OF TIME WITH analyze.sh!!! USE ON YOUR OWN RISK!!!

Strategie files can be put in the "strategies"-directory the defaults 

There is an example for a buy and a sell strategy file (deactivated by "return 0" in the forst line):
```
ls strategies/buy.example.conf
ls strategies/sell.example.conf
```
Aditional strategies can be created with Name
```
strategies/buy.<name>.conf
strategies/sell.<name>.conf
```
e.g named "mannover-sulu-1" for buy strategy and "command-kirk-3" for sell strategy
```
strategies/buy.mannover-sulu-1.conf
strategies/sell.command-kirk-3.conf
```

### Optional: Create individual watch-assets.csv
```
cp dabo/watch-assets.csv watch-assets.csv
```
Optional:
You can edit this file if you want do generate warnings or track your asstes/trades.
```
nano watch-assets.csv
```

### Set Rights
Set Rights (UID 10000 for non-root-User in running container):
```
chown -R 10000:10000 dabo data home strategies dabo-bot.conf watch-assets.csv
```

### Operational commands
Run/Restart:
```
docker compose down   # if an old instance is running 
docker compose up -d 
```

Check
```
docker compose ps
```

Logs/Output:
```
docker compose logs -f
```

Update:
Not necessary if you use the playbooks
```
# Optinal: Remove local data
git reset --hard HEAD^   # Remove local commits
git clean -fd            # Remove local uncommited files

# Update and restart
git pull https://github.com/egabosh/dabo.git main -f
docker compose down 
docker compose up -d
```

## Strategies

You can put your own code into the strategies it will be sourced by the bot.

You can use available variables to read (and set) values.

### Variables with current market values

#### Large associative arrays v and vr (reverse)

${v[SYMBOL_TIMEFRAME_ITEM_NUMBER]}

- SYMBOL: Crypto-Symbol for examle ETHUSDT or ECONOMY_DXY ECONOMY_DOWJONES ECONOMY_SP500 ECONOMY_NASDAQ ECONOMY_MSCIEAFE ECONOMY_10YRTREASURY ECONOMY_OIL ECONOMY_GOLD ECONOMY_MSCIWORLD ECONOMY_OILGAS ECONOMY_KRE ECONOMY_EUR-USD
- TIMEFRAME: 5m,15m,1h,4h,1d,1w
- ITEM: date,open,high,low,close,volume,change,ath,ema12,ema26,ema50,ema100,ema200,ema400,ema800,rsi5,rsi14,rsi21,macd,macd_ema9_signal,macd_histogram,macd_histogram_signal,macd_histogram_max,macd_histogram_strength
- NUMBER: 0=latest; 1=second latest

Examples:
```
${v[ECONOMY_NASDAQ_1h_close_0]}
${v[ECONOMY_SP500_rsi14_0]}
${v[ETHUSDT_1w_ema200_0]}
${v[ETHUSDT_1w_macd_histogram_signal_1]}
${v[SOLUSDT_levels_1d]}
$v[$[SOLUSDT_levels_1d_next_up]}
$v[$[ETHUSDT_levels_1w_next_down]}
```
You can find a complete list of available values in the file `data/botdata/values` whic is creates in the runtime of the bot.
An example you can find in example-values.
#### Current price from exchange 

${f_tickers_array[SYMBOL]}
```
${f_tickers_array[SOLUSDT]}
${f_tickers_array[ETH${CURRENCY}]}
```

## Support/Community
New Telegram group for the dabo community. 
https://t.me/dabobotcrypto


## Future ideas/featrues and todosa
- Partial StopLoss and TakeProfit
- Fibonacci Levels
- Forecasts
- Chart improvements
- Volumeindicator and for example RSI on volume values
- Support for decentralized exchanges like uniswap
- Archive/compress old or large CSV-History-files
- Hedge mode (long and short positions the same time)
- Emergency stop if balance falls below defined value
- Analysis tool for collected historical values to try out buy or sell conditions based on them 
- Consideration of trading and funding fees
- Liquidation Heatmap (https://www.coinglass.com/pro/futures/LiquidationHeatMap)
