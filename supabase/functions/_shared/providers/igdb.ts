// IGDB provider — video games
// Uses the IGDB v4 API (Apicalypse query language) with Twitch OAuth.
// Auth: exchange client id/secret for an app access token at id.twitch.tv,
// then send `Client-ID` + `Authorization: Bearer` on every request.
import type { SearchResponse, SearchResult, MediaDetail } from '../types.ts';

const BASE_URL = 'https://api.igdb.com/v4';
const TOKEN_URL = 'https://id.twitch.tv/oauth2/token';
const IMAGE_BASE = 'https://images.igdb.com/igdb/image/upload';

// IGDB themes we treat as NSFW and exclude from search (42 = Erotic).
const NSFW_THEME = 42;

// Module-level token cache (edge worker lifetime)
let cachedToken: string | null = null;
let tokenExpiry = 0;

function getCredentials(): { id: string; secret: string } {
  const id = Deno.env.get('IGDB_CLIENT_ID');
  const secret = Deno.env.get('IGDB_CLIENT_SECRET');
  if (!id || !secret) {
    throw new Error('IGDB_CLIENT_ID and IGDB_CLIENT_SECRET are not set');
  }
  return { id, secret };
}

async function getToken(forceRefresh = false): Promise<string> {
  const now = Date.now() / 1000;
  if (!forceRefresh && cachedToken && tokenExpiry > now + 60) {
    return cachedToken;
  }

  const { id, secret } = getCredentials();
  const params = new URLSearchParams({
    client_id: id,
    client_secret: secret,
    grant_type: 'client_credentials',
  });

  const resp = await fetch(`${TOKEN_URL}?${params}`, { method: 'POST' });
  if (!resp.ok) {
    throw new Error(`IGDB token error: ${resp.status} ${resp.statusText}`);
  }

  const data = await resp.json();
  cachedToken = data.access_token as string;
  // Refresh 60s before the real expiry to avoid using an expired token.
  tokenExpiry = now + (data.expires_in as number) - 60;
  return cachedToken;
}

/// Pre-fetch the auth token so the first real request on a warm worker is fast.
export async function warm(): Promise<void> {
  await getToken();
}

/**
 * POST an Apicalypse query to an IGDB endpoint. Retries once on 401 by
 * forcing a fresh token (the cached one was revoked or expired early).
 */
async function igdbQuery<T = Record<string, unknown>>(endpoint: string, query: string): Promise<T> {
  const { id } = getCredentials();

  const run = async (token: string) =>
    fetch(`${BASE_URL}/${endpoint}`, {
      method: 'POST',
      headers: {
        'Client-ID': id,
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      },
      body: query,
    });

  let resp = await run(await getToken());
  if (resp.status === 401) {
    resp = await run(await getToken(true));
  }

  if (!resp.ok) {
    const body = await resp.text().catch(() => '');
    throw new Error(`IGDB ${endpoint} error: ${resp.status} ${resp.statusText} ${body}`.trim());
  }

  return (await resp.json()) as T;
}

// --- Field helpers ---

interface IgdbImage {
  image_id?: string;
}

interface IgdbGameRef {
  id: number;
  name?: string;
  cover?: IgdbImage;
  first_release_date?: number;
  total_rating?: number;
}

function coverUrl(game: { cover?: IgdbImage } | undefined, size = 'cover_big'): string | null {
  const imageId = game?.cover?.image_id;
  if (!imageId) return null;
  return `${IMAGE_BASE}/t_${size}/${imageId}.jpg`;
}

function getScore(totalRating: number | undefined): number | null {
  if (totalRating === undefined || totalRating === null) return null;
  // IGDB total_rating is 0-100 → convert to 0-10.
  return Math.round((totalRating / 10) * 10) / 10;
}

function getYear(firstReleaseDate: number | undefined): string | null {
  if (!firstReleaseDate) return null;
  return String(new Date(firstReleaseDate * 1000).getUTCFullYear());
}

function getReleaseDate(firstReleaseDate: number | undefined): string | null {
  if (!firstReleaseDate) return null;
  return new Date(firstReleaseDate * 1000).toISOString().substring(0, 10);
}

