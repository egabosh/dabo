import re
from html import escape

ANSI_RE = re.compile(r'\x1B\[[0-9;]*m')

ANSI_COLOR_MAP = {
    '30': 'ansi-black',
    '31': 'ansi-red',
    '32': 'ansi-green',
    '33': 'ansi-yellow',
    '34': 'ansi-blue',
    '35': 'ansi-magenta',
    '36': 'ansi-cyan',
    '37': 'ansi-white',
    '90': 'ansi-bright-black',
    '91': 'ansi-bright-red',
    '92': 'ansi-bright-green',
    '93': 'ansi-bright-yellow',
    '94': 'ansi-bright-blue',
    '95': 'ansi-bright-magenta',
    '96': 'ansi-bright-cyan',
    '97': 'ansi-bright-white',
    '0':  'reset',
}

def ansi_to_html(line: str) -> str:
    # Gegen XSS sichern: erst escapen
    line = escape(line)

    result = []
    open_span = False
    pos = 0

    for m in ANSI_RE.finditer(line):
        # Text vor der Sequenz
        if m.start() > pos:
            result.append(line[pos:m.start()])

        seq = m.group(0)          # z.B. "\x1b[97m"
        codes = seq[2:-1].split(';')  # "97" oder "0;35" etc.

        # Reset
        if '0' in codes:
            if open_span:
                result.append('</span>')
                open_span = False
        else:
            # beliebigen passenden Farbcode nehmen
            color_code = next((c for c in codes if c in ANSI_COLOR_MAP), None)
            if color_code:
                if open_span:
                    result.append('</span>')
                css_class = ANSI_COLOR_MAP[color_code]
                if css_class != 'reset':
                    result.append(f'<span class="{css_class}">')
                    open_span = True

        pos = m.end()

    # Rest anhängen
    if pos < len(line):
        result.append(line[pos:])

    if open_span:
        result.append('</span>')

    return ''.join(result)
