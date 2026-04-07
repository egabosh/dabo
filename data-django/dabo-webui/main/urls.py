"""
URL routing configuration for the dabo web UI.

Organizes routes by functional area:
    - Dashboard: Main page and streaming
    - History: Transaction data
    - Data: Market data and charts
    - Strategies: Strategy management
    - Settings: Bot configuration
    - Logs: Log viewing
"""

from django.urls import path
from .views import (
    dashboard,
    history_stream,
    get_transaction_data_api,
    debug_check_files,
    data_overview_view,
    data_chart_view,
    serve_asset_history,
    healthcheck_view,
    trades_view,
    cancel_order,
    cancel_position,
    cancel_all_orders,
    close_all_positions,
    external_positions_view,
    strategies_overview_view,
    strategies_settings_view,
    strategy_variables_view,
    strategy_toggle,
    strategy_toggle_type,
    strategy_editor,
    strategy_delete,
    settings_view,
    settings_general_view,
    settings_exchange_view,
    settings_trade_view,
    settings_ai_view,
    logs_view,
    logs_stream,
)

urlpatterns = [
    # Dashboard - Main page and real-time streaming
    path('', dashboard, name='dashboard'),
    path('dashboard/stream/', history_stream, name='dashboard_stream'),

    # Healthcheck - System health status
    path('healthcheck/', healthcheck_view, name='healthcheck'),

    # History - Transaction history and tax reports
    path('history/', get_transaction_data_api, name='history'),
    path('history/debug/', debug_check_files, name='debug_transaction_files'),

    # Data - Market data overview and charting
    path('data/', data_overview_view, name='data_overview'),
    path('data/chart/', data_chart_view, name='data_chart'),
    path('botdata/asset-histories/<path:filename>', serve_asset_history),

    # Trades - Orders and Positions management
    path('trades/', trades_view, name='trades'),
    path('trades/cancel-order/', cancel_order, name='cancel_order'),
    path('trades/cancel-position/', cancel_position, name='cancel_position'),
    path('trades/cancel-all-orders/', cancel_all_orders, name='cancel_all_orders'),
    path('trades/close-all-positions/', close_all_positions, name='close_all_positions'),

    # External Exchanges - Bitpanda, JustTrade
    path('exchanges/', external_positions_view, name='external_positions'),

    # Strategies - Strategy management, editor, and variables
    path('strategies/', strategies_overview_view, name='strategies'),
    path('strategies/overview/', strategies_overview_view, name='strategies_overview'),
    path('strategies/settings/', strategies_settings_view, name='strategies_settings'),
    path('strategies/variables/', strategy_variables_view, name='strategy_variables'),
    path('strategies/toggle/<str:base_name>/', strategy_toggle, name='strategy_toggle'),
    path('strategies/toggle-type/<str:base_name>/', strategy_toggle_type, name='strategy_toggle_type'),
    path('strategies/editor/new/', strategy_editor, name='strategy_editor_new'),
    path('strategies/editor/<str:filename>/', strategy_editor, name='strategy_editor'),
    path('strategies/delete/', strategy_delete, name='strategy_delete'),

    # Settings - Bot configuration
    path('settings/', settings_general_view, name='settings'),
    path('settings/general/', settings_general_view, name='settings_general'),
    path('settings/exchange/', settings_exchange_view, name='settings_exchange'),
    path('settings/trade/', settings_trade_view, name='settings_trade'),
    path('settings/ai/', settings_ai_view, name='settings_ai'),

    # Logs - Log viewing
    path('logs/', logs_view, name='logs'),
    path('logs/stream/', logs_stream, name='logs_stream'),
]