const GAME_TYPE_MAP: Record<number, string> = {
  0: 'Main Game',
  1: 'DLC',
  2: 'Expansion',
  3: 'Bundle',
  4: 'Standalone Expansion',
  5: 'Mod',
  6: 'Episode',
  7: 'Season',
  8: 'Remake',
  9: 'Remaster',
  10: 'Expanded Game',
  11: 'Port',
  12: 'Fork',
  13: 'Pack',
  14: 'Update',
};

function getFormat(gameType: number | undefined): string {
  if (gameType === undefined) return 'Game';
  return GAME_TYPE_MAP[gameType] || 'Game';
}

function getNames(items: Array<{ name?: string }> | undefined): string[] {
  if (!items) return [];
  return items.map((i) => i.name).filter((n): n is string => Boolean(n));
}

// Platform names from IGDB are sometimes verbose — tidy the common ones.
const PLATFORM_CLEANUP: Record<string, string> = {
  'PC (Microsoft Windows)': 'PC',
  Mac: 'macOS',
};

function getPlatforms(platforms: Array<{ name?: string }> | undefined): string[] {
  const names = getNames(platforms).map((n) => PLATFORM_CLEANUP[n] || n);
  return [...new Set(names)];
}

interface IgdbCompany {
  developer?: boolean;
  publisher?: boolean;
  company?: { name?: string };
}

/** Prefer developer studios; fall back to any involved company. */
function getCompanies(involved: IgdbCompany[] | undefined): string | null {
  if (!involved || involved.length === 0) return null;
  const name = (c: IgdbCompany) => c.company?.name;
  const developers = involved
    .filter((c) => c.developer)
    .map(name)
    .filter(Boolean) as string[];
  const chosen =
    developers.length > 0 ? developers : (involved.map(name).filter(Boolean) as string[]);
  const unique = [...new Set(chosen)];
  return unique.length > 0 ? unique.join(', ') : null;
}

function getPublishers(involved: IgdbCompany[] | undefined): string[] {
  if (!involved) return [];
  const names = involved
    .filter((c) => c.publisher)
    .map((c) => c.company?.name)
    .filter((n): n is string => Boolean(n));
  return [...new Set(names)];
}

function toSearchResult(game: IgdbGameRef): SearchResult {
  return {
    media_id: String(game.id),
    source: 'igdb',
    media_type: 'game',
    title: game.name || '',
    image_url: coverUrl(game),
    year: getYear(game.first_release_date),
    score: getScore(game.total_rating),
  };
}

// --- Public API ---

