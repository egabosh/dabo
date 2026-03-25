from django import template

register = template.Library()

@register.filter
def get_item(dictionary, key):
    if dictionary is None:
        return []
    return dictionary.get(key, [])

@register.filter
def symbol_matches(file_path, current_symbol):
    """Check if the raw symbol (first part of file path) matches current_symbol."""
    if not file_path or not current_symbol:
        return False
    raw_symbol = file_path.split('.history.')[0]
    return raw_symbol == current_symbol

@register.filter
def to_1d_csv(file_path):
    """Convert a file path to use 1d timeframe."""
    if not file_path:
        return file_path
    return file_path.rsplit('.', 2)[0] + '.1d.csv'

@register.filter
def symbol_from_file(file_path):
    """Extract symbol from file path like ECONOMY-DXY.history.1d.csv."""
    if not file_path:
        return ''
    return file_path.split('.history.')[0]

@register.filter
def filter_1d_files(files):
    """Filter files to only return those with 1d timeframe."""
    if not files:
        return []
    return [f for f in files if '.history.' in f and '.1d.csv' in f]
