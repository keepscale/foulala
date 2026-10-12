# Image officielle PostgreSQL (Debian bookworm, dépôt apt.postgresql.org déjà configuré),
# avec PostGIS et pg_cron. Les images postgis/postgis:16-* reposent encore sur bullseye,
# que le dépôt PostgreSQL ne publie plus.
FROM postgres:16-bookworm

# PostGIS pour les parcours et zones, pg_cron pour la purge horaire des jetons
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      postgresql-16-postgis-3 postgresql-16-postgis-3-scripts postgresql-16-cron \
 && rm -rf /var/lib/apt/lists/*
