"""
Trades Views

This module contains views for managing trades:
    - Orders (open orders with cancel functionality)
    - Positions (open positions with close functionality)
    - Cancel/Close individual or all orders/positions
"""

from django.shortcuts import render
from django.http import HttpResponse
from django.views.decorators.http import require_http_methods
import os

VALUES_DIR = "/dabo/htdocs/botdata"


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


def parse_positions(filepath):
    """Parse positions from values-positions file."""
    from collections import defaultdict
    import re
    
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
    from collections import defaultdict
    import re
    
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
