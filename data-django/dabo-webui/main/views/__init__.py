"""
Main views module - Central entry point for all Django views.

This module re-exports all view functions from specialized submodules
for backwards compatibility with URL routing.

Areas:
    - Dashboard: Main dashboard, data overview, charts
    - Healthcheck: System health status
    - Trades: Orders & Positions management
    - Trades Exchanges: External exchanges (Bitpanda, JustTrade)
    - History: Transaction history
    - Strategies: Strategy management, editor, variables
    - Settings: Bot configuration
    - Logs: Log viewing
"""

# Dashboard & Data views
from .dashboard import (
    dashboard,
    history_stream,
    data_overview_view,
    data_chart_view,
    serve_asset_history,
)

# Healthcheck
from .healthcheck import (
    healthcheck_view,
)

# Trades - Orders & Positions
from .trades import (
    trades_view,
    cancel_order,
    cancel_position,
    cancel_all_orders,
    close_all_positions,
)

# Trades - External Exchanges
from .trades_exchanges import (
    external_positions_view,
)

# History & Transactions
from .history import (
    history_view as get_transaction_data_api,
    history_debug_view as debug_check_files,
)

# Strategy management
from .strategies import (
    strategies_overview_view,
    strategies_settings_view,
    strategy_toggle,
    strategy_toggle_type,
    strategy_editor,
    strategy_delete,
    strategy_variables_view,
)

# Settings
from .settings import (
    settings_view,
    settings_general_view,
    settings_exchange_view,
    settings_trade_view,
    settings_ai_view,
)

# Logs
from .logs import (
    logs_view,
    logs_stream,
)
