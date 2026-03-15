from pathlib import Path
from typing import List
from collections import defaultdict

ASSET_BASE_DIR = Path("/dabo/htdocs/botdata/asset-histories")

def list_economy_files() -> List[str]:
    """Nur explizit ECONOMY-*."""
    if not ASSET_BASE_DIR.exists():
        return []
    files = [f.name for f in ASSET_BASE_DIR.glob("ECONOMY-*history*.csv")]
    return sorted(set([f for f in files if "coinmarketcap" not in f.lower() and "yahoo" not in f.lower()]))

def list_marketdata_files() -> List[str]:
    """Nur explizit MARKETDATA_*."""
    if not ASSET_BASE_DIR.exists():
        return []
    files = []
    # MARKETDATA_*
    files.extend([f.name for f in ASSET_BASE_DIR.glob("MARKETDATA_*history*.csv")])
    # BINANCE_*
    files.extend([f.name for f in ASSET_BASE_DIR.glob("BINANCE-*history*.csv")])
    # US_*
    files.extend([f.name for f in ASSET_BASE_DIR.glob("US-*history*.csv")])
    return sorted(set([f for f in files if "coinmarketcap" not in f.lower() and "yahoo" not in f.lower()]))

def list_crypto_files() -> List[str]:
    """ALLES was NICHT Economy/Marketdata/coinmarketcap/yahoo ist."""
    if not ASSET_BASE_DIR.exists():
        return []
    
    all_files = [f.name for f in ASSET_BASE_DIR.glob("*history*.csv")]
    
    crypto_files = []
    for f in all_files:
        name_lower = f.lower()
        # EXPLIZIT AUSSCHLIESSEN
        if (not f.startswith("ECONOMY-") and 
            not f.startswith("MARKETDATA_") and
            "economy" not in name_lower and
            "binance-" not in name_lower and
            "us-" not in name_lower and 
            "marketdata" not in name_lower and
            ".history-raw.csv" not in name_lower and
            "coinmarketcap" not in name_lower and 
            "yahoo" not in name_lower):
            crypto_files.append(f)
    
    return sorted(set(crypto_files))

def get_unique_symbols(files):
    """Extract unique symbols with their available timeframes."""
    symbols = defaultdict(list)
    for filename in files:
        symbol_part = filename.split(".history.")[0]
        if symbol_part.startswith("MARKETDATA_"):
            display_name = symbol_part[11:].replace("_", " ").title()
        elif symbol_part.startswith("ECONOMY-"):
            display_name = symbol_part[8:].replace("-", " ").title()
        else:
            display_name = symbol_part.upper()
        symbols[display_name].append(filename)
    return dict(symbols)

