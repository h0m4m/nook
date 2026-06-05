-- Keep the search-media Edge Function worker (and its provider auth tokens) hot
-- so real searches skip the cold-start + token round-trip. The anon key is the
-- public client key (shipped in the app), so embedding it here is not a secret
-- leak. Applied to nook-staging (wzakmmuxsosfybqufdsn) via MCP.
create extension if not exists pg_cron;

-- Make this idempotent: drop any prior job of the same name before rescheduling.
select cron.unschedule('warm-search-media')
where exists (select 1 from cron.job where jobname = 'warm-search-media');

select cron.schedule(
  'warm-search-media',
  '*/4 * * * *',
  $job$
  select net.http_post(
    url := 'https://wzakmmuxsosfybqufdsn.supabase.co/functions/v1/search-media',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6YWttbXV4c29zZnlicXVmZHNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MjA2MzIsImV4cCI6MjA5NTA5NjYzMn0.rS3cFd3PfT_PLGGbO1I57ZXvUEOfeElL-ONJBRoYeOg'
    ),
    body := jsonb_build_object('warm', true)
  );
  $job$
);
