-- Push delivery webhook: on every new notification row, asynchronously call the
-- `send-push` edge function so it can deliver an APNs push. This keeps push in lock-
-- step with the in-app inbox (the notifications table is the single source of truth).
--
-- Uses pg_net (async — net.http_post queues and a background worker sends it after
-- commit, so it never blocks the inserting transaction). The shared secret that
-- authenticates the call to the function is read from Supabase Vault (name
-- 'send_push_secret') so it never lives in this migration or the repo. If the secret
-- isn't set yet, or pg_net/network fails, we swallow the error — the in-app
-- notification must still succeed.

create extension if not exists pg_net;

create or replace function private.tg_push_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
begin
  begin
    select decrypted_secret into v_secret
      from vault.decrypted_secrets
      where name = 'send_push_secret'
      limit 1;

    if v_secret is not null then
      perform net.http_post(
        url := 'https://wzakmmuxsosfybqufdsn.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-webhook-secret', v_secret
        ),
        body := jsonb_build_object('record', to_jsonb(NEW))
      );
    end if;
  exception when others then
    -- Vault missing, pg_net disabled, network error, etc. — never block the insert.
    null;
  end;
  return NEW;
end;
$$;

drop trigger if exists trg_push_notification on public.notifications;
create trigger trg_push_notification
  after insert on public.notifications
  for each row execute function private.tg_push_notification();