export async function search(query: string, page: number): Promise<SearchResponse> {
  const limit = 20;
  const offset = (page - 1) * limit;

  // Escape quotes/backslashes so user input can't break out of the string literal.
  const safe = query.replace(/["\\]/g, '\\$&');
  const conditions = `where name ~ *"${safe}"* & game_type = (0,1,2,3,4,5,6,7,8,9,10) & themes != (${NSFW_THEME})`;

  const multiquery =
    `query games "results" {` +
    `fields name,cover.image_id,first_release_date,total_rating;` +
    `sort total_rating_count desc;` +
    `limit ${limit};offset ${offset};${conditions};` +
    `};` +
    `query games/count "count" {${conditions};};`;

  const response = await igdbQuery<Array<Record<string, unknown>>>('multiquery', multiquery);

  const games =
    (response.find((r) => r.name === 'results')?.result as Array<
      IgdbGameRef & { first_release_date?: number; total_rating?: number }
    >) || [];
  const totalCount = (response.find((r) => r.name === 'count')?.count as number) || 0;

  const results: SearchResult[] = games.map((game) => ({
    media_id: String(game.id),
    source: 'igdb',
    media_type: 'game',
    title: game.name || '',
    image_url: coverUrl(game),
    year: getYear(game.first_release_date),
    score: getScore(game.total_rating),
  }));

  const totalPages = Math.max(1, Math.ceil(totalCount / limit));

  return {
    results,
    page,
    total_pages: totalPages,
    per_page: limit,
  };
}

interface IgdbGameDetail extends IgdbGameRef {
  url?: string;
  summary?: string;
  game_type?: number;
  first_release_date?: number;
  total_rating?: number;
  total_rating_count?: number;
  genres?: Array<{ name?: string }>;
  themes?: Array<{ name?: string }>;
  platforms?: Array<{ name?: string }>;
  involved_companies?: IgdbCompany[];
  similar_games?: IgdbGameRef[];
  expansions?: IgdbGameRef[];
  standalone_expansions?: IgdbGameRef[];
  expanded_games?: IgdbGameRef[];
  dlcs?: IgdbGameRef[];
  remakes?: IgdbGameRef[];
  remasters?: IgdbGameRef[];
  parent_game?: IgdbGameRef;
}

export async function detail(sourceId: string): Promise<MediaDetail> {
  const fields =
    `fields name,cover.image_id,url,summary,game_type,first_release_date,` +
    `total_rating,total_rating_count,genres.name,themes.name,platforms.name,` +
    `involved_companies.developer,involved_companies.publisher,involved_companies.company.name,` +
    `similar_games.name,similar_games.cover.image_id,similar_games.first_release_date,similar_games.total_rating,` +
    `expansions.name,expansions.cover.image_id,expansions.first_release_date,expansions.total_rating,` +
    `standalone_expansions.name,standalone_expansions.cover.image_id,standalone_expansions.first_release_date,standalone_expansions.total_rating,` +
    `expanded_games.name,expanded_games.cover.image_id,expanded_games.first_release_date,expanded_games.total_rating,` +
    `dlcs.name,dlcs.cover.image_id,dlcs.first_release_date,dlcs.total_rating,` +
    `remakes.name,remakes.cover.image_id,remakes.first_release_date,remakes.total_rating,` +
    `remasters.name,remasters.cover.image_id,remasters.first_release_date,remasters.total_rating,` +
    `parent_game.name,parent_game.cover.image_id,parent_game.first_release_date,parent_game.total_rating;`;

  const query = `${fields}where id = ${Number(sourceId)};`;
  const response = await igdbQuery<IgdbGameDetail[]>('games', query);

  if (!response || response.length === 0) {
    throw new Error(`IGDB game not found: ${sourceId}`);
  }

  const game = response[0];
  const releaseDate = getReleaseDate(game.first_release_date);

  // Derive a status from the release date (IGDB has no reliable status field).
  let status: string | null = null;
  if (game.first_release_date) {
    status = game.first_release_date * 1000 > Date.now() ? 'Upcoming' : 'Released';
  }

  const publishers = getPublishers(game.involved_companies);

  const details: Record<string, unknown> = {
    format: getFormat(game.game_type),
    release_date: releaseDate,
    status,
    platforms: getPlatforms(game.platforms),
    companies: getCompanies(game.involved_companies),
    publishers: publishers.length > 0 ? publishers : null,
    themes: getNames(game.themes),
  };

  // Build a recommendations list from similar games plus related entries
  // (expansions, DLC, remakes…). Dedup by id, require a cover, cap at 12.
  const recommendations = buildRecommendations(game);

  return {
    media_id: String(game.id),
    source: 'igdb',
    media_type: 'game',
    source_url: game.url || `https://www.igdb.com/games/${sourceId}`,
    title: game.name || '',
    image_url: coverUrl(game, '720p'),
    synopsis: game.summary || 'No synopsis available.',
    genres: getNames(game.genres),
    score: getScore(game.total_rating),
    score_count: game.total_rating_count ?? null,
    max_progress: null,
    details,
    related: recommendations.length > 0 ? { recommendations } : null,
  };
}

function buildRecommendations(game: IgdbGameDetail): SearchResult[] {
  const buckets: Array<IgdbGameRef[] | undefined> = [
    game.similar_games,
    game.expansions,
    game.dlcs,
    game.standalone_expansions,
    game.expanded_games,
    game.remakes,
    game.remasters,
    game.parent_game ? [game.parent_game] : undefined,
  ];

  const seen = new Set<number>([game.id]);
  const results: SearchResult[] = [];

  for (const bucket of buckets) {
    if (!bucket) continue;
    for (const ref of bucket) {
      if (results.length >= 12) break;
      if (!ref || seen.has(ref.id)) continue;
      const image = coverUrl(ref, '720p');
      if (!image) continue; // skip entries with no poster
      seen.add(ref.id);
      results.push({ ...toSearchResult(ref), image_url: image });
    }
  }

  return results;
}
