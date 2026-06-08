// revenuecat-webhook — keeps `user_profiles.is_plus` in sync with RevenueCat.
//
// Invoked by RevenueCat's webhook (Project → Integrations → Webhooks) on every
// subscriber event. Auth is the shared secret you configure as the webhook's
// "Authorization header value": RevenueCat sends it verbatim in the
// `Authorization` header. This runs with verify_jwt disabled — the caller is
// RevenueCat, not an end user.
//
// Because the app calls `Purchases.logIn(supabaseUserId)` before purchasing,
// `event.app_user_id` IS the Supabase user id, so we can update the profile row
// directly with the service role (which bypasses RLS).
//
// Required function secrets (supabase secrets set ...):
//   REVENUECAT_WEBHOOK_SECRET - must equal the dashboard's Authorization value
// Auto-provided by the platform:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const WEBHOOK_SECRET = Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ?? '';

// The entitlement identifier configured in RevenueCat (and in the iOS client).
const ENTITLEMENT_ID = 'plus';

// Event types that revoke access immediately. Everything else either grants or
// preserves access (CANCELLATION only turns off auto-renew — access continues
// until expiration, so it is NOT in this set).
const REVOKING = new Set(['EXPIRATION', 'SUBSCRIPTION_PAUSED']);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// The subset of the RevenueCat webhook event we use. See
// https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
interface RcEvent {
  type?: string;
  entitlement_ids?: string[];
  entitlement_id?: string;
  expiration_at_ms?: number;
  app_user_id?: string;
  transferred_from?: string[];
  transferred_to?: string[];
}

interface RcWebhookBody {
  event?: RcEvent;
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

type Admin = ReturnType<typeof createClient>;

async function setPlus(admin: Admin, ids: string[], isPlus: boolean, expiresAt: string | null) {
  const valid = ids.filter((id) => UUID_RE.test(id));
  if (valid.length === 0) return;
  await admin
    .from('user_profiles')
    .update({ is_plus: isPlus, plus_expires_at: isPlus ? expiresAt : null })
    .in('id', valid);
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' });

  // Constant work either way; reject if the shared secret doesn't match.
  if (!WEBHOOK_SECRET || req.headers.get('Authorization') !== WEBHOOK_SECRET) {
    return json(401, { error: 'Unauthorized' });
  }

  let body: RcWebhookBody;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'Invalid JSON' });
  }

  const event = body?.event;
  const type = event?.type;
  if (!event || !type) return json(200, { ignored: 'no event' });

  // Dashboard "Send test event" — acknowledge so the test passes.
  if (type === 'TEST') return json(200, { ok: true, test: true });

  // If the event names entitlements and ours isn't among them, ignore it.
  const entitlements: string[] =
    event.entitlement_ids ?? (event.entitlement_id ? [event.entitlement_id] : []);
  if (entitlements.length > 0 && !entitlements.includes(ENTITLEMENT_ID)) {
    return json(200, { ignored: 'other entitlement' });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const expiresAt =
    typeof event.expiration_at_ms === 'number'
      ? new Date(event.expiration_at_ms).toISOString()
      : null;

  // Transfers move the entitlement between app_user_ids.
  if (type === 'TRANSFER') {
    await setPlus(admin, event.transferred_from ?? [], false, null);
    await setPlus(admin, event.transferred_to ?? [], true, expiresAt);
    return json(200, { ok: true, transfer: true });
  }

  const uid: string | undefined = event.app_user_id;
  if (!uid || !UUID_RE.test(uid)) {
    // Anonymous / non-Supabase id — nothing to map to a profile.
    return json(200, { ignored: 'non-uuid app_user_id' });
  }

  const stillValid = expiresAt === null || new Date(expiresAt).getTime() > Date.now();
  const active = !REVOKING.has(type) && stillValid;

  const { error } = await admin
    .from('user_profiles')
    .update({ is_plus: active, plus_expires_at: active ? expiresAt : null })
    .eq('id', uid);

  if (error) {
    console.error('revenuecat-webhook update failed', error);
    return json(500, { error: 'update failed' });
  }

  return json(200, { ok: true, uid, type, active });
});
