"""
Settings Views

This module contains views for bot configuration:
    - General settings (URL, interval, debug, testnet)
    - Exchange settings (API keys, trading pairs)
    - Trade settings (stop loss, take profit, etc.)
    - AI settings

Configuration is stored in shell-style config files with KEY="VALUE" format.
"""

from django.shortcuts import render, redirect
from django.views.decorators.http import require_http_methods
from ..utils.config_utils import (
    load_effective_config,
    save_override_config,
    load_supported_exchanges,
    load_exchange_secrets,
    save_exchange_secrets,
    load_tickers_for_exchange,
    extract_quote_currency,
    load_economy_assets,
    load_marketdata_assets,
    LSTM_FIELDS,
)


def settings_view(request):
    """Settings main page."""
    return render(request, 'main/settings.html')


@require_http_methods(['GET', 'POST'])
def settings_general_view(request):
    """General settings page."""
    effective_cfg = load_effective_config()

    if request.method == 'POST':
        new_values = {
            'URL': request.POST.get('URL', effective_cfg.get('URL', '')),
            'INTERVAL': request.POST.get('INTERVAL', effective_cfg.get('INTERVAL', '300')),
            'DEBUG': 'true' if request.POST.get('DEBUG') == 'on' else 'false',
            'TESTNET': 'true' if request.POST.get('TESTNET') == 'on' else 'false',
        }
        save_override_config(new_values)
        return redirect('settings_general')

    return render(request, 'main/settings_general.html', {'config': effective_cfg})


@require_http_methods(['GET', 'POST'])
def settings_exchange_view(request):
    """Exchange settings page."""
    effective_cfg = load_effective_config()
    supported_exchanges = load_supported_exchanges()
    current_exchange = effective_cfg.get('STOCK_EXCHANGE', 'NONE')

    exchange_secrets = {}
    if current_exchange and current_exchange != 'NONE':
        exchange_secrets = load_exchange_secrets(current_exchange)

    if request.method == 'POST':
        selected_exchange = request.POST.get('STOCK_EXCHANGE', 'NONE')
        api_key = request.POST.get('API_KEY', '')
        api_secret = request.POST.get('API_SECRET', '')

        new_values = {'STOCK_EXCHANGE': selected_exchange}
        save_override_config(new_values)

        if selected_exchange != 'NONE' and api_key and api_secret:
            save_exchange_secrets(selected_exchange, api_key, api_secret)

        return redirect('settings_exchange')

    return render(request, 'main/settings_exchange.html', {
        'config': effective_cfg,
        'supported_exchanges': supported_exchanges,
        'current_exchange': current_exchange,
        'exchange_secrets': exchange_secrets,
    })


@require_http_methods(['GET', 'POST'])
def settings_trade_view(request):
    """Trade settings page."""
    effective_cfg = load_effective_config()
    exchange = effective_cfg.get('STOCK_EXCHANGE', 'NONE')
    current_currency = effective_cfg.get('CURRENCY', '')

    tickers = []
    available_quote_currencies = set()
    currency_filtered_symbols = []

    if exchange and exchange != 'NONE':
        tickers = load_tickers_for_exchange(exchange)
        
        for symbol, _price in tickers:
            quote = extract_quote_currency(symbol)
            if quote:
                available_quote_currencies.add(quote)
        
        if current_currency:
            for symbol, _price in tickers:
                quote = extract_quote_currency(symbol)
                if quote == current_currency:
                    base_symbol = symbol
                    if ':' in base_symbol:
                        base_symbol = base_symbol.split(':', 1)[0]
                    if '/' in base_symbol:
                        base_symbol = base_symbol.split('/', 1)[0]
                    if base_symbol not in currency_filtered_symbols:
                        currency_filtered_symbols.append(base_symbol)
        else:
            for symbol, _price in tickers:
                base_symbol = symbol
                if ':' in base_symbol:
                    base_symbol = base_symbol.split(':', 1)[0]
                if '/' in base_symbol:
                    base_symbol = base_symbol.split('/', 1)[0]
                if base_symbol not in currency_filtered_symbols:
                    currency_filtered_symbols.append(base_symbol)

    if not available_quote_currencies:
        available_quote_currencies.add('USDT')
    if not currency_filtered_symbols:
        default_symbols = effective_cfg.get('SYMBOLS', '').split()
        currency_filtered_symbols.extend([s.strip() for s in default_symbols if s.strip()])

    if request.method == 'POST':
        selected_currency = request.POST.get('CURRENCY', current_currency or 'USDT')
        selected_symbols = request.POST.getlist('SYMBOLS')
        
        if not selected_symbols:
            selected_symbols = effective_cfg.get('SYMBOLS', '').split()

        new_values = {
            'CURRENCY': selected_currency,
            'SYMBOLS': ' '.join(selected_symbols),
            'LEVERAGE': request.POST.get('LEVERAGE', effective_cfg.get('LEVERAGE', '2')),
            'MARGIN_MODE': request.POST.get('MARGIN_MODE', effective_cfg.get('MARGIN_MODE', 'isolated')),
        }
        save_override_config(new_values)
        return redirect('settings_trade')

    return render(request, 'main/settings_trade.html', {
        'config': effective_cfg,
        'exchange': exchange,
        'current_currency': current_currency,
        'available_quote_currencies': sorted(available_quote_currencies),
        'available_symbols': sorted(currency_filtered_symbols),
    })


