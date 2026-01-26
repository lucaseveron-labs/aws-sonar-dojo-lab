# local_settings.py
# this file will be included by settings.py *after* loading settings.dist.py

# this example sets some loglevels to DEBUG

# adding DEBUG logging for all of Django.
LOGGING['loggers']['root'] = {
            'handlers': ['console'],
            'level': 'DEBUG',
        }
# setting log level WARN for defect dojo
# LOGGING['loggers']['dojo']['level'] = 'WARN'

# output DEBUG logging for deduplication
# LOGGING['loggers']['dojo.specific-loggers.deduplication']['level'] = 'DEBUG'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'defectdojo',
        'USER': 'dojosonar_admin',
        'PASSWORD': 'Ns2b7_bfqbf!',
        'HOST': 'app-postgres-db-22.cwn4e6i2uzew.us-east-1.rds.amazonaws.com',
        'PORT': '5432',
        'CONN_MAX_AGE': 60,
    }
}