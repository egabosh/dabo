"""
Utility functions for reading and parsing CCXT data files securely.

This module provides:
    - Reading CCXT data files (positions, orders, balance)
    - Parsing JSON and CSV data formats
    - Dashboard data aggregation

Data files location: /dabo/htdocs/botdata/
"""

import json
from pathlib import Path
from typing import Dict, List, Any, Optional


# Base directory for data files
DATA_BASE_DIR = Path("/dabo/htdocs/botdata")

DATA_FILES = {
    "CCXT_POSITIONS_RAW": DATA_BASE_DIR / "CCXT_POSITIONS_RAW",
    "CCXT_ORDERS": DATA_BASE_DIR / "CCXT_ORDERS",
    "CCXT_BALANCE": DATA_BASE_DIR / "CCXT_BALANCE",
}


def read_data_file(filepath: Path) -> Optional[str]:
    """Safely read data file content if it exists."""
    if not filepath.exists():
        return None
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception:
        return None


def parse_balance(data: str) -> Dict[str, Any]:
    """Parse CCXT balance JSON."""
    try:
        return json.loads(data)
    except json.JSONDecodeError:
        return {}


def get_top_balances(balance_data: Dict[str, Any], max_assets: int = 5) -> List[Dict[str, float]]:
    """Extract top balances by total value."""
    balances = {}
    
    for asset, asset_data in balance_data.items():
        if isinstance(asset_data, dict) and 'total' in asset_data:
            total = float(asset_data['total'] or 0)
            if total > 0:
                balances[asset] = total
    
    if 'total' in balance_data:
        for asset, total_str in balance_data['total'].items():
            total = float(total_str or 0)
            if total > 0:
                balances[asset] = max(balances.get(asset, 0), total)
    
    sorted_balances = sorted(balances.items(), key=lambda x: x[1], reverse=True)
    return [{'asset': asset, 'total': total} for asset, total in sorted_balances[:max_assets]]
