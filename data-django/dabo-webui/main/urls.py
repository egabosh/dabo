from django.urls import path
from . import views

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    
    path('strategies/', views.strategies_overview_view, name='strategies'),
    path('strategies/overview/', views.strategies_overview_view, name='strategies_overview'),
    path('strategies/settings/', views.strategies_settings_view, name='strategies_settings'),
    
    path('settings/', views.settings_general_view, name='settings'),
    path('settings/general/', views.settings_general_view, name='settings_general'),
    path('settings/exchange/', views.settings_exchange_view, name='settings_exchange'),
]

