import os
from pathlib import Path
from typing import Dict

DEFAULT_CONFIG_PATH = Path("/dabo/dabo-bot.conf")
OVERRIDE_CONFIG_PATH = Path("/dabo/dabo-bot.override.conf")
SECRETS_DIR = Path("/dabo/secrets")
SUPPORTED_EXCHANGES_FILE = Path("/dabo/htdocs/botdata/CCXT_SUPPORTED_EXCHANGES")
TICKERS_DIR = Path("/dabo/htdocs/botdata")


def parse_shell_like_config(path: Path) -> Dict[str, str]:
    """Parse a simple KEY=\"VALUE\" style config file into a dict."""
    config: Dict[str, str] = {}
    if not path.exists():
        return config
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                # Strip optional surrounding quotes
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                config[key] = value
    except Exception:
        # In case of parsing error, return what we have
        return config
    return config


def format_shell_like_config(config: Dict[str, str]) -> str:
    """Format dict back into KEY=\"VALUE\" lines."""
    lines = []
    for key, value in config.items():
        # Always quote, escape inner quotes
        safe_value = str(value).replace('"', '\\"')
        lines.append(f'{key}="{safe_value}"')
    return "\n".join(lines) + "\n"


def load_effective_config() -> Dict[str, str]:
    """Load default config and overlay with override config."""
    default_cfg = parse_shell_like_config(DEFAULT_CONFIG_PATH)
    override_cfg = parse_shell_like_config(OVERRIDE_CONFIG_PATH)
    effective = default_cfg.copy()
    effective.update(override_cfg)
    return effective


def load_override_config() -> Dict[str, str]:
    """Load only override config."""
    return parse_shell_like_config(OVERRIDE_CONFIG_PATH)


def save_override_config(new_values: Dict[str, str]) -> None:
    """Update override config with new values and write to file."""
    current = load_override_config()
    current.update(new_values)
    OVERRIDE_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OVERRIDE_CONFIG_PATH, "w", encoding="utf-8") as f:
        f.write(format_shell_like_config(current))


def load_supported_exchanges() -> list[str]:
    """Load list of supported exchanges from text file."""
    exchanges: list[str] = []
    if not SUPPORTED_EXCHANGES_FILE.exists():
        return exchanges
    with open(SUPPORTED_EXCHANGES_FILE, "r", encoding="utf-8") as f:
        for line in f:
            name = line.strip()
            if name:
                exchanges.append(name)
    return exchanges


def exchange_secrets_paths(exchange: str) -> tuple[Path, Path]:
    """Return file paths for API key and secret for given exchange."""
    SECRETS_DIR.mkdir(parents=True, exist_ok=True)
    api_key_path = SECRETS_DIR / f"api_key-{exchange}"
    api_secret_path = SECRETS_DIR / f"api_secret-{exchange}"
    return api_key_path, api_secret_path


def load_exchange_secrets(exchange: str) -> Dict[str, str]:
    """Load API key/secret for given exchange if available."""
    api_key_path, api_secret_path = exchange_secrets_paths(exchange)
    result: Dict[str, str] = {"API_KEY": "", "API_SECRET": ""}
    if api_key_path.exists():
        with open(api_key_path, "r", encoding="utf-8") as f:
            result["API_KEY"] = f.read().strip()
    if api_secret_path.exists():
        with open(api_secret_path, "r", encoding="utf-8") as f:
            result["API_SECRET"] = f.read().strip()
    return result


def save_exchange_secrets(exchange: str, api_key: str, api_secret: str) -> None:
    """Save API key/secret for given exchange into separate files."""
    api_key_path, api_secret_path = exchange_secrets_paths(exchange)
    with open(api_key_path, "w", encoding="utf-8") as f:
        f.write(api_key.strip() + "\n")
    with open(api_secret_path, "w", encoding="utf-8") as f:
        f.write(api_secret.strip() + "\n")


def load_tickers_for_exchange(exchange: str) -> list[tuple[str, float]]:
    """Load tickers CSV for given exchange, return list of (symbol, price)."""
    tickers_file = TICKERS_DIR / f"CCXT_TICKERS-{exchange}-ALL"
    tickers: list[tuple[str, float]] = []
    if not tickers_file.exists():
        return tickers
    with open(tickers_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(",")
            if len(parts) != 2:
                continue
            symbol = parts[0].strip()
            try:
                price = float(parts[1].strip())
            except ValueError:
                price = 0.0
            tickers.append((symbol, price))
    return tickers


def extract_quote_currency(symbol: str) -> str:
    """Extract quote currency from CCXT symbol like 'MINA/USDT:USDT'."""
    if ":" in symbol:
        symbol = symbol.split(":", 1)[0]
    if "/" in symbol:
        return symbol.split("/")[1]
    return ""


import subprocess
import os
from pathlib import Path

def load_economy_assets() -> list[str]:
    """Load economy assets exactly like: ls -1 .../ECONOMY_*.csv | cut -d/ -f6 | cut -d. -f1 | sed 's/ECONOMY_//' | sort -u"""
    path = Path("/dabo/htdocs/botdata/asset-histories")
    if not path.exists():
        return []
    
    assets = []
    for csv_file in path.glob("ECONOMY_*.csv"):
        # cut -d/ -f6 → basename
        basename = csv_file.name  # z.B. "ECONOMY_NASDAQ.csv"
        # cut -d. -f1 → vor erstem .
        filename_without_ext = basename.split('.')[0]  # "ECONOMY_NASDAQ"
        # remove ECONOMY_
        asset_name = filename_without_ext.replace("ECONOMY_", "")
        if asset_name:
            assets.append(asset_name)
    
    return sorted(set(assets))  # sort -u

def load_marketdata_assets() -> list[str]:
    """Load marketdata assets exactly like: ls -1 .../MARKETDATA_*.csv | cut -d/ -f6 | cut -d. -f1 | sed 's/MARKETDATA_//' | sort -u"""
    path = Path("/dabo/htdocs/botdata/asset-histories")
    if not path.exists():
        return []
    
    assets = []
    for csv_file in path.glob("MARKETDATA_*.csv"):
        basename = csv_file.name  # z.B. "MARKETDATA_ALTCOIN_SEASON_INDEX_COINMARKETCAP.csv"
        filename_without_ext = basename.split('.')[0]  # "MARKETDATA_ALTCOIN_SEASON_INDEX_COINMARKETCAP"
        asset_name = filename_without_ext.replace("MARKETDATA_", "")
        if asset_name:
            assets.append(asset_name)
    
    return sorted(set(assets))  # sort -u


LSTM_FIELDS = [
    (1, "date"),
    (2, "open"), (3, "high"), (4, "low"), (5, "close"),
    (6, "volume"), (7, "change"), (8, "ath"),
    (9, "ema12"), (10, "ema26"), (11, "ema50"),
    (12, "ema100"), (13, "ema200"), (14, "ema400"),
    (15, "ema800"),
    (16, "rsi5"), (17, "rsi14"), (18, "rsi21"),
    (19, "macd"), (20, "macd_ema9_signal"),
    (21, "macd_histogram"), (22, "macd_histogram_signal"),
    (23, "macd_histogram_max"), (24, "macd_histogram_strength"),
]

LSTM_OPTION_FLAGS = [
    "--show_rmse", "--verbose", 
]


