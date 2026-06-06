// Shared OpenAI moderation gate. Every piece of user-generated text/image that
// the `content` Edge Function is about to persist runs through here first.
//
// Uses `omni-moderation-latest`, which screens text AND images in a single call:
// the `input` array mixes { type: "text" } and { type: "image_url" } items, and
// the response returns one result per item. If ANY item is flagged, the whole
// write is rejected.
//
// Fail-closed: if OpenAI errors, times out, or the key is missing, we treat the
// content as rejected (with a "couldn't verify" message) rather than letting it
// through unmoderated. An outage must never silently disable moderation.

const OPENAI_URL = 'https://api.openai.com/v1/moderations';
const MODEL = 'omni-moderation-latest';
const TIMEOUT_MS = 6000;

// ─────────────────────────────────────────────────────────────────────────────
// Block policy — per-category score thresholds (NOT OpenAI's raw `flagged`).
//
// Nook is a movies / TV / anime / games community: violent and dark themes are
// the subject matter, so the raw `flagged` boolean rejects normal reviews ("the
// killer murders the family", a GTA review, etc.). Instead we block only on the
// genuinely-harmful categories above a confidence threshold, and we apply
// SEPARATE thresholds to text vs images:
//   * TEXT  — lenient on violence/criticism; we still block real threats, hate,
//     explicit sexual text, CSAM, and genuine self-harm intent.
//   * IMAGE — zero tolerance for sexual content / nudity (very low `sexual`
//     threshold), but generic media violence (e.g. an action-movie banner) is
//     allowed.
// A category absent from a map is NEVER blocked on (e.g. generic `violence`,
// harsh `harassment` criticism). Tune the numbers here.
// ─────────────────────────────────────────────────────────────────────────────

const TEXT_THRESHOLDS: Record<string, number> = {
  'sexual/minors': 0.2,
  sexual: 0.63,
  hate: 0.6,
  'hate/threatening': 0.5,
  'harassment/threatening': 0.5,
  'self-harm/intent': 0.85,
  'self-harm/instructions': 0.5,
  // Real-world violent incitement ("let's bomb some houses", "burn down their
  // house") scores 0.17-0.45 here, while *reviewing* violent media (war docs,
  // GTA, a terrorist novel) scores <0.1 — so 0.15 catches incitement without
  // touching media talk. Pairs with `violence` 0.85 (which catches blatant
  // first-person violent statements that this category misses).
  'illicit/violent': 0.15,
  // Note: text `sexual` is 0.63 (was 0.7, tightened 10% for safety). Allows
  // discussing sexual themes in media; blocks explicit sexual text.
  // First-person / direct violent statements ("I want to kill everyone") score
  // ~0.95, while legit media titles & reviews ("Goriest Horror Kills", "the
  // killer murders the family") score ~0.45-0.6. 0.85 catches the former while
  // letting media talk through. Raise toward 0.9 if graphic reviews get caught;
  // lower toward 0.8 to be stricter (at the cost of more review false-positives).
  violence: 0.85,
};

const IMAGE_THRESHOLDS: Record<string, number> = {
  'sexual/minors': 0.2, // CSAM — zero tolerance, never raise
  // Blocks nudity + sexual/revealing clothing (lingerie etc.) while letting
  // ordinary swimwear/beach art through (swimwear scores ~0; explicit ~0.8+).
  // Tuned 10% stricter (0.5 -> 0.45) for safety. Raise if swimwear is wrongly
  // caught; lower toward 0.4 to be stricter still.
  sexual: 0.45,
  hate: 0.6,
  'hate/threatening': 0.5,
  'harassment/threatening': 0.5,
  'self-harm/intent': 0.7,
  'self-harm/instructions': 0.5,
  'illicit/violent': 0.6,
  'violence/graphic': 0.9, // only extreme gore images; normal media violence is fine
};

