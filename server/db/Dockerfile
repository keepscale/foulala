FROM postgis/postgis:16-3.4

# pg_cron pour la purge horaire des jetons
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-16-cron \
 && rm -rf /var/lib/apt/lists/*
