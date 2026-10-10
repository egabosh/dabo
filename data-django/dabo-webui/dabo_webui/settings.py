from pathlib import Path
import os

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'fallback-secret-key-for-dev')
DEBUG = True
ALLOWED_HOSTS = ['*']

# Dynamically read domain from override config
# NOTE: the file can contain several URL= lines (defaults first, ansible
# managed block last). Like bash sourcing, the LAST valid line wins.
BOT_OVERRIDE_CONF = '/dabo/dabo-bot.override.conf'
DOMAIN = None
try:
    with open(BOT_OVERRIDE_CONF, 'r') as f:
        for line in f:
            s = line.strip()
            if s.startswith('URL='):
                val = s.split('=', 1)[1].strip().strip('"').strip("'")
                # strip scheme/path if present, keep host only
                val = val.split('://')[-1].split('/')[0].strip()
                if not val:
                    continue
                # skip unconfigured placeholders unless nothing else found
                if '$' in val or 'mydomain' in val:
                    if DOMAIN is None:
                        DOMAIN = val
                    continue
                DOMAIN = val
except Exception:
    pass


def _add_origin(origins, seen, origin):
    if origin and origin not in seen:
        seen.add(origin)
        origins.append(origin)


# CSRF trusted origins: the WebUI is served behind Traefik TLS under
# dabo-webui.<host> while the bot URL in the override conf is dabo.<host>.
# Browsers send "Origin: https://dabo-webui.<host>" on POST - if that origin
# is not trusted Django answers 403 HTML ("Origin checking failed") and the
# JS fetch().json() dies with "JSON.parse: unexpected character".
CSRF_TRUSTED_ORIGINS = []
_seen_origins = set()

# Explicit env overrides first (comma/semicolon separated, scheme optional)
for _part in os.getenv('DJANGO_CSRF_TRUSTED_ORIGINS', '').replace(';', ',').split(','):
    _part = _part.strip()
    if _part:
        _add_origin(CSRF_TRUSTED_ORIGINS, _seen_origins,
                     _part if '://' in _part else 'https://' + _part)

# WEBUI_DOMAIN env (set via compose) wins over the derived domain
WEBUI_DOMAIN = os.getenv('WEBUI_DOMAIN', '').strip().split('://')[-1].split('/')[0]
if WEBUI_DOMAIN:
    _add_origin(CSRF_TRUSTED_ORIGINS, _seen_origins, 'https://' + WEBUI_DOMAIN)

if DOMAIN and 'mydomain' not in DOMAIN and '$' not in DOMAIN:
    _add_origin(CSRF_TRUSTED_ORIGINS, _seen_origins, 'https://' + DOMAIN)
    # bot domain dabo.<host> <-> webui domain dabo-webui.<host>
    if DOMAIN.startswith('dabo.') and not DOMAIN.startswith('dabo-webui.'):
        _add_origin(CSRF_TRUSTED_ORIGINS, _seen_origins,
                     'https://dabo-webui.' + DOMAIN[len('dabo.'):])
    elif DOMAIN.startswith('dabo-webui.'):
        _add_origin(CSRF_TRUSTED_ORIGINS, _seen_origins,
                     'https://dabo.' + DOMAIN[len('dabo-webui.'):])
    # wildcard for the parent domain (covers future subdomains)
    _parent = DOMAIN.split('.', 1)[-1] if '.' in DOMAIN else ''
    if _parent and '.' in _parent:
        _add_origin(CSRF_TRUSTED_ORIGINS, _seen_origins, 'https://*.' + _parent)

# local dev / direct container access
for _local in ('http://localhost', 'http://127.0.0.1',
               'http://localhost:889', 'http://127.0.0.1:889'):
    _add_origin(CSRF_TRUSTED_ORIGINS, _seen_origins, _local)

# Behind Traefik TLS termination: honor X-Forwarded-Proto so
# request.scheme / is_secure() see https
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.contenttypes',
    'django.contrib.staticfiles',
    'main',
]
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
]

ROOT_URLCONF = 'dabo_webui.urls'
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'main' / 'templates'],
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.template.context_processors.csrf',
        ],
    },
}]
WSGI_APPLICATION = 'dabo_webui.wsgi.application'
STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'main' / 'static']
from django.conf.urls.static import static
from django.conf import settings
WHITENOISE_BOTDATA_PATH = BASE_DIR.parent / 'data' / 'botdata'
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'dabo-webui',
        'OPTIONS': {'MAX_ENTRIES': 500, 'CULL_FREQUENCY': 100},
    }
}
