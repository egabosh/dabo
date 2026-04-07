"""
Healthcheck View

Displays healthcheck status from HEALTH_*.done files.
"""

from django.shortcuts import render
import os
import glob

VALUES_DIR = "/dabo/htdocs/botdata"


def healthcheck_view(request):
    """Display healthcheck information from HEALTH_* files."""
    checks = []
    seen = set()
    status_counts = {'OK': 0, 'WARN': 0, 'ERROR': 0}
    
    pattern = os.path.join(VALUES_DIR, "HEALTH_*")
    files = glob.glob(pattern)
    
    for filepath in sorted(files):
        try:
            with open(filepath, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    
                    # Split by first two colons
                    parts = line.split(':', 2)
                    if len(parts) < 3:
                        continue
                    
                    status = parts[0].strip()
                    program_func = parts[1].strip()
                    message = parts[2].strip()
                    
                    # Deduplicate by status + program_func + message
                    key = (status, program_func, message)
                    if key in seen:
                        continue
                    seen.add(key)
                    
                    # Count statuses
                    if status in status_counts:
                        status_counts[status] += 1
                    
                    checks.append({
                        'status': status,
                        'program_func': program_func,
                        'message': message,
                        'file': os.path.basename(filepath),
                    })
        except Exception:
            pass
    
    # Sort: ERROR first, then WARN, then OK
    status_order = {'ERROR': 0, 'WARN': 1, 'OK': 2}
    checks.sort(key=lambda x: (status_order.get(x['status'], 3), x['file'], x['program_func']))
    
    return render(request, 'main/healthcheck.html', {
        'checks': checks,
        'status_counts': status_counts,
        'total': len(checks),
    })
