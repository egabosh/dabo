from django.shortcuts import render, redirect
from django.views.decorators.http import require_http_methods
from .utils.log_utils import logs_stream
from .utils.data_utils import dashboard_data_stream
from .utils.config_utils import (
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
from .utils.data_files_utils import (
    list_economy_files,
    list_marketdata_files,
    list_crypto_files,
)
# Each view changes the left sidebar based on top menu choice

def dashboard(request):
    return render(request, 'main/dashboard.html')

def strategies_overview_view(request):
    return render(request, 'main/strategies_overview.html')

def strategies_settings_view(request):
    return render(request, 'main/strategies_settings.html')

def settings_view(request):
    return render(request, 'main/settings.html')

def settings_general_view(request):
    return render(request, 'main/settings_general.html')

def settings_exchange_view(request):
    return render(request, 'main/settings_exchange.html')

def logs(request):
    context = {
        "default_log_name": "dabo-bot.log",
    }
    return render(request, 'main/logs.html', context)

def dashboard_stream(request):
    return dashboard_data_stream(request)


@require_http_methods(["GET", "POST"])
def settings_general_view(request):
    effective_cfg = load_effective_config()

    if request.method == "POST":
        # Collect fields from POST and write to override config
        new_values = {
            "URL": request.POST.get("URL", effective_cfg.get("URL", "")),
            "INTERVAL": request.POST.get("INTERVAL", effective_cfg.get("INTERVAL", "300")),
            "DEBUG": "true" if request.POST.get("DEBUG") == "on" else "false",
            "TESTNET": "true" if request.POST.get("TESTNET") == "on" else "false",
        }
        save_override_config(new_values)
        return redirect("settings_general")

    context = {
        "config": effective_cfg,
    }
    return render(request, "main/settings_general.html", context)


@require_http_methods(["GET", "POST"])
def settings_exchange_view(request):
    effective_cfg = load_effective_config()
    supported_exchanges = load_supported_exchanges()
    current_exchange = effective_cfg.get("STOCK_EXCHANGE", "NONE")

    exchange_secrets = {}
    if current_exchange and current_exchange != "NONE":
        exchange_secrets = load_exchange_secrets(current_exchange)

    if request.method == "POST":
        selected_exchange = request.POST.get("STOCK_EXCHANGE", "NONE")
        api_key = request.POST.get("API_KEY", "")
        api_secret = request.POST.get("API_SECRET", "")

        new_values = {
            "STOCK_EXCHANGE": selected_exchange,
        }
        save_override_config(new_values)

        if selected_exchange != "NONE" and api_key and api_secret:
            save_exchange_secrets(selected_exchange, api_key, api_secret)

        return redirect("settings_exchange")

    context = {
        "config": effective_cfg,
        "supported_exchanges": supported_exchanges,
        "current_exchange": current_exchange,
        "exchange_secrets": exchange_secrets,
    }
    return render(request, "main/settings_exchange.html", context)


@require_http_methods(["GET", "POST"])
def settings_trade_view(request):
    effective_cfg = load_effective_config()
    exchange = effective_cfg.get("STOCK_EXCHANGE", "NONE")
    current_currency = effective_cfg.get("CURRENCY", "")

    tickers = []
    available_quote_currencies: set[str] = set()
    currency_filtered_symbols: list[str] = []  # Nur Symbole für aktuelle CURRENCY

    if exchange and exchange != "NONE":
        tickers = load_tickers_for_exchange(exchange)
        
        # Erst alle Quote-Currencies sammeln
        for symbol, _price in tickers:
            quote = extract_quote_currency(symbol)
            if quote:
                available_quote_currencies.add(quote)
        
        # Dann nur Symbole für aktuelle CURRENCY filtern
        if current_currency:
            for symbol, _price in tickers:
                quote = extract_quote_currency(symbol)
                if quote == current_currency:
                    # Base-Symbol extrahieren (z.B. "KAITO" aus "KAITO/USDC:USDC")
                    base_symbol = symbol
                    if ":" in base_symbol:
                        base_symbol = base_symbol.split(":", 1)[0]
                    if "/" in base_symbol:
                        base_symbol = base_symbol.split("/", 1)[0]
                    
                    if base_symbol not in currency_filtered_symbols:
                        currency_filtered_symbols.append(base_symbol)
        else:
            # Keine Currency ausgewählt → alle Base-Symbole
            for symbol, _price in tickers:
                base_symbol = symbol
                if ":" in base_symbol:
                    base_symbol = base_symbol.split(":", 1)[0]
                if "/" in base_symbol:
                    base_symbol = base_symbol.split("/", 1)[0]
                if base_symbol not in currency_filtered_symbols:
                    currency_filtered_symbols.append(base_symbol)

    # Fallbacks nur wenn gar keine Tickers da sind
    if not available_quote_currencies:
        available_quote_currencies.add("USDT")  # Nur als absoluter Fallback
    if not currency_filtered_symbols:
        default_symbols = effective_cfg.get("SYMBOLS", "").split()
        currency_filtered_symbols.extend([s.strip() for s in default_symbols if s.strip()])

    if request.method == "POST":
        selected_currency = request.POST.get("CURRENCY", current_currency or "USDT")
        selected_symbols = request.POST.getlist("SYMBOLS")
        
        # Wenn keine Symbole ausgewählt, alte behalten
        if not selected_symbols:
            selected_symbols = effective_cfg.get("SYMBOLS", "").split()

        new_values = {
            "CURRENCY": selected_currency,
            "SYMBOLS": " ".join(selected_symbols),
            "LEVERAGE": request.POST.get("LEVERAGE", effective_cfg.get("LEVERAGE", "2")),
            "MARGIN_MODE": request.POST.get("MARGIN_MODE", effective_cfg.get("MARGIN_MODE", "isolated")),
        }
        save_override_config(new_values)
        return redirect("settings_trade")

    context = {
        "config": effective_cfg,
        "exchange": exchange,
        "current_currency": current_currency,
        "available_quote_currencies": sorted(available_quote_currencies),
        "available_symbols": sorted(currency_filtered_symbols),  # Nur passende Symbole!
    }
    return render(request, "main/settings_trade.html", context)

@require_http_methods(["GET", "POST"])
def settings_ai_view(request):
    """AI/LSTM settings with conditional field display."""
    effective_cfg = load_effective_config()
    dolstm_enabled = effective_cfg.get("DOLSTM", "false").lower() == "true"
    
    # LSTM defaults
    DEFAULT_LSTM_FIELDS = "5,6,11,13,17,21"
    DEFAULT_LSTM_ECO = "NASDAQ SP500 DOWJONES DXY KRE"
    DEFAULT_LSTM_MARKET = "ALTCOIN_SEASON_INDEX_COINMARKETCAP BINANCE_LONG_SHORT_RATIO_ACCOUNT_ BINANCE_LONG_SHORT_RATIO_TAKER_ BINANCE_OPEN_INTEREST_ FEAR_AND_GREED_ALTERNATIVEME FEAR_AND_GREED_CNN FEAR_AND_GREED_COINMARKETCAP US_CONSUMER_PRICE_INDEX_CPI US_FED_FUNDS_RATE US_UNEMPLOYMENT_RATE"

    # Load assets
    economy_assets = load_economy_assets()
    marketdata_assets = load_marketdata_assets()
    
    # LSTM fields parsing with defaults
    lstm_fields_str = effective_cfg.get("LSTM_USE_FIELDS", DEFAULT_LSTM_FIELDS)
    selected_lstm_fields = set(int(x.strip()) for x in lstm_fields_str.split(",") if x.strip())

    # Economy assets with defaults
    lstm_eco_str = effective_cfg.get("LSTM_USE_ECO_ASSETS", DEFAULT_LSTM_ECO)
    selected_eco_assets = set(x.strip() for x in lstm_eco_str.split() if x.strip())

    # Marketdata assets with defaults
    lstm_market_str = effective_cfg.get("LSTM_USE_MARKETDATA", DEFAULT_LSTM_MARKET)
    selected_market_assets = set(x.strip() for x in lstm_market_str.split() if x.strip())
    
    # LSTM options parsing
    lstm_options_str = effective_cfg.get("LSTM_OPTIONS", "--show_rmse --verbose 1")
    
    if request.method == "POST":
        new_values = {}
        
        # DOLSTM toggle
        new_values["DOLSTM"] = "true" if request.POST.get("DOLSTM") == "on" else "false"
        
        # LSTM fields from checkboxes
        selected_fields = []
        for num_str in request.POST.getlist("LSTM_USE_FIELDS"):
            try:
                selected_fields.append(num_str)
            except ValueError:
                pass
        if selected_fields:
            new_values["LSTM_USE_FIELDS"] = ",".join(selected_fields)
        else:
            new_values["LSTM_USE_FIELDS"] = DEFAULT_LSTM_FIELDS
        
        # Eco assets
        selected_eco = request.POST.getlist("LSTM_USE_ECO_ASSETS")
        if selected_eco:
            new_values["LSTM_USE_ECO_ASSETS"] = " ".join(selected_eco)
        else:
            new_values["LSTM_USE_ECO_ASSETS"] = DEFAULT_LSTM_ECO
        
        # Marketdata assets
        selected_market = request.POST.getlist("LSTM_USE_MARKETDATA")
        if selected_market:
            new_values["LSTM_USE_MARKETDATA"] = " ".join(selected_market)
        else:
            new_values["LSTM_USE_MARKETDATA"] = DEFAULT_LSTM_MARKET
        
        # LSTM options (build from checkboxes + text fields)
        options = []
        if request.POST.get("LSTM_show_rmse") == "on":
            options.append("--show_rmse")
        if request.POST.get("LSTM_verbose") == "on":
            verbose_val = request.POST.get("LSTM_verbose_value", "1")
            options.append(f"--verbose {verbose_val}")
        
        # Text fields for numeric options
        for opt in ["epochs", "batch_size", "predictions", "look_back", 
                   "train_ratio", "patience", "lstm_units", 
                   "dropout_rate", "dense_units"]:
            val = request.POST.get(f"LSTM_{opt}", "").strip()
            if val:
                options.append(f"--{opt} {val}")
        
        if options:
            new_values["LSTM_OPTIONS"] = " ".join(options)
        else:
            new_values["LSTM_OPTIONS"] = "--show_rmse --verbose 1"
        
        save_override_config(new_values)
        return redirect("settings_ai")
    
    context = {
        "config": effective_cfg,
        "dolstm_enabled": dolstm_enabled,
        "lstm_fields": LSTM_FIELDS,
        "selected_lstm_fields": selected_lstm_fields,
        "economy_assets": economy_assets,
        "selected_eco_assets": selected_eco_assets,
        "marketdata_assets": marketdata_assets,
        "selected_market_assets": selected_market_assets,
        "lstm_options": lstm_options_str,
    }
    return render(request, "main/settings_ai.html", context)


from django.http import Http404

from collections import defaultdict

def get_unique_symbols(files):
    """Extract unique symbols with their available timeframes."""
    symbols = defaultdict(list)
    for filename in files:
        # BTCUSD.history.4h.csv → BTCUSD
        symbol = filename.split(".history.")[0]
        if symbol.startswith("MARKETDATA_"):
            display_name = symbol[11:].replace("_", " ").title()
        elif symbol.startswith("ECONOMY-"):
            display_name = symbol[8:].replace("-", " ").title()
        else:
            display_name = symbol.upper()
        
        symbols[display_name].append(filename)
    return dict(symbols)

@require_http_methods(["GET"])
def data_overview_view(request):
    economy_files = list_economy_files()
    marketdata_files = list_marketdata_files()
    crypto_files = list_crypto_files()

    marketdata_symbols = get_unique_symbols(marketdata_files)
    economy_symbols = get_unique_symbols(economy_files)
    crypto_symbols = get_unique_symbols(crypto_files)

    context = {
        "marketdata_symbols": marketdata_symbols,
        "economy_symbols": economy_symbols, 
        "crypto_symbols": crypto_symbols,
    }
    return render(request, "main/data_overview.html", context)


@require_http_methods(["GET"])
def data_chart_view(request):
    filename = request.GET.get("file")
    if not filename:
        raise Http404("No file specified")

    if "/" in filename or ".." in filename:
        raise Http404("Invalid file")

    parts = filename.split(".history.")
    if len(parts) != 2:
        raise Http404("Invalid file format: expected SYMBOL.history.TIME.csv")
    
    symbol = parts[0]
    timeframe = parts[1].replace(".csv", "")

    # SIDEBAR-DATEN MITGEBEN
    marketdata_symbols = get_unique_symbols(list_marketdata_files())
    economy_symbols = get_unique_symbols(list_economy_files())
    crypto_symbols = get_unique_symbols(list_crypto_files())
    
    context = {
        "symbol": symbol, "timeframe": timeframe, "filename": filename,
        "timeframes": ["5m", "15m", "1h", "4h", "1d", "1w"],
        "marketdata_symbols": marketdata_symbols,
        "economy_symbols": economy_symbols,
        "crypto_symbols": crypto_symbols,
    }
    return render(request, "main/data_chart.html", context)


from django.http import FileResponse, Http404, HttpResponse
from django.views.decorators.http import require_GET
import os

@require_GET
def serve_asset_history(request, filename):
    """Serve CSV files from /dabo/htdocs/botdata/asset-histories/."""
    filepath = os.path.join("/dabo/htdocs/botdata/asset-histories", filename)
    
    # Security: Path traversal verhindern
    if ".." in filename or not os.path.exists(filepath):
        raise Http404(f"File not found: {filename}")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        raise Http404(f"Cannot read file: {filename}")
    
    response = HttpResponse(content, content_type='text/csv')
    response['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    response['Pragma'] = 'no-cache'
    return response
