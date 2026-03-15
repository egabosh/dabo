from django.urls import path
from . import views

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
 
    path('data/', views.data_overview_view, name='data_overview'),
    path('data/chart/', views.data_chart_view, name='data_chart'),
    path('botdata/asset-histories/<path:filename>', views.serve_asset_history), 
  
    path('strategies/', views.strategies_overview_view, name='strategies'),
    path('strategies/overview/', views.strategies_overview_view, name='strategies_overview'),
    path('strategies/settings/', views.strategies_settings_view, name='strategies_settings'),
    
    path('settings/', views.settings_general_view, name='settings'),
    path('settings/general/', views.settings_general_view, name='settings_general'),
    path('settings/exchange/', views.settings_exchange_view, name='settings_exchange'),
    path('settings/trade/', views.settings_trade_view, name='settings_trade'),
    path('settings/ai/', views.settings_ai_view, name='settings_ai'),

    path('logs/', views.logs, name='logs'),
    path('logs/stream/', views.logs_stream, name='logs_stream'),

    path('dashboard/stream/', views.dashboard_stream, name='dashboard_stream'),
]