@require_http_methods(['GET', 'POST'])
def settings_ai_view(request):
    """AI/LSTM settings page."""
    effective_cfg = load_effective_config()
    dolstm_enabled = effective_cfg.get('DOLSTM', 'false').lower() == 'true'
    
    DEFAULT_LSTM_FIELDS = '5,6,11,13,17,21'
    DEFAULT_LSTM_ECO = 'NASDAQ SP500 DOWJONES DXY KRE'
    DEFAULT_LSTM_MARKET = (
        'ALTCOIN_SEASON_INDEX_COINMARKETCAP '
        'BINANCE_LONG_SHORT_RATIO_ACCOUNT_ '
        'BINANCE_LONG_SHORT_RATIO_TAKER_ '
        'BINANCE_OPEN_INTEREST_ '
        'FEAR_AND_GREED_ALTERNATIVEME '
        'FEAR_AND_GREED_CNN '
        'FEAR_AND_GREED_COINMARKETCAP '
        'US_CONSUMER_PRICE_INDEX_CPI '
        'US_FED_FUNDS_RATE '
        'US_UNEMPLOYMENT_RATE'
    )

    economy_assets = load_economy_assets()
    marketdata_assets = load_marketdata_assets()
    
    lstm_fields_str = effective_cfg.get('LSTM_USE_FIELDS', DEFAULT_LSTM_FIELDS)
    selected_lstm_fields = set(int(x.strip()) for x in lstm_fields_str.split(',') if x.strip())

    lstm_eco_str = effective_cfg.get('LSTM_USE_ECO_ASSETS', DEFAULT_LSTM_ECO)
    selected_eco_assets = set(x.strip() for x in lstm_eco_str.split() if x.strip())

    lstm_market_str = effective_cfg.get('LSTM_USE_MARKETDATA', DEFAULT_LSTM_MARKET)
    selected_market_assets = set(x.strip() for x in lstm_market_str.split() if x.strip())
    
    lstm_options_str = effective_cfg.get('LSTM_OPTIONS', '--show_rmse --verbose 1')
    
    if request.method == 'POST':
        new_values = {}
        
        new_values['DOLSTM'] = 'true' if request.POST.get('DOLSTM') == 'on' else 'false'
        
        selected_fields = []
        for num_str in request.POST.getlist('LSTM_USE_FIELDS'):
            try:
                selected_fields.append(num_str)
            except ValueError:
                pass
        new_values['LSTM_USE_FIELDS'] = ','.join(selected_fields) if selected_fields else DEFAULT_LSTM_FIELDS
        
        selected_eco = request.POST.getlist('LSTM_USE_ECO_ASSETS')
        new_values['LSTM_USE_ECO_ASSETS'] = ' '.join(selected_eco) if selected_eco else DEFAULT_LSTM_ECO
        
        selected_market = request.POST.getlist('LSTM_USE_MARKETDATA')
        new_values['LSTM_USE_MARKETDATA'] = ' '.join(selected_market) if selected_market else DEFAULT_LSTM_MARKET
        
        options = []
        if request.POST.get('LSTM_show_rmse') == 'on':
            options.append('--show_rmse')
        if request.POST.get('LSTM_verbose') == 'on':
            verbose_val = request.POST.get('LSTM_verbose_value', '1')
            options.append(f'--verbose {verbose_val}')
        
        for opt in ['epochs', 'batch_size', 'predictions', 'look_back', 
                   'train_ratio', 'patience', 'lstm_units', 
                   'dropout_rate', 'dense_units']:
            val = request.POST.get(f'LSTM_{opt}', '').strip()
            if val:
                options.append(f'--{opt} {val}')
        
        new_values['LSTM_OPTIONS'] = ' '.join(options) if options else '--show_rmse --verbose 1'
        
        save_override_config(new_values)
        return redirect('settings_ai')
    
    return render(request, 'main/settings_ai.html', {
        'config': effective_cfg,
        'dolstm_enabled': dolstm_enabled,
        'lstm_fields': LSTM_FIELDS,
        'selected_lstm_fields': selected_lstm_fields,
        'economy_assets': economy_assets,
        'selected_eco_assets': selected_eco_assets,
        'marketdata_assets': marketdata_assets,
        'selected_market_assets': selected_market_assets,
        'lstm_options': lstm_options_str,
    })
