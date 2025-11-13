from django.shortcuts import render

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

