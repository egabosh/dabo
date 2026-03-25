"""
Main views module - Central entry point for all Django views.

This module re-exports all view functions from specialized submodules
for backwards compatibility with URL routing.

Areas:
    - Dashboard: Main dashboard, data overview, charts
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
