"""
Asset Files Utilities

This module provides functions for listing and categorizing asset history files.
Files are located in: /dabo/htdocs/botdata/asset-histories/

Categories:
    - Economy: Files starting with ECONOMY_ (e.g., ECONOMY_DXY)
    - Market Data: Files starting with MARKETDATA_, BINANCE-, US-
    - Crypto: All other asset files (e.g., BTCUSDT.history.1d.csv)
"""

from pathlib import Path
from typing import List
from collections import defaultdict


ASSET_BASE_DIR = Path("/dabo/htdocs/botdata/asset-histories")


def list_economy_files() -> List[str]:
    """List economy asset files (ECONOMY_* pattern)."""
    if not ASSET_BASE_DIR.exists():
        return []
    files = [f.name for f in ASSET_BASE_DIR.glob("ECONOMY_*history*.csv")]
    return sorted(set([f for f in files if "coinmarketcap" not in f.lower() and "yahoo" not in f.lower()]))


def list_marketdata_files() -> List[str]:
    """List market data files (MARKETDATA_*, BINANCE-*, US-* patterns)."""
    if not ASSET_BASE_DIR.exists():
        return []
    files = []
    files.extend([f.name for f in ASSET_BASE_DIR.glob("MARKETDATA_*history*.csv")])
    files.extend([f.name for f in ASSET_BASE_DIR.glob("BINANCE-*history*.csv")])
    files.extend([f.name for f in ASSET_BASE_DIR.glob("US-*history*.csv")])
    return sorted(set([f for f in files if "coinmarketcap" not in f.lower() and "yahoo" not in f.lower()]))


def list_crypto_files() -> List[str]:
    """List crypto asset files (excluding economy/marketdata)."""
    if not ASSET_BASE_DIR.exists():
        return []
    
    all_files = [f.name for f in ASSET_BASE_DIR.glob("*history*.csv")]
    
    crypto_files = []
    for f in all_files:
        name_lower = f.lower()
        if (not f.startswith("ECONOMY_") and 
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
