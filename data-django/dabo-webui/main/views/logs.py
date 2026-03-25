"""
Log Viewing Views

This module contains views for:
    - Main logs page with log file selection
    - Log streaming for real-time log updates

Log files are served from /dabo/htdocs/botdata directory.
"""

from django.shortcuts import render
from ..utils.log_utils import logs_stream


def logs_view(request):
    """Log viewing page with file browser."""
    return render(request, 'main/logs.html', {
        'default_log_name': 'dabo-bot.log',
    })
