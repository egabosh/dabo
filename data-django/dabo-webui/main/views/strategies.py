"""
Strategy Management Views

This module contains views for:
    - Strategy overview listing all strategy files
    - Strategy editor for creating/editing strategies
    - Strategy toggle for activating/deactivating
    - Strategy type toggle for switching between Regular/Manage
    - Strategy variables view showing available bash variables

Strategies are shell scripts located in /dabo/strategies with extensions:
    - .strategy.sh = Active
    - .inactive-strategy.sh, .example-strategy.sh, .template-strategy.sh = Inactive
"""

from django.shortcuts import render, redirect
from django.views.decorators.http import require_http_methods
from django.http import JsonResponse, HttpResponseBadRequest
import os
import re
import glob


STRATEGIES_DIR = "/dabo/strategies"
INACTIVE_SUFFIXES = ['.inactive-strategy.sh', '.example-strategy.sh', '.template-strategy.sh']


def get_strategy_status(filename):
    """Check if a strategy is active or inactive."""
    for suffix in INACTIVE_SUFFIXES:
        if filename.endswith(suffix):
            return 'inactive'
    if filename.endswith('.strategy.sh'):
        return 'active'
    return 'unknown'


def get_base_name(filename):
    """Get the base name without status suffix."""
    for suffix in INACTIVE_SUFFIXES:
        if filename.endswith(suffix):
            return filename[:-len(suffix)]
    return filename.replace('.strategy.sh', '')


def is_manage_strategy(filename):
    """Check if this is a manage strategy (runs every 30 seconds)."""
    base = get_base_name(filename)
    return base.endswith('.manage') or '.manage.' in base


def list_strategies():
    """List all strategies with their status."""
    strategies = {}
    
    if not os.path.exists(STRATEGIES_DIR):
        return strategies
    
    for filepath in glob.glob(os.path.join(STRATEGIES_DIR, "*strategy.sh")):
        filename = os.path.basename(filepath)
        status = get_strategy_status(filename)
        base_name = get_base_name(filename)
        is_manage = is_manage_strategy(filename)
        
        if base_name not in strategies:
            strategies[base_name] = {
                'base_name': base_name,
                'active': None,
                'inactive': None,
                'is_manage': is_manage,
            }
        
        if status == 'active':
            strategies[base_name]['active'] = filename
        else:
            strategies[base_name]['inactive'] = filename
    
    return strategies


def strategies_overview_view(request):
    """Strategies overview page - list all strategies."""
    strategies = list_strategies()
    sorted_strategies = sorted(strategies.values(), key=lambda x: x['base_name'])
    
    return render(request, 'main/strategies_overview.html', {
        'strategies': sorted_strategies,
    })


def strategies_settings_view(request):
    """Strategies settings page - same as overview."""
    return strategies_overview_view(request)


@require_http_methods(["POST"])
def strategy_toggle(request, base_name):
    """Toggle a strategy between active and inactive."""
    strategies = list_strategies()
    
    if base_name not in strategies:
        return HttpResponseBadRequest("Strategy not found")
    
    strategy = strategies[base_name]
    
    if strategy['active'] and strategy['inactive']:
        active_path = os.path.join(STRATEGIES_DIR, strategy['active'])
        inactive_path = os.path.join(STRATEGIES_DIR, strategy['inactive'])
        
        if request.POST.get('action') == 'activate':
            new_active = strategy['inactive'].replace('.inactive-strategy.sh', '.strategy.sh')
            new_path = os.path.join(STRATEGIES_DIR, new_active)
            os.rename(inactive_path, new_path)
            return JsonResponse({'status': 'ok', 'action': 'activated'})
        else:
            new_inactive = strategy['active'].replace('.strategy.sh', '.inactive-strategy.sh')
            new_path = os.path.join(STRATEGIES_DIR, new_inactive)
            os.rename(active_path, new_path)
            return JsonResponse({'status': 'ok', 'action': 'deactivated'})
    elif strategy['active']:
        active_path = os.path.join(STRATEGIES_DIR, strategy['active'])
        new_name = strategy['active'].replace('.strategy.sh', '.inactive-strategy.sh')
        new_path = os.path.join(STRATEGIES_DIR, new_name)
        os.rename(active_path, new_path)
        return JsonResponse({'status': 'ok', 'action': 'deactivated'})
    elif strategy['inactive']:
        inactive_path = os.path.join(STRATEGIES_DIR, strategy['inactive'])
        new_name = strategy['inactive'].replace('.inactive-strategy.sh', '.strategy.sh')
        new_path = os.path.join(STRATEGIES_DIR, new_name)
        os.rename(inactive_path, new_path)
        return JsonResponse({'status': 'ok', 'action': 'activated'})
    
    return HttpResponseBadRequest("Cannot toggle strategy")


