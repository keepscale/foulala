-- Purge horaire : 24 h après la fin d'une manif, les jetons sont remplacés par des totaux.
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('purge-manifs', '0 * * * *', 'SELECT purge_due_events()');
