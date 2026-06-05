// send-push — delivers an APNs push for a freshly-inserted notification row.
//
// Invoked by a Postgres webhook (pg_net) on INSERT into public.notifications (see
// migration notifications_push_webhook). Auth is a shared secret header
// (`x-webhook-secret`) — this function runs with verify_jwt disabled because the
// caller is the database, not an end user.
//
// Flow: validate secret -> load recipient prefs (push_enabled + category gate) ->
// load recipient's device tokens -> build APNs payload -> sign an ES256 JWT with the
// APNs .p8 key -> POST to APNs per token (HTTP/2) -> delete tokens APNs reports stale.
//
// Required function secrets (supabase secrets set ...):
//   APNS_KEY_ID       - 10-char key id of the .p8 auth key
//   APNS_PRIVATE_KEY  - contents of the .p8 (PEM, -----BEGIN PRIVATE KEY----- ...)
//   SEND_PUSH_SECRET  - shared secret, must match the DB webhook's stored value
// Optional (have sensible defaults):
//   APNS_TEAM_ID      - default 8PP9FS9CAY
//   APNS_BUNDLE_ID    - default app.getnook
//   APNS_ENV          - 'sandbox' | 'production', fallback when a token row has none
import { createClient } from 'jsr:@supabase/supabase-js@2';

const TEAM_ID = Deno.env.get('APNS_TEAM_ID') ?? '8PP9FS9CAY';
const BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') ?? 'app.getnook';
const KEY_ID = Deno.env.get('APNS_KEY_ID') ?? '';
const PRIVATE_KEY_PEM = Deno.env.get('APNS_PRIVATE_KEY') ?? '';
const DEFAULT_ENV = Deno.env.get('APNS_ENV') ?? 'sandbox';
const WEBHOOK_SECRET = Deno.env.get('SEND_PUSH_SECRET') ?? '';

// Notification type -> (preference category, push body). Title is the actor's name.
const TYPE_META: Record<string, { category: 'activity' | 'community' | 'reviews'; body: string }> = {
  follow: { category: 'activity', body: 'started following you' },
  like_review: { category: 'reviews', body: 'liked your review' },
  comment_review: { category: 'reviews', body: 'commented on your review' },
  like_post: { category: 'activity', body: 'liked your post' },
  comment_post: { category: 'community', body: 'commented on your post' },
  club_invite: { category: 'community', body: 'invited you to a club' },
  club_join: { category: 'community', body: 'joined your club' },
  nook_mention: { category: 'activity', body: 'mentioned you in a nook' },
};

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

let cachedKey: CryptoKey | null = null;
async function getSigningKey(): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  cachedKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(PRIVATE_KEY_PEM),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  return cachedKey;
}

// APNs provider JWT (reusable up to ~1h; we mint one per invocation).
async function makeProviderToken(): Promise<string> {
  const header = base64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID }));
  const claims = base64url(JSON.stringify({ iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${claims}`;
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    await getSigningKey(),
    new TextEncoder().encode(signingInput),
  );
  // Web Crypto ECDSA produces the raw r||s the JWS ES256 spec wants.
  return `${signingInput}.${base64url(new Uint8Array(sig))}`;
}

function hostFor(environment: string): string {
  return environment === 'production' ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com';
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }
  if (!WEBHOOK_SECRET || req.headers.get('x-webhook-secret') !== WEBHOOK_SECRET) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (!KEY_ID || !PRIVATE_KEY_PEM) {
    return new Response(JSON.stringify({ error: 'APNs key not configured' }), { status: 500 });
  }

  // pg_net / Supabase webhook payload: { record: <row> } (or the row itself).
  const payload = await req.json().catch(() => ({}));
  const row = payload.record ?? payload;
  const recipientId: string | undefined = row?.user_id;
  const actorId: string | undefined = row?.actor_id;
  const type: string | undefined = row?.type;

  if (!recipientId || !type) {
    return new Response(JSON.stringify({ error: 'missing user_id/type' }), { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const meta = TYPE_META[type] ?? { category: 'activity' as const, body: 'interacted with you' };

  // Recipient preferences: push_enabled is the master switch; the category flag is a
  // second gate (the in-app trigger already checked it, but this defends push too).
  const { data: recipient } = await supabase
    .from('user_profiles')
    .select('notification_preferences')
    .eq('id', recipientId)
    .single();
  const prefs = (recipient?.notification_preferences ?? {}) as Record<string, boolean>;
  if (prefs.push_enabled === false || prefs[meta.category] === false) {
    return new Response(JSON.stringify({ skipped: 'preferences' }), { status: 200 });
  }

  // Actor name/avatar for the alert.
  let actorName = 'Someone';
  let actorAvatar: string | null = null;
  if (actorId) {
    const { data: actor } = await supabase
      .from('user_profiles')
      .select('full_name, username, avatar_url')
      .eq('id', actorId)
      .single();
    actorName = actor?.full_name || actor?.username || 'Someone';
    actorAvatar = actor?.avatar_url ?? null;
  }

  // Recipient device tokens.
  const { data: tokens } = await supabase
    .from('device_tokens')
    .select('token, environment')
    .eq('user_id', recipientId);
  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ skipped: 'no devices' }), { status: 200 });
  }

  // Badge = unread count for the recipient.
  const { count: unread } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', recipientId)
    .eq('is_read', false);

  const apsBody = {
    aps: {
      alert: { title: actorName, body: meta.body },
      sound: 'default',
      badge: unread ?? 1,
    },
    // Custom keys consumed by the iOS PushRouter for tap deep-linking.
    n_type: type,
    ref_id: row?.reference_id ?? null,
    ref_type: row?.reference_type ?? null,
    actor_id: actorId ?? null,
    actor_name: actorName,
    actor_avatar: actorAvatar,
  };
  const bodyStr = JSON.stringify(apsBody);
  const jwt = await makeProviderToken();

  const results = await Promise.all(
    tokens.map(async (t) => {
      const env = t.environment || DEFAULT_ENV;
      const res = await fetch(`${hostFor(env)}/3/device/${t.token}`, {
        method: 'POST',
        headers: {
          'authorization': `bearer ${jwt}`,
          'apns-topic': BUNDLE_ID,
          'apns-push-type': 'alert',
          'apns-priority': '10',
          'content-type': 'application/json',
        },
        body: bodyStr,
      });
      if (res.status === 200) return { token: t.token, ok: true };
      const text = await res.text().catch(() => '');
      let reason = '';
      try { reason = JSON.parse(text)?.reason ?? ''; } catch { /* ignore */ }
      // Prune tokens APNs says will never deliver.
      if (res.status === 410 || reason === 'BadDeviceToken' || reason === 'Unregistered') {
        await supabase.from('device_tokens').delete().eq('token', t.token);
      }
      return { token: t.token, ok: false, status: res.status, reason };
    }),
  );

  return new Response(JSON.stringify({ sent: results.filter((r) => r.ok).length, results }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