// Sexual solicitation ("send me nudes", "show me your tits", "dm your hot pics")
// scores the SAME as legit media sex-talk on OpenAI's `sexual` axis (~0.2-0.4),
// so a threshold can't catch it. We match against a NORMALIZED form of the text
// (lowercased, de-leetspeked, symbols stripped) so common evasions collapse:
// b00bs->boobs, s3nd->send, "f***"->"f", "titspls"->"titspls" (boundary handled).
// Caveat (accepted tradeoff): still defeatable by spacing/odd spelling, and won't
// catch fully-censored verbs ("i *** u up"); may rarely catch meta-discussion.
function normalizeForMatch(s: string): string {
  return s
    .toLowerCase()
    .replace(/0/g, 'o')
    .replace(/[1!|]/g, 'i')
    .replace(/3/g, 'e')
    .replace(/4/g, 'a')
    .replace(/5/g, 's')
    .replace(/7/g, 't')
    .replace(/\$/g, 's')
    .replace(/@/g, 'a')
    .replace(/[^a-z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Request verbs only. Bare "show"/"post"/"drop" are excluded because they're
// also nouns ("the SHOW has nude scenes", "this POST") — we require "show me/us".
// A request verb is what separates "this character has nice tits" (allowed,
// describing media) from "show me your tits" (blocked, directed at a person).
const SOLICIT_VERB =
  '(send|sent|sending|gimme|give me|dm|lemme see|let me see|can i see|wanna see|got any|you got|u got|show me|show us)';
// Body parts: most allow a glued suffix (titspls), but "ass" keeps a trailing
// boundary so it doesn't fire on "assignment"/"assassin".
const SEXUAL_SOLICITATION: RegExp[] = [
  new RegExp(`\\b${SOLICIT_VERB}\\b.{0,25}\\b(nudes?|nudez|noods?|noodz)`),
  new RegExp(
    `\\b${SOLICIT_VERB}\\b.{0,20}\\b(your )?(tits|titties|titty|tiddies|boobs|boobies|asshole|dick|cock|pussy|coochie|genitals?|ass\\b)`,
  ),
  new RegExp(
    `\\b${SOLICIT_VERB}\\b.{0,20}\\b(hot|sexy|nude|naked|lewd) (pic|pics|photo|photos|selfie|selfies|vid|vids)`,
  ),
  // Clear sexual advances (kept narrow; ambiguous "link up/hook up" excluded so
  // "let's hook up the console" isn't flagged).
  /\b(lets|let s|wanna|want to|can we|down to|tryna|u tryna|you tryna)\b.{0,15}\b(have sex|netflix and chill|sleep with|fuck tonight|fuck rn|smash tonight)\b/,
];

function isSexualSolicitation(text: string): boolean {
  const n = normalizeForMatch(text);
  return SEXUAL_SOLICITATION.some((re) => re.test(n));
}

type InputKind = 'text' | 'image';

export interface ModerationInput {
  text?: string | null;
  imageUrl?: string | null;
}

export interface ModerationResult {
  flagged: boolean;
  categories: string[];
  /** Set when we could not get a verdict from OpenAI (fail-closed reject). */
  unavailable?: boolean;
}

interface OpenAIModerationResponse {
  results: Array<{
    flagged: boolean;
    categories: Record<string, boolean>;
    category_scores: Record<string, number>;
  }>;
}

/**
 * Run all inputs through OpenAI moderation in one request.
 * Empty/whitespace-only text and empty image URLs are skipped. If nothing is
 * left to moderate, returns { flagged: false } (e.g. an avatar-only update).
 */
/** One moderation HTTP call with retry/backoff for transient failures. Returns
 *  parsed results, or null if it couldn't get a verdict (caller fails closed).
 *
 *  Retries on 429 (rate limit), 5xx, network/abort, and `image_url_unavailable`
 *  — the last one happens when OpenAI tries to fetch a just-uploaded image before
 *  Supabase's CDN has propagated it (a race on quick re-submits). Permanent
 *  errors (bad key, too_many_images, malformed) fail fast. */
async function callModeration(
  apiKey: string,
  payloadInputs: Array<Record<string, unknown>>,
): Promise<OpenAIModerationResponse | null> {
  const MAX_ATTEMPTS = 3;
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const res = await fetch(OPENAI_URL, {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: MODEL, input: payloadInputs }),
        signal: controller.signal,
      });
      if (res.ok) return (await res.json()) as OpenAIModerationResponse;
      const bodyText = await res.text().catch(() => '');
      // Retry transient failures; permanent ones (bad key, malformed) give up.
      const retryable =
        res.status === 429 || res.status >= 500 || bodyText.includes('image_url_unavailable');
      console.error(
        '[moderation] OpenAI',
        res.status,
        bodyText.slice(0, 200),
        retryable ? '(will retry)' : '',
      );
      if (!retryable) return null;
    } catch (err) {
      // network/abort error — fall through to backoff + retry
      console.error('[moderation] fetch error:', err);
    } finally {
      clearTimeout(timer);
    }
    // Backoff before the next attempt — gives the CDN time to propagate and eases
    // any rate limit. 0.6s, then 1.2s.
    if (attempt < MAX_ATTEMPTS - 1) await new Promise((r) => setTimeout(r, 600 * (attempt + 1)));
  }
  return null;
}

