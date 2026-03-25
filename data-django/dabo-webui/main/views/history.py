"""
Transaction History Views

This module contains views for:
    - Transaction history page with tax report generation
    - Debug endpoint for checking transaction file status

Reads transaction data from ALL_TRANSACTIONS_OVERVIEW.csv files
and groups transactions by exchange and year for tax reporting.
"""

from django.shortcuts import render
from django.http import HttpResponse
from django.views.decorators.http import require_http_methods
import os
import csv


def history_view(request):
    """Transaction history page with data from ALL_TRANSACTIONS_OVERVIEW.csv."""
    exchange_year_data = {}
    
    csv_file_real = '/dabo/htdocs/botdata/ALL_TRANSACTIONS_OVERVIEW.csv'
    csv_file_tmp = '/dabo/htdocs/botdata/ALL_TRANSACTIONS_OVERVIEW.csv.tmp'
    
    if os.path.exists(csv_file_real):
        csv_path = csv_file_real
    elif os.path.exists(csv_file_tmp):
        csv_path = csv_file_tmp
    else:
        return render(request, 'main/transaction_history_data.html', {
            'exchange_year_data': [],
            'all_exchanges': [],
        })
    
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            
            for row in reader:
                if len(row) < 14 or not row[0]:
                    continue
                
                date_str = row[0]
                exchange = row[1] if len(row) > 1 else 'unknown'
                trans_type = row[2] if len(row) > 2 else 'unknown'
                asset = row[3] if len(row) > 3 else 'unknown'
                amount = row[4] if len(row) > 4 else '0'
                quote_asset = row[5] if len(row) > 5 else 'USDT'
                fiat_raw = row[6] if len(row) > 6 else '0'
                price = row[7] if len(row) > 7 else '0'
                fee = row[8] if len(row) > 8 else '0'
                tax_type = row[12] if len(row) > 12 else ''
                tax_amount_raw = row[13] if len(row) > 13 else '0'
                
                try:
                    fiat_value = float(fiat_raw) if fiat_raw else 0.0
                except (ValueError, TypeError):
                    fiat_value = 0.0
                
                try:
                    tax_amount = float(tax_amount_raw) if tax_amount_raw else 0.0
                except (ValueError, TypeError):
                    tax_amount = 0.0
                
                year = date_str.split('-')[0] if '-' in date_str else date_str[:4]
                key = f'{year}-{exchange}'
                
                if key not in exchange_year_data:
                    exchange_year_data[key] = {
                        'exchange': exchange,
                        'year': year,
                        'taxes': {},
                        'transactions': [],
                    }
                
                exchange_year_data[key]['transactions'].append({
                    'date': date_str[:10],
                    'type': trans_type,
                    'market': f'{asset}/{quote_asset}',
                    'side': 'Buy' if trans_type.lower() == 'buy' else 'Sell',
                    'asset': asset,
                    'amount': abs(float(amount)) if amount else 0,
                    'price': abs(float(price)) if price else 0,
                    'fee': abs(float(fee)) if fee else 0,
                    'fiat_value': fiat_value,
                    'tax_type': tax_type,
                    'tax': tax_amount,
                    'tax_amount': tax_amount,
                })
                
                if tax_type and tax_type.strip():
                    if tax_type not in exchange_year_data[key]['taxes']:
                        exchange_year_data[key]['taxes'][tax_type] = 0.0
                    exchange_year_data[key]['taxes'][tax_type] += tax_amount
    
    except Exception:
        pass
    
    sorted_data = sorted(
        exchange_year_data.values(),
        key=lambda x: (x['year'], x['exchange']),
        reverse=True
    )
    for data in sorted_data:
        data['taxes'] = dict(sorted(data['taxes'].items(), key=lambda x: x[1], reverse=True))
        data['tax_total'] = sum(data['taxes'].values())
        data['summary'] = [{'tax_type': k, 'tax_amount': v} for k, v in data['taxes'].items()]
    
    all_exchanges = sorted(set(d['exchange'] for d in sorted_data))
    
    return render(request, 'main/transaction_history_data.html', {
        'exchange_year_data': sorted_data,
        'all_exchanges': all_exchanges,
    })


def history_debug_view(request):
    """Debug endpoint to check transaction files."""
    base_dir = '/dabo/htdocs/botdata'
    messages = []
    
    messages.append('=== TRANSACTION FILES DEBUG ===')
    messages.append('')
    messages.append(f'Base directory: {base_dir}')
    messages.append(f'Directory exists: {os.path.exists(base_dir)}')
    
    if not os.path.exists(base_dir):
        messages.append('')
        messages.append('ERROR: Directory does not exist!')
        messages.append('')
        messages.append('This means the transaction data files are not being written')
        messages.append('to the expected location. Check your bot configuration.')
        return HttpResponse(''.join(messages), content_type='text/plain')
    
    files_listed = []
    all_files = os.listdir(base_dir)
    messages.append(f'\nTotal files in directory: {len(all_files)}')
    
    for filename in sorted(all_files):
        if filename.startswith('TRANSACTIONS-') and filename.endswith('.csv'):
            files_listed.append(filename)
            messages.append(f'\n{filename}')
            messages.append(f'  Size: {os.path.getsize(f"{base_dir}/{filename}")} bytes')
            try:
                with open(f'{base_dir}/{filename}', 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    messages.append('  First line preview:')
                    first_line = lines[0].strip()[:80] if lines else '(empty)'
                    for i, word in enumerate(first_line.split(',')):
                        if i < 6:
                            messages.append(f'    Column {i}: {word[:30]}')
                    messages.append('  Status: OK (has content)')
            except Exception as e:
                messages.append(f'  Status: ERROR - {str(e)[:50]}')
    
    if files_listed:
        messages.append('')
        messages.append(f'Found {len(files_listed)} valid TRANSACTION_* files')
    else:
        messages.append('')
        messages.append('ERROR: No TRANSACTION_* files found!')
    
    messages.append('')
    messages.append('=== END DEBUG OUTPUT ===')
    
    return HttpResponse('\n'.join(messages), content_type='text/plain')
