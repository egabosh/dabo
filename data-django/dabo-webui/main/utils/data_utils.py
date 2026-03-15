"""
Utility functions for reading and parsing CCXT data files securely.
"""
import os
import json
from pathlib import Path
from typing import Dict, List, Any, Optional
from django.http import JsonResponse, HttpResponseBadRequest
from collections import defaultdict

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


def parse_positions(data: str) -> List[Dict[str, Any]]:
    """Parse CCXT positions JSON, filter non-zero contracts."""
    try:
        positions = json.loads(data)
        return [p for p in positions if p.get('contracts', 0) != 0]
    except json.JSONDecodeError:
        return []


def parse_orders(data: str) -> List[List[str]]:
    """Parse CCXT orders CSV."""
    if not data.strip():
        return []
    return [line.split(',') for line in data.strip().split('\n')]


def parse_balance(data: str) -> Dict[str, Any]:
    """Parse CCXT balance JSON."""
    try:
        return json.loads(data)
    except json.JSONDecodeError:
        return {}


def get_top_balances(balance_data: Dict[str, Any], max_assets: int = 5) -> List[Dict[str, float]]:
    """Dynamically find top balances by total value."""
    balances = {}
    
    # Extract from balance.USDT, balance.BTC etc.
    for asset, data in balance_data.items():
        if isinstance(data, dict) and 'total' in data:
            total = float(data['total'] or 0)
            if total > 0:
                balances[asset] = total
    
    # Also check top-level total dict
    if 'total' in balance_data:
        for asset, total_str in balance_data['total'].items():
            total = float(total_str or 0)
            if total > 0:
                balances[asset] = max(balances.get(asset, 0), total)
    
    # Sort by total descending and take top N
    sorted_balances = sorted(balances.items(), key=lambda x: x[1], reverse=True)
    return [{'asset': asset, 'total': total} for asset, total in sorted_balances[:max_assets]]


def get_primary_quote_currency(positions: List[Dict], orders: List[List[str]]) -> str:
    """Dynamically detect primary quote currency from positions and orders."""
    quote_currencies = set()
    
    # From positions
    for pos in positions:
        symbol = pos.get('symbol', '')
        if '/' in symbol:
            quote = symbol.split('/')[1]
            quote_currencies.add(quote)
    
    # From orders
    for order in orders:
        if len(order) > 0:
            symbol = order[0]
            if '/' in symbol:
                quote = symbol.split('/')[1].replace(':USDT', '')
                quote_currencies.add(quote)
    
    # Return most common (or first found)
    return max(quote_currencies, key=list(quote_currencies).count, default='USDT') if quote_currencies else 'USDT'


def get_dashboard_data() -> Dict[str, Any]:
    """Get all dashboard data."""
    positions_raw = read_data_file(DATA_FILES["CCXT_POSITIONS_RAW"])
    orders_raw = read_data_file(DATA_FILES["CCXT_ORDERS"])
    balance_raw = read_data_file(DATA_FILES["CCXT_BALANCE"])
    
    positions = parse_positions(positions_raw or "[]")
    orders = parse_orders(orders_raw or "")
    balance = parse_balance(balance_raw or "{}")
    
    # Dynamic calculations
    quote_currency = get_primary_quote_currency(positions, orders)
    top_balances = get_top_balances(balance)
    
    total_pnl = sum(float(pos.get('unrealizedPnl', 0)) for pos in positions)
    
    # Find largest free balance for "Available" card
    available_balance = 0
    primary_asset = None
    for asset_data in balance.values():
        if isinstance(asset_data, dict) and 'free' in asset_data:
            free = float(asset_data['free'] or 0)
            if free > available_balance:
                available_balance = free
                primary_asset = next((k for k, v in balance.items() if v is asset_data), None)
    
    return {
        "positions": positions,
        "orders": orders,
        "balance": balance,
        "positions_count": len(positions),
        "orders_count": len(orders),
        "quote_currency": quote_currency,
        "top_balances": top_balances,
        "total_pnl": total_pnl,
        "available_balance": available_balance,
        "primary_asset": primary_asset,
    }


def dashboard_data_stream(request):
    """Stream dashboard data as JSON."""
    data = get_dashboard_data()
    return JsonResponse(data)