function evaluate(results: OpenAIModerationResponse, kind: InputKind, out: Set<string>): boolean {
  let flagged = false;
  const thresholds = kind === 'image' ? IMAGE_THRESHOLDS : TEXT_THRESHOLDS;
  for (const result of results.results ?? []) {
    const cs = result.category_scores ?? {};
    for (const [name, threshold] of Object.entries(thresholds)) {
      if ((cs[name] ?? 0) >= threshold) {
        flagged = true;
        out.add(name);
      }
    }
    // Composite: directed real-world threat. Fictional/media violence scores high
    // on `violence` but near-zero on `harassment` (narration, not aimed at a
    // person); a real threat scores high on BOTH; harsh criticism ("the writers
    // are idiots") is high `harassment` but low `violence`, so it stays clear.
    if (kind === 'text' && (cs['harassment'] ?? 0) >= 0.5 && (cs['violence'] ?? 0) >= 0.5) {
      flagged = true;
      out.add('threat');
    }
  }
  return flagged;
}

export async function moderateInputs(inputs: ModerationInput[]): Promise<ModerationResult> {
  const apiKey = Deno.env.get('OPENAI_API_KEY');
  if (!apiKey) {
    console.error('[moderation] OPENAI_API_KEY is not set');
    return { flagged: true, categories: ['service_unavailable'], unavailable: true };
  }

  const texts: string[] = [];
  const imageUrls: string[] = [];
  for (const input of inputs) {
    const text = input.text?.trim();
    if (text) texts.push(text);
    if (input.imageUrl) imageUrls.push(input.imageUrl);
  }
  if (texts.length === 0 && imageUrls.length === 0) return { flagged: false, categories: [] };

  // Local phrase check for sexual solicitation (OpenAI can't separate it by score).
  // A match blocks immediately — no need to call OpenAI or check images.
  for (const t of texts) {
    if (isSexualSolicitation(t)) {
      return { flagged: true, categories: ['sexual_solicitation'] };
    }
  }

  // OpenAI moderation allows only ONE image per request, so we batch all text
  // into a single call and send each image as its own call — all in parallel.
  const jobs: Array<{ kind: InputKind; promise: Promise<OpenAIModerationResponse | null> }> = [];
  if (texts.length > 0) {
    jobs.push({
      kind: 'text',
      promise: callModeration(
        apiKey,
        texts.map((t) => ({ type: 'text', text: t })),
      ),
    });
  }
  for (const url of imageUrls) {
    jobs.push({
      kind: 'image',
      promise: callModeration(apiKey, [{ type: 'image_url', image_url: { url } }]),
    });
  }

  const settled = await Promise.all(jobs.map((j) => j.promise));

  const flaggedCategories = new Set<string>();
  let flagged = false;
  for (let i = 0; i < jobs.length; i++) {
    const data = settled[i];
    if (!data) {
      // Couldn't verify one of the inputs — fail closed.
      return { flagged: true, categories: ['service_unavailable'], unavailable: true };
    }
    if (evaluate(data, jobs[i].kind, flaggedCategories)) flagged = true;
  }
  return { flagged, categories: [...flaggedCategories] };
}

/** JSON body for a moderation rejection (HTTP 422). */
export function moderationRejection(result: ModerationResult): {
  status: number;
  body: Record<string, unknown>;
} {
  if (result.unavailable) {
    return {
      status: 503,
      body: {
        error: "We couldn't verify your content right now. Please try again in a moment.",
        categories: result.categories,
      },
    };
  }
  return {
    status: 422,
    body: {
      error: 'Your content was flagged as violating our community guidelines and was not posted.',
      categories: result.categories,
    },
  };
}