@require_http_methods(["GET", "POST"])
def strategy_editor(request, filename=None):
    """Strategy editor - view and edit strategy files."""
    strategies = list_strategies()
    sorted_strategies = sorted(strategies.values(), key=lambda x: x['base_name'])
    
    if request.method == 'GET':
        if filename:
            filepath = os.path.join(STRATEGIES_DIR, filename)
            if not os.path.exists(filepath):
                return HttpResponseBadRequest("File not found")
            
            with open(filepath, 'r') as f:
                content = f.read()
            
            return render(request, 'main/strategy_editor.html', {
                'filename': filename,
                'content': content,
                'strategies': sorted_strategies,
                'is_new': False,
            })
        else:
            return render(request, 'main/strategy_editor.html', {
                'filename': '',
                'content': '#!/bin/bash\n\n# New strategy\n',
                'strategies': sorted_strategies,
                'is_new': True,
            })
    
    elif request.method == 'POST':
        filename = request.POST.get('filename', '').strip()
        content = request.POST.get('content', '')
        new_filename = request.POST.get('new_filename', '').strip()
        strategy_type = request.POST.get('strategy_type', 'regular').strip()
        strategy_status = request.POST.get('strategy_status', 'active').strip()
        
        if not filename and not new_filename:
            return JsonResponse({'error': 'Filename required'}, status=400)
        
        if new_filename:
            filename = new_filename
            
            base = filename
            
            if strategy_type == 'manage' and '.manage.' not in base:
                base = base + '.manage'
            
            if strategy_status == 'inactive':
                filename = base + '.inactive-strategy.sh'
            else:
                filename = base + '.strategy.sh'
        
        filepath = os.path.join(STRATEGIES_DIR, filename)
        
        if not filepath.startswith(STRATEGIES_DIR):
            return JsonResponse({'error': 'Invalid path'}, status=400)
        
        import subprocess
        try:
            result = subprocess.run(
                ['bash', '-n', '-c', content],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode != 0:
                error_msg = result.stderr.strip()
                if error_msg:
                    return JsonResponse({
                        'error': f'Bash syntax error: {error_msg}',
                        'details': error_msg
                    }, status=400)
                return JsonResponse({
                    'error': 'Bash syntax error in script',
                    'details': result.stderr
                }, status=400)
        except subprocess.TimeoutExpired:
            return JsonResponse({'error': 'Syntax check timed out'}, status=400)
        except Exception:
            pass
        
        if not content.startswith('#!'):
            content = '#!/bin/bash\n\n' + content
        
        with open(filepath, 'w') as f:
            f.write(content)
        
        return JsonResponse({'status': 'ok', 'filename': filename})


@require_http_methods(["POST"])
def strategy_delete(request):
    """Delete a strategy (all files for this strategy)."""
    base_name = request.POST.get('base_name', '').strip()
    
    if not base_name:
        return JsonResponse({'error': 'Strategy name required'}, status=400)
    
    deleted = []
    errors = []
    
    for filepath in glob.glob(os.path.join(STRATEGIES_DIR, f"{base_name}*strategy.sh")):
        filename = os.path.basename(filepath)
        try:
            os.remove(filepath)
            deleted.append(filename)
        except Exception as e:
            errors.append(f"{filename}: {str(e)}")
    
    if not deleted and errors:
        return JsonResponse({'error': 'Could not delete: ' + ', '.join(errors)}, status=400)
    
    return JsonResponse({'status': 'ok', 'deleted': deleted})


@require_http_methods(["POST"])
def strategy_toggle_type(request, base_name):
    """Toggle a strategy between Regular and Manage type."""
    strategies = list_strategies()
    
    if base_name not in strategies:
        return HttpResponseBadRequest("Strategy not found")
    
    strategy = strategies[base_name]
    
    current_file = strategy['active'] or strategy['inactive']
    if not current_file:
        return HttpResponseBadRequest("No file found")
    
    current_path = os.path.join(STRATEGIES_DIR, current_file)
    
    if strategy['is_manage']:
        new_base = base_name.replace('.manage', '').replace('.manage', '')
        if new_base == base_name and base_name.endswith('.manage'):
            new_base = base_name[:-7]
        new_file = new_base + '.strategy.sh'
    else:
        new_file = base_name + '.manage.strategy.sh'
    
    new_path = os.path.join(STRATEGIES_DIR, new_file)
    
    if os.path.exists(new_path):
        return JsonResponse({'error': 'Target file already exists'}, status=400)
    
    os.rename(current_path, new_path)
    
    return JsonResponse({'status': 'ok', 'new_type': 'manage' if not strategy['is_manage'] else 'regular'})


def strategy_variables_view(request):
    """View available bash variables for strategies."""
    VALUES_DIR = "/dabo/htdocs/botdata"
    
    TF_ORDER = ['1w', '1d', '4h', '1h', '30m', '15m', '5m', '1M', '12h', '2d', '7d']
    
    def parse_indicator(indicator):
        """Extract base indicator type like ema, rsi, macd from full indicator name."""
        if not indicator:
            return None
        parts = indicator.split('_')
        return parts[0].lower() if parts else indicator.lower()
    
    def parse_var(inner):
        """Parse variable and determine category and components."""
        if not inner:
            return None, None, None, None, None
        
        if inner.endswith('_price'):
            return inner[:-6], None, None, 'PRICE', inner
        
        for tf in TF_ORDER:
            suffix = '_' + tf + '_'
            if suffix in inner:
                idx = inner.index(suffix)
                prefix_part = inner[:idx]
                indicator = inner[idx+len(suffix):]
                
                if inner.startswith('ECONOMY_'):
                    return prefix_part, tf, indicator, 'ECONOMY', inner
                elif inner.startswith('MARKETDATA_'):
                    return prefix_part, tf, indicator, 'MARKETDATA', inner
                else:
                    return prefix_part, tf, indicator, 'CRYPTO', inner
        
        if inner.startswith('ECONOMY_'):
            return inner, None, None, 'ECONOMY', inner
        elif inner.startswith('MARKETDATA_'):
            return inner, None, None, 'MARKETDATA', inner
        else:
            return inner, None, None, 'META', inner
    
    categories = {
        'PRICE': {'items': [], 'by_symbol': {}},
        'CRYPTO': {'by_timeframe': {}, 'symbols': set()},
        'ECONOMY': {'by_timeframe': {}, 'symbols': set()},
        'MARKETDATA': {'by_timeframe': {}, 'symbols': set()},
        'META': {'items': []},
    }
    
    all_indicators = set()
    all_timeframes = set()
    
    values_file = os.path.join(VALUES_DIR, "values")
    if os.path.exists(values_file):
        try:
            with open(values_file, 'r') as f:
                for line in f:
                    if '=' not in line:
                        continue
                    parts = line.strip().split('=', 1)
                    if len(parts) != 2:
                        continue
                    var_expr = parts[0].strip()
                    value = parts[1].strip()
                    match = re.match(r'^\$\{v\[([^\]]+)\]\}$', var_expr)
                    if not match:
                        continue
                    inner = match.group(1)
                    
                    symbol, tf, indicator, cat, full_inner = parse_var(inner)
                    base_ind = parse_indicator(indicator)
                    if base_ind:
                        all_indicators.add(base_ind)
                    
                    item = {'var': var_expr, 'inner': full_inner, 'symbol': symbol, 'timeframe': tf, 'indicator': indicator, 'value': value}
                    
                    if cat == 'PRICE':
                        categories['PRICE']['items'].append(item)
                        categories['PRICE']['by_symbol'][symbol] = item
                    elif cat in ('CRYPTO', 'ECONOMY', 'MARKETDATA'):
                        if tf not in categories[cat]['by_timeframe']:
                            categories[cat]['by_timeframe'][tf] = []
                        categories[cat]['by_timeframe'][tf].append(item)
                        categories[cat]['symbols'].add(symbol)
                        if tf:
                            all_timeframes.add(tf)
                    else:
                        categories['META']['items'].append(item)
        except Exception:
            pass
    
    categories['ORDERS'] = {'by_symbol': {}}
    orders_file = os.path.join(VALUES_DIR, "values-orders")
    if os.path.exists(orders_file):
        try:
            with open(orders_file, 'r') as f:
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
                    symbol = inner.split('_')[0] if '_' in inner else inner
                    
                    if symbol not in categories['ORDERS']['by_symbol']:
                        categories['ORDERS']['by_symbol'][symbol] = []
                    categories['ORDERS']['by_symbol'][symbol].append({
                        'var': var_expr, 'inner': inner, 'value': value
                    })
        except Exception:
            pass
    
    categories['POSITIONS'] = {'by_symbol': {}}
    positions_file = os.path.join(VALUES_DIR, "values-positions")
    if os.path.exists(positions_file):
        try:
            with open(positions_file, 'r') as f:
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
                    symbol = inner.split('_')[0] if '_' in inner else inner
                    
                    if symbol not in categories['POSITIONS']['by_symbol']:
                        categories['POSITIONS']['by_symbol'][symbol] = []
                    categories['POSITIONS']['by_symbol'][symbol].append({
                        'var': var_expr, 'inner': inner, 'value': value
                    })
        except Exception:
            pass
    
    def sort_timeframes(tfs):
        return sorted(tfs, key=lambda x: TF_ORDER.index(x) if x in TF_ORDER else 99)
    
    for cat in ['CRYPTO', 'ECONOMY', 'MARKETDATA']:
        for tf in categories[cat]['by_timeframe']:
            categories[cat]['by_timeframe'][tf].sort(key=lambda x: (x['symbol'], x['indicator']))
    
    for sym in categories['ORDERS']['by_symbol']:
        categories['ORDERS']['by_symbol'][sym].sort(key=lambda x: x['inner'])
    for sym in categories['POSITIONS']['by_symbol']:
        categories['POSITIONS']['by_symbol'][sym].sort(key=lambda x: x['inner'])
    
    counts = {
        'PRICE': len(categories['PRICE']['items']),
        'CRYPTO': sum(len(v) for v in categories['CRYPTO']['by_timeframe'].values()),
        'ECONOMY': sum(len(v) for v in categories['ECONOMY']['by_timeframe'].values()),
        'MARKETDATA': sum(len(v) for v in categories['MARKETDATA']['by_timeframe'].values()),
        'ORDERS': sum(len(v) for v in categories['ORDERS']['by_symbol'].values()),
        'POSITIONS': sum(len(v) for v in categories['POSITIONS']['by_symbol'].values()),
    }
    
    all_indicators = sorted(all_indicators)
    all_timeframes = sort_timeframes(all_timeframes)
    
    total_count = sum(counts.values())
    
    return render(request, 'main/strategy_variables.html', {
        'categories': categories,
        'counts': counts,
        'all_indicators': all_indicators,
        'all_timeframes': all_timeframes,
        'total_count': total_count,
        'tf_order': TF_ORDER,
    })
    if os.path.exists(orders_file):
        try:
            with open(orders_file, 'r') as f:
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
                    
                    all_variables.append({
                        'prefix': 'o',
                        'var': var_expr,
                        'inner': inner,
                        'symbol': inner.split('_')[0] if '_' in inner else inner,
                        'category': 'ORDER',
                        'indicator': None,
                        'value': value,
                        'var_type': 'ORDER',
                    })
        except Exception:
            pass
    
    positions_file = os.path.join(VALUES_DIR, "values-positions")
    if os.path.exists(positions_file):
        try:
            with open(positions_file, 'r') as f:
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
                    
                    all_variables.append({
                        'prefix': 'p',
                        'var': var_expr,
                        'inner': inner,
                        'symbol': inner.split('_')[0] if '_' in inner else inner,
                        'category': 'POSITION',
                        'indicator': None,
                        'value': value,
                        'var_type': 'POSITION',
                    })
        except Exception:
            pass
    
    all_variables.sort(key=lambda x: (x['prefix'], x['symbol'] or '', x['category'] or '', x['indicator'] or ''))
    symbols = sorted(symbols)
    timeframes = sorted(timeframes, key=lambda x: ['1w', '1d', '4h', '1h', '30m', '15m', '5m'].index(x) if x in ['1w', '1d', '4h', '1h', '30m', '15m', '5m'] else 99)
    indicator_types = sorted(indicator_types)
    
    return render(request, 'main/strategy_variables.html', {
        'variables': all_variables,
        'symbols': symbols,
        'timeframes': timeframes,
        'indicator_types': indicator_types,
        'total_count': len(all_variables),
    })
