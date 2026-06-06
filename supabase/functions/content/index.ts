/* eslint-disable @typescript-eslint/no-explicit-any -- Deno edge function; request payloads are dynamic client JSON validated per handler */
// Content gateway: the ONLY write path for user-generated content.
//
// Every create/edit of moderated content is funneled here. The client can no
// longer insert these rows directly — the matching RLS INSERT/UPDATE policies
// have been dropped (see migration 20260605200000_moderation_gateway_lockdown).
// This function:
//   1. authenticates the caller from their JWT,
//   2. runs all text + image URLs through OpenAI moderation (omni-moderation),
//   3. on a clean verdict, writes the row(s) with the service role,
//   4. on a flag, returns 422 and writes NOTHING.
//
// Authorization that RLS used to enforce is re-checked here, because the
// service-role client bypasses RLS:
//   - rows are always written with user_id = the authenticated caller,
//   - update_club requires the caller to be a club owner/manager,
//   - set_nook_items requires the caller to own the nook.
//
// Notification / mention / count triggers all key off NEW.user_id (not
// auth.uid()) and the count triggers are SECURITY DEFINER, so they fire
// correctly on these service-role writes.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import {
  moderateInputs,
  moderationRejection,
  type ModerationInput,
} from '../_shared/moderation.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

// Service-role client: bypasses RLS, used for all writes + authz lookups.
const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    // 1. Authenticate the caller.
    const authHeader = req.headers.get('Authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '');
    if (!jwt) return json(401, { error: 'Missing authorization' });

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return json(401, { error: 'Invalid session' });
    const uid = userData.user.id;

    // 2. Parse request.
    const { action, payload } = await req.json().catch(() => ({}));
    if (typeof action !== 'string' || !action) {
      return json(400, { error: 'Missing action' });
    }
    const p = payload ?? {};

    // 3. Dispatch.
    switch (action) {
      case 'create_review':
        return await createReview(uid, p);
      case 'create_review_comment':
        return await createReviewComment(uid, p);
      case 'create_club':
        return await createClub(uid, p);
      case 'update_club':
        return await updateClub(uid, p);
      case 'create_club_post':
        return await createClubPost(uid, p);
      case 'create_club_post_comment':
        return await createClubPostComment(uid, p);
      case 'create_nook':
        return await createNook(uid, p);
      case 'set_nook_items':
        return await setNookItems(uid, p);
      case 'create_nook_comment':
        return await createNookComment(uid, p);
      case 'update_profile_text':
        return await updateProfileText(uid, p);
      default:
        return json(400, { error: `Unknown action: ${action}` });
    }
  } catch (err) {
    console.error('[content] unhandled error:', err);
    return json(500, { error: 'Internal error' });
  }
});

