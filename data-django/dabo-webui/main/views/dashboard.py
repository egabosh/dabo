"""
Dashboard and Data Views

This module contains views for:
    - Main dashboard page showing positions and orders
    - Data overview page with categorized asset files (crypto, economy, marketdata)
    - Data chart page for viewing historical price/indicator data
    - Asset history file serving for chart data
"""

from django.shortcuts import render
from django.http import HttpResponse
from django.views.decorators.http import require_http_methods
from django.http import Http404
import os
import csv
import re
import glob
from collections import defaultdict


VALUES_DIR = "/dabo/htdocs/botdata"


def get_healthcheck_summary():
    """Get healthcheck errors and warnings."""
    errors = []
    warnings = []
    seen = set()
    
    pattern = os.path.join(VALUES_DIR, "HEALTH_*")
    files = glob.glob(pattern)
    
    for filepath in sorted(files):
        try:
            with open(filepath, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    
                    parts = line.split(':', 2)
                    if len(parts) < 3:
                        continue
                    
                    status = parts[0].strip()
                    program_func = parts[1].strip()
                    message = parts[2].strip()
                    
                    key = (status, program_func, message)
                    if key in seen:
                        continue
                    seen.add(key)
                    
                    if status == 'ERROR':
                        errors.append({
                            'program_func': program_func,
                            'message': message,
                        })
                    elif status == 'WARN':
                        warnings.append({
                            'program_func': program_func,
                            'message': message,
                        })
        except Exception:
            pass
    
    return errors, warnings


def dashboard(request):
    """Main dashboard page - reads positions and orders from values files."""
    positions = []
    orders = []
    
    positions_file = os.path.join(VALUES_DIR, "values-positions")
    if os.path.exists(positions_file):
        positions = parse_positions(positions_file)
    
    orders_file = os.path.join(VALUES_DIR, "values-orders")
    if os.path.exists(orders_file):
        orders = parse_orders(orders_file)
    
    total_pnl = sum(float(p.get('pnl', 0)) for p in positions if p.get('pnl'))
    
    config = load_config()
    currency = config.get('CURRENCY', 'USDT')
    symbols = config.get('SYMBOLS', '').split()
    margin_mode = config.get('MARGIN_MODE', 'spot')
    leverage = config.get('LEVERAGE', '1')
    
    balance_complete = 0
    balance_free = 0
    balance_used = 0
    balance_file = os.path.join(VALUES_DIR, "CCXT_BALANCE")
    if os.path.exists(balance_file):
        try:
            with open(balance_file, 'r') as f:
                parts = f.read().strip().split(',')
                if len(parts) == 3:
                    balance_complete = float(parts[0])
                    balance_free = float(parts[1])
                    balance_used = float(parts[2])
        except Exception:
            pass
    
    healthcheck_errors, healthcheck_warnings = get_healthcheck_summary()
    
    return render(request, 'main/dashboard.html', {
        'positions': positions,
        'orders': orders,
        'total_pnl': total_pnl,
        'currency': currency,
        'symbols': symbols,
        'margin_mode': margin_mode,
        'leverage': leverage,
        'balance_complete': balance_complete,
        'balance_free': balance_free,
        'balance_used': balance_used,
        'healthcheck_errors': healthcheck_errors,
        'healthcheck_warnings': healthcheck_warnings,
    })


def load_config():
    """Load effective config."""
    config = {}
    for path in ['/dabo/dabo-bot.conf', '/dabo/dabo-bot.override.conf']:
        if os.path.exists(path):
            try:
                with open(path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        if '=' in line:
                            key, value = line.split('=', 1)
                            key = key.strip()
                            value = value.strip().strip('"').strip("'")
                            config[key] = value
            except Exception:
                pass
    return config


def get_currency_price(currency):
    """Get currency price from values file."""
    price_file = os.path.join(VALUES_DIR, "values")
    if os.path.exists(price_file):
        try:
            with open(price_file, 'r') as f:
                for line in f:
                    if f'{currency}_price]' in line:
                        parts = line.strip().split('=', 1)
                        if len(parts) == 2:
                            return parts[1].strip()
        except Exception:
            pass
    return '0.00'


def get_currency_balance():
    """Calculate total currency balance from positions."""
    positions_file = os.path.join(VALUES_DIR, "values-positions")
    total = 0.0
    
    if os.path.exists(positions_file):
        try:
            with open(positions_file, 'r') as f:
                for line in f:
                    if 'currency_amount]' in line:
                        parts = line.strip().split('=', 1)
                        if len(parts) == 2:
                            try:
                                total += float(parts[1].strip())
                            except ValueError:
                                pass
        except Exception:
            pass
    
    return f"{total:.2f}"


def parse_positions(filepath):
    """Parse positions from values-positions file."""
    positions = defaultdict(dict)
    
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if '=' not in line:
                    continue
                parts = line.strip().split('=', 1)
                if len(parts) != 2:
                    continue
                
                var_expr = parts[0].strip()
                value = parts[1].strip()
                
                match = re.match(r'^\$\{p\[([^\]]+)\]\}$', var_expr)
                if not match:
                    continue
                
                inner = match.group(1)
                m = re.match(r'^([A-Z]+USDT)_(.+)$', inner)
                if m:
                    symbol = m.group(1)
                    field = m.group(2)
                    positions[symbol][field] = value
    except Exception:
        pass
    
    result = []
    for symbol, data in positions.items():
        result.append({
            'symbol': symbol,
            'asset_amount': data.get('asset_amount', ''),
            'currency_amount': data.get('currency_amount', ''),
            'entry_price': data.get('entry_price', ''),
            'current_price': data.get('current_price', ''),
            'liquidation_price': data.get('liquidation_price', ''),
            'leverage': data.get('leverage', ''),
            'side': data.get('side', ''),
            'pnl': data.get('pnl', ''),
            'pnl_percentage': data.get('pnl_percentage', ''),
            'unrealized_pnl': data.get('unrealized_pnl', ''),
            'realized_pnl': data.get('realized_pnl', ''),
            'breakeven_price': data.get('breakeven_price', ''),
        })
    
    return sorted(result, key=lambda x: x['symbol'])


def parse_orders(filepath):
    """Parse orders from values-orders file."""
    orders = defaultdict(dict)
    
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if '=' not in line:
                    continue
                parts = line.strip().split('=', 1)
                if len(parts) != 2:
                    continue
                
                var_expr = parts[0].strip()
                value = parts[1].strip()
                
                match = re.match(r'^\$\{o\[([^\]]+)\]\}$', var_expr)
                if not match:
                    continue
                
                inner = match.group(1)
                m = re.match(r'^([A-Z]+USDT)_(\d+)_(.+)$', inner)
                if m:
                    symbol = m.group(1)
                    order_id = m.group(2)
                    field = m.group(3)
                    key = f"{symbol}_{order_id}"
                    orders[key][field] = value
                    orders[key]['symbol'] = symbol
                    orders[key]['order_id'] = order_id
    except Exception:
        pass
    
    result = []
    for key, data in orders.items():
        result.append({
            'symbol': data.get('symbol', ''),
            'order_id': data.get('order_id', ''),
            'id': data.get('id', ''),
            'type': data.get('type', ''),
            'side': data.get('side', ''),
            'amount': data.get('amount', ''),
            'entry_price': data.get('entry_price', ''),
            'stop_price': data.get('stopprice', ''),
            'stop_loss': data.get('stoplossprice', ''),
            'take_profit': data.get('takeprofitprice', ''),
        })
    
    return sorted(result, key=lambda x: (x['symbol'], x['order_id']))


def history_stream(request):
    """Stream endpoint for dashboard data (positions, orders, balance) as JSON."""
    from django.http import JsonResponse
    from ..utils.data_utils import read_data_file, DATA_FILES, parse_balance, get_top_balances
    
    positions_raw = read_data_file(DATA_FILES["CCXT_POSITIONS_RAW"])
    orders_raw = read_data_file(DATA_FILES["CCXT_ORDERS"])
    balance_raw = read_data_file(DATA_FILES["CCXT_BALANCE"])
    
    positions = []
    if positions_raw:
        import json
        try:
            positions = json.loads(positions_raw)
        except:
            pass
    
    orders = []
    if orders_raw:
        orders = [line.split(',') for line in orders_raw.strip().split('\n') if line]
    
    balance = parse_balance(balance_raw or "{}")
    top_balances = get_top_balances(balance)
    total_pnl = sum(float(p.get('unrealizedPnl', 0)) for p in positions if p.get('unrealizedPnl'))
    
    available_balance = 0
    primary_asset = None
    for asset_data in balance.values():
        if isinstance(asset_data, dict) and 'free' in asset_data:
            free = float(asset_data['free'] or 0)
            if free > available_balance:
                available_balance = free
                primary_asset = next((k for k, v in balance.items() if v is asset_data), None)
    
    return JsonResponse({
        "positions": positions,
        "orders": orders,
        "balance": balance,
        "positions_count": len(positions),
        "orders_count": len(orders),
        "top_balances": top_balances,
        "total_pnl": total_pnl,
        "available_balance": available_balance,
        "primary_asset": primary_asset,
    })


def data_overview_view(request):
    """Data overview page showing available market, economy and crypto data."""
    from ..utils.data_files_utils import (
        list_economy_files,
        list_marketdata_files,
        list_crypto_files,
    )
    
    marketdata_files = list_marketdata_files()
    economy_files = list_economy_files()
    crypto_files = list_crypto_files()

    marketdata_symbols = _get_unique_symbols(marketdata_files)
    economy_symbols = _get_unique_symbols(economy_files)
    crypto_symbols = _get_unique_symbols(crypto_files)

    return render(request, 'main/data_overview.html', {
        'marketdata_symbols': marketdata_symbols,
        'economy_symbols': economy_symbols, 
        'crypto_symbols': crypto_symbols,
    })


def data_chart_view(request):
    """Data chart page for viewing historical data."""
    from django.http import Http404
    from ..utils.data_files_utils import (
        list_economy_files,
        list_marketdata_files,
        list_crypto_files,
    )
    
    filename = request.GET.get('file')
    if not filename:
        raise Http404('No file specified')

    if '/' in filename or '..' in filename:
        raise Http404('Invalid file')

    parts = filename.split('.history.')
    if len(parts) != 2:
        raise Http404('Invalid file format: expected SYMBOL.history.TIME.csv')
    
    symbol_raw = parts[0]
    timeframe = parts[1].replace('.csv', '')

    marketdata_files = list_marketdata_files()
    economy_files = list_economy_files()
    crypto_files = list_crypto_files()
    
    marketdata_symbols = _get_unique_symbols(marketdata_files)
    economy_symbols = _get_unique_symbols(economy_files)
    crypto_symbols = _get_unique_symbols(crypto_files)
    
    # Check category based on symbol prefix
    in_market = symbol_raw.startswith('MARKETDATA_') or symbol_raw.startswith('BINANCE-') or symbol_raw.startswith('US-')
    in_economy = symbol_raw.startswith('ECONOMY_')
    in_crypto = not in_market and not in_economy
    
    return render(request, 'main/data_chart.html', {
        'symbol': symbol_raw,
        'symbol_display': symbol_raw.replace('_', ' ').replace('-', ' ').title(),
        'timeframe': timeframe,
        'filename': filename,
        'timeframes': ['1d', '4h', '1h', '15m', '5m', '1w'],
        'marketdata_symbols': marketdata_symbols,
        'economy_symbols': economy_symbols,
        'crypto_symbols': crypto_symbols,
        'in_marketdata': in_market,
        'in_economy': in_economy,
        'in_crypto': in_crypto,
        'marketdata_raw_symbols': [f.split('.history.')[0] for f in marketdata_files],
        'economy_raw_symbols': [f.split('.history.')[0] for f in economy_files],
        'crypto_raw_symbols': [f.split('.history.')[0] for f in crypto_files],
    })


def serve_asset_history(request, filename):
    """Serve CSV files from /dabo/htdocs/botdata/asset-histories/."""
    from django.http import HttpResponse, Http404
    from django.views.decorators.http import require_GET
    
    filepath = os.path.join('/dabo/htdocs/botdata/asset-histories', filename)
    
    if '..' in filename or not os.path.exists(filepath):
        raise Http404(f'File not found: {filename}')
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        raise Http404(f'Cannot read file: {filename}')
    
    response = HttpResponse(content, content_type='text/csv')
    response['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    response['Pragma'] = 'no-cache'
    return response


def _get_unique_symbols(files):
    """Extract unique symbols with their available timeframes."""
    symbols = defaultdict(list)
    for filename in files:
        symbol = filename.split('.history.')[0]
        if symbol.startswith('MARKETDATA_'):
            display_name = symbol[11:].replace('_', ' ').title()
        elif symbol.startswith('ECONOMY_'):
            display_name = symbol[8:].replace('-', ' ').title()
        else:
            display_name = symbol.upper()
        symbols[display_name].append(filename)
    return dict(symbols)


# =============================================================================
# Trades View - Orders and Positions Management
# =============================================================================

def trades_view(request):
    """Trades page showing orders and positions with cancel functionality."""
    positions = []
    orders = []
    
    positions_file = os.path.join(VALUES_DIR, "values-positions")
    if os.path.exists(positions_file):
        positions = parse_positions(positions_file)
    
    orders_file = os.path.join(VALUES_DIR, "values-orders")
    if os.path.exists(orders_file):
        orders = parse_orders(orders_file)
    
    return render(request, 'main/trades.html', {
        'positions': positions,
        'orders': orders,
    })


@require_http_methods(["POST"])
def cancel_order(request):
    """Cancel an order by writing to webcontrol file."""
    symbol = request.POST.get('symbol', '').strip()
    order_id = request.POST.get('order_id', '').strip()
    
    if not order_id:
        return HttpResponse('Order ID required', status=400)
    
    webcontrol_file = os.path.join(VALUES_DIR, "webcontrol")
    command = f'order-cancel:{symbol}:{order_id}'
    
    try:
        existing = []
        if os.path.exists(webcontrol_file):
            with open(webcontrol_file, 'r') as f:
                existing = f.readlines()
        
        if command + '\n' not in existing:
            with open(webcontrol_file, 'a') as f:
                f.write(command + '\n')
        
        return HttpResponse('Order cancellation requested')
    except Exception as e:
        return HttpResponse(f'Error: {str(e)}', status=500)


@require_http_methods(["POST"])
def cancel_position(request):
    """Cancel/close a position by writing to webcontrol file."""
    symbol = request.POST.get('symbol', '').strip()
    
    if not symbol:
        return HttpResponse('Symbol required', status=400)
    
    webcontrol_file = os.path.join(VALUES_DIR, "webcontrol")
    command = f'position-close:{symbol}'
    
    try:
        existing = []
        if os.path.exists(webcontrol_file):
            with open(webcontrol_file, 'r') as f:
                existing = f.readlines()
        
        if command + '\n' not in existing:
            with open(webcontrol_file, 'a') as f:
                f.write(command + '\n')
        
        return HttpResponse('Position close requested')
    except Exception as e:
        return HttpResponse(f'Error: {str(e)}', status=500)


@require_http_methods(["POST"])
def cancel_all_orders(request):
    """Cancel all open orders by writing to webcontrol file."""
    webcontrol_file = os.path.join(VALUES_DIR, "webcontrol")
    command = 'order-cancel:ALL'
    
    try:
        existing = []
        if os.path.exists(webcontrol_file):
            with open(webcontrol_file, 'r') as f:
                existing = f.readlines()
        
        if command + '\n' not in existing:
            with open(webcontrol_file, 'a') as f:
                f.write(command + '\n')
        
        return HttpResponse('Cancel all orders requested')
    except Exception as e:
        return HttpResponse(f'Error: {str(e)}', status=500)


@require_http_methods(["POST"])
def close_all_positions(request):
    """Close all open positions by writing to webcontrol file."""
    webcontrol_file = os.path.join(VALUES_DIR, "webcontrol")
    command = 'position-close:ALL'
    
    try:
        existing = []
        if os.path.exists(webcontrol_file):
            with open(webcontrol_file, 'r') as f:
                existing = f.readlines()
        
        if command + '\n' not in existing:
            with open(webcontrol_file, 'a') as f:
                f.write(command + '\n')
        
        return HttpResponse('Close all positions requested')
    except Exception as e:
        return HttpResponse(f'Error: {str(e)}', status=500)
