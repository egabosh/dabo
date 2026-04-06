from pathlib import Path
import os

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'fallback-secret-key-for-dev')
DEBUG = True
ALLOWED_HOSTS = ['*']

# Dynamically read domain from override config
BOT_OVERRIDE_CONF = '/dabo/dabo-bot.override.conf'
DOMAIN = None
try:
    with open(BOT_OVERRIDE_CONF, 'r') as f:
        for line in f:
            if line.strip().startswith('URL='):
                DOMAIN = line.split('=',1)[1].strip().strip('"')
                break
except Exception:
    DOMAIN = None

# Prepare CSRF trusted origins
if DOMAIN:
    CSRF_TRUSTED_ORIGINS = [f"https://{DOMAIN}"]
else:
    CSRF_TRUSTED_ORIGINS = []

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