/** Moderate the given inputs; return a Response to short-circuit if flagged, else null. */
async function gate(inputs: ModerationInput[]): Promise<Response | null> {
  const result = await moderateInputs(inputs);
  if (result.flagged) {
    const { status, body } = moderationRejection(result);
    return json(status, body);
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reviews
// ─────────────────────────────────────────────────────────────────────────────

async function createReview(uid: string, p: any): Promise<Response> {
  if (!p.media_item_id || typeof p.body !== 'string' || typeof p.rating !== 'number') {
    return json(400, { error: 'media_item_id, body and rating are required' });
  }
  const blocked = await gate([{ text: p.title }, { text: p.body }]);
  if (blocked) return blocked;

  const { data, error } = await admin
    .from('reviews')
    .upsert(
      {
        user_id: uid,
        media_item_id: p.media_item_id,
        title: p.title ?? null,
        body: p.body,
        rating: p.rating,
        is_spoiler: p.is_spoiler ?? false,
      },
      { onConflict: 'user_id,media_item_id' },
    )
    .select('id')
    .single();
  if (error) return json(400, { error: error.message });

  const reviewId = data.id;
  // The review content changed — clear old comments/likes and reset the count.
  await admin.from('review_comments').delete().eq('review_id', reviewId);
  await admin.from('review_likes').delete().eq('review_id', reviewId);
  await admin.from('reviews').update({ likes_count: 0 }).eq('id', reviewId);

  // Best-effort activity feed entry (matches prior client behavior).
  await admin.from('activity_feed').insert({
    user_id: uid,
    action_type: 'reviewed',
    media_item_id: p.media_item_id,
    reference_id: reviewId,
    reference_type: 'review',
  });

  return json(200, { id: reviewId });
}

async function createReviewComment(uid: string, p: any): Promise<Response> {
  if (!p.review_id || typeof p.body !== 'string') {
    return json(400, { error: 'review_id and body are required' });
  }
  const blocked = await gate([{ text: p.body }]);
  if (blocked) return blocked;

  const { data, error } = await admin
    .from('review_comments')
    .insert({
      review_id: p.review_id,
      user_id: uid,
      parent_comment_id: p.parent_comment_id ?? null,
      body: p.body,
    })
    .select('id')
    .single();
  if (error) return json(400, { error: error.message });
  return json(200, { id: data.id });
}

// ─────────────────────────────────────────────────────────────────────────────
// Clubs
// ─────────────────────────────────────────────────────────────────────────────

async function createClub(uid: string, p: any): Promise<Response> {
  if (
    typeof p.name !== 'string' ||
    !p.name.trim() ||
    typeof p.category !== 'string' ||
    typeof p.privacy !== 'string'
  ) {
    return json(400, { error: 'name, category and privacy are required' });
  }
  const blocked = await gate([
    { text: p.name },
    { text: p.description },
    { imageUrl: p.banner_url },
    { imageUrl: p.icon_url },
  ]);
  if (blocked) return blocked;

  const { data, error } = await admin
    .from('clubs')
    .insert({
      owner_id: uid,
      name: p.name,
      description: p.description ?? null,
      category: p.category,
      privacy: p.privacy,
      theme_color: p.theme_color ?? null,
      banner_url: p.banner_url ?? null,
      icon_url: p.icon_url ?? null,
    })
    .select('id')
    .single();
  if (error) return json(400, { error: error.message });

  const clubId = data.id;
  const { error: memberErr } = await admin
    .from('club_members')
    .insert({ club_id: clubId, user_id: uid, role: 'owner' });
  if (memberErr) {
    // Roll back the club so we don't leave an ownerless shell.
    await admin.from('clubs').delete().eq('id', clubId);
    return json(400, { error: memberErr.message });
  }

  return json(200, { id: clubId });
}

async function updateClub(uid: string, p: any): Promise<Response> {
  if (!p.club_id) return json(400, { error: 'club_id is required' });

  // Authorization that RLS ("Admins update club" → is_club_admin) used to enforce.
  const { data: isAdmin, error: authzErr } = await admin.rpc('is_club_admin', {
    p_club_id: p.club_id,
    p_user_id: uid,
  });
  if (authzErr) return json(400, { error: authzErr.message });
  if (!isAdmin) return json(403, { error: 'Not allowed to edit this club' });

  const blocked = await gate([
    { text: p.description },
    { imageUrl: p.banner_url },
    { imageUrl: p.icon_url },
  ]);
  if (blocked) return blocked;

  // name is immutable (matches prior behavior — never updated here).
  const updates: Record<string, unknown> = {};
  if ('description' in p) updates.description = p.description ?? null;
  if ('category' in p) updates.category = p.category;
  if ('privacy' in p) updates.privacy = p.privacy;
  if ('theme_color' in p) updates.theme_color = p.theme_color ?? null;
  if (p.banner_url) updates.banner_url = p.banner_url;
  if (p.icon_url) updates.icon_url = p.icon_url;

  const { error } = await admin.from('clubs').update(updates).eq('id', p.club_id);
  if (error) return json(400, { error: error.message });
  return json(200, { id: p.club_id });
}

async function createClubPost(uid: string, p: any): Promise<Response> {
  if (!p.club_id || typeof p.body !== 'string') {
    return json(400, { error: 'club_id and body are required' });
  }
  const images: Array<{ url: string; position: number }> = Array.isArray(p.images) ? p.images : [];
  const media: Array<{ media_item_id: string; position: number }> = Array.isArray(p.media)
    ? p.media
    : [];
  const poll: { closes_at?: string | null; options: string[] } | null = p.poll ?? null;

  const inputs: ModerationInput[] = [{ text: p.body }];
  for (const img of images) inputs.push({ imageUrl: img.url });
  if (poll?.options) for (const opt of poll.options) inputs.push({ text: opt });
  const blocked = await gate(inputs);
  if (blocked) return blocked;

  const { data: post, error } = await admin
    .from('club_posts')
    .insert({ club_id: p.club_id, user_id: uid, body: p.body })
    .select('id')
    .single();
  if (error) return json(400, { error: error.message });
  const postId = post.id;

  if (images.length > 0) {
    const { error: imgErr } = await admin
      .from('club_post_images')
      .insert(images.map((img) => ({ post_id: postId, url: img.url, position: img.position })));
    if (imgErr) return json(400, { error: imgErr.message });
  }

  if (media.length > 0) {
    const { error: medErr } = await admin
      .from('club_post_media')
      .insert(
        media.map((m) => ({
          post_id: postId,
          media_item_id: m.media_item_id,
          position: m.position,
        })),
      );
    if (medErr) return json(400, { error: medErr.message });
  }

  if (poll && Array.isArray(poll.options) && poll.options.length >= 2) {
    const { data: pollRow, error: pollErr } = await admin
      .from('club_post_polls')
      .insert({ post_id: postId, closes_at: poll.closes_at ?? null })
      .select('id')
      .single();
    if (pollErr) return json(400, { error: pollErr.message });

    const { error: optErr } = await admin
      .from('club_poll_options')
      .insert(poll.options.map((text, index) => ({ poll_id: pollRow.id, text, position: index })));
    if (optErr) return json(400, { error: optErr.message });
  }

  return json(200, { id: postId });
}

async function createClubPostComment(uid: string, p: any): Promise<Response> {
  if (!p.post_id || typeof p.body !== 'string') {
    return json(400, { error: 'post_id and body are required' });
  }
  const blocked = await gate([{ text: p.body }]);
  if (blocked) return blocked;

  const { data, error } = await admin
    .from('club_post_comments')
    .insert({
      post_id: p.post_id,
      user_id: uid,
      parent_comment_id: p.parent_comment_id ?? null,
      body: p.body,
    })
    .select('id')
    .single();
  if (error) return json(400, { error: error.message });
  return json(200, { id: data.id });
}

// ─────────────────────────────────────────────────────────────────────────────
// Nooks
// ─────────────────────────────────────────────────────────────────────────────

async function createNook(uid: string, p: any): Promise<Response> {
  if (typeof p.name !== 'string' || !p.name.trim() || typeof p.privacy !== 'string') {
    return json(400, { error: 'name and privacy are required' });
  }
  const blocked = await gate([{ text: p.name }, { text: p.description }]);
  if (blocked) return blocked;

  const { data, error } = await admin
    .from('nooks')
    .insert({
      user_id: uid,
      name: p.name,
      description: p.description ?? null,
      privacy: p.privacy,
    })
    .select('id')
    .single();
  if (error) return json(400, { error: error.message });
  const nookId = data.id;

  await admin.from('activity_feed').insert({
    user_id: uid,
    action_type: 'created_nook',
    reference_id: nookId,
    reference_type: 'nook',
  });

  return json(200, { id: nookId });
}

/** Replace all items in a nook (delete-then-insert), moderating any per-item notes. */
async function setNookItems(uid: string, p: any): Promise<Response> {
  if (!p.nook_id || !Array.isArray(p.items)) {
    return json(400, { error: 'nook_id and items are required' });
  }
  // Authorization: caller must own the nook (RLS "items to own nooks").
  const { data: nook, error: ownErr } = await admin
    .from('nooks')
    .select('user_id')
    .eq('id', p.nook_id)
    .single();
  if (ownErr) return json(400, { error: ownErr.message });
  if (nook.user_id !== uid) return json(403, { error: 'Not your nook' });

  const items: Array<{ media_item_id: string; note?: string | null; sort_order: number }> = p.items;
  const blocked = await gate(items.map((it) => ({ text: it.note })));
  if (blocked) return blocked;

  // Replace (mirrors NookService.replaceItems): clear then insert.
  await admin.from('nook_items').delete().eq('nook_id', p.nook_id);
  if (items.length > 0) {
    const { error } = await admin.from('nook_items').insert(
      items.map((it) => ({
        nook_id: p.nook_id,
        media_item_id: it.media_item_id,
        note: it.note ?? null,
        sort_order: it.sort_order,
      })),
    );
    if (error) return json(400, { error: error.message });
  }
  return json(200, { nook_id: p.nook_id });
}

async function createNookComment(uid: string, p: any): Promise<Response> {
  if (!p.nook_id || typeof p.body !== 'string') {
    return json(400, { error: 'nook_id and body are required' });
  }
  const blocked = await gate([{ text: p.body }]);
  if (blocked) return blocked;

  const { data, error } = await admin
    .from('nook_comments')
    .insert({
      nook_id: p.nook_id,
      user_id: uid,
      parent_comment_id: p.parent_comment_id ?? null,
      body: p.body,
    })
    .select('id')
    .single();
  if (error) return json(400, { error: error.message });
  return json(200, { id: data.id });
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile (full_name / username / bio — the only gated columns)
// ─────────────────────────────────────────────────────────────────────────────

async function updateProfileText(uid: string, p: any): Promise<Response> {
  const blocked = await gate([
    { text: p.full_name },
    { text: p.username },
    { text: p.bio },
    { imageUrl: p.avatar_url },
  ]);
  if (blocked) return blocked;

  // Upsert so it works during onboarding (row may not exist yet) and for edits.
  // avatar_url is non-text and passed through here only as a convenience for the
  // onboarding step, which sets name + username + avatar in one go.
  const row: Record<string, unknown> = { id: uid };
  if ('full_name' in p && p.full_name != null) row.full_name = p.full_name;
  if ('username' in p && p.username != null) row.username = p.username;
  if ('bio' in p && p.bio != null) row.bio = p.bio;
  if ('avatar_url' in p && p.avatar_url != null) row.avatar_url = p.avatar_url;
  if (p.set_username_changed_at) row.username_changed_at = new Date().toISOString();

  const { error } = await admin.from('user_profiles').upsert(row, { onConflict: 'id' });
  if (error) {
    // Unique violation on username → 409 so the client can surface "taken".
    if ((error as { code?: string }).code === '23505') {
      return json(409, { error: 'That username is taken.' });
    }
    return json(400, { error: error.message });
  }
  return json(200, { id: uid });
}
