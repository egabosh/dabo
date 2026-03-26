"""
Trades - External Exchanges

This module contains views for managing external exchange positions
from Bitpanda and JustTrade (sub-menu under Trades).
"""

from django.shortcuts import render
from django.http import HttpResponse
from django.views.decorators.http import require_http_methods
import os
import functools

VALUES_DIR = "/dabo/htdocs/botdata"


@functools.lru_cache(maxsize=1)
def fetch_bitpanda_prices():
    """Fetch current prices from Bitpanda API."""
    try:
        import urllib.request
        import json
        url = "https://api.bitpanda.com/v1/ticker"
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode())
    except Exception:
        return {}


def parse_external_positions():
    """Parse external positions from ALL_TRANSACTIONS_OVERVIEW.csv for Bitpanda and JustTrade."""
    csv_file = os.path.join(VALUES_DIR, "ALL_TRANSACTIONS_OVERVIEW.csv")
    if not os.path.exists(csv_file):
        return []
    
    prices = fetch_bitpanda_prices()
    holdings = {}
    
    try:
        with open(csv_file, 'r') as f:
            for line in f:
                parts = line.strip().split(',')
                if len(parts) < 8:
                    continue
                
                exchange = parts[1]
                tx_type = parts[2]
                asset = parts[3]
                amount = parts[4]
                currency = parts[5]
                spent = parts[6]
                
                if exchange not in ('Bitpanda', 'JustTrade'):
                    continue
                
                key = f"{exchange}:{asset}"
                
                try:
                    amount_val = float(amount) if amount else 0
                except ValueError:
                    amount_val = 0
                
                if key not in holdings:
                    holdings[key] = {
                        'exchange': exchange,
                        'asset': asset,
                        'currency': currency,
                        'amount': 0,
                        'spent': 0,
                        'first_date': parts[0],
                    }
                
                holdings[key]['amount'] += amount_val
                
                try:
                    spent_val = float(spent) if spent else 0
                except ValueError:
                    spent_val = 0
                holdings[key]['spent'] += spent_val
                
                if parts[0] < holdings[key]['first_date']:
                    holdings[key]['first_date'] = parts[0]
        
        result = []
        for key, data in holdings.items():
            if data['amount'] > 0.00000001:
                asset = data['asset']
                price_data = prices.get(asset, {})
                current_price = price_data.get('EUR', 0) if isinstance(price_data, dict) else 0
                data['current_price'] = float(current_price) if current_price else 0
                data['current_value'] = data['amount'] * data['current_price']
                data['pnl'] = data['current_value'] + data['spent']
                data['pnl_percent'] = (data['pnl'] / abs(data['spent']) * 100) if data['spent'] != 0 else 0
                result.append(data)
        
        result.sort(key=lambda x: (x['spent'], x['exchange'], x['asset']))
        return result
        
    except Exception:
        return []


def external_positions_view(request):
    """View for external exchange positions (Bitpanda, JustTrade)."""
    external_positions = parse_external_positions()
    
    external_total_spent = sum(p['spent'] for p in external_positions)
    external_total_value = sum(p['current_value'] for p in external_positions)
    external_total_pnl = external_total_value + external_total_spent
    
    return render(request, 'main/external_positions.html', {
        'external_positions': external_positions,
        'external_total_spent': external_total_spent,
        'external_total_value': external_total_value,
        'external_total_pnl': external_total_pnl,
    })
