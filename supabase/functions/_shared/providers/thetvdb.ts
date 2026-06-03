// TheTVDB provider — movies + TV shows
// Replaces TMDB. Uses TheTVDB v4 API with bearer token auth.
import type { SearchResponse, SearchResult, MediaDetail } from '../types.ts';

const BASE_URL = 'https://api4.thetvdb.com/v4';

// Module-level token cache
let cachedToken: string | null = null;
let tokenExpiry = 0;

function getApiKey(): string {
  const key = Deno.env.get('THETVDB_API_KEY');
  if (!key) throw new Error('THETVDB_API_KEY is not set');
  return key;
}

async function getToken(): Promise<string> {
  const now = Date.now() / 1000;
  // Token lasts ~1 month, refresh with 1 day buffer
  if (cachedToken && tokenExpiry > now + 86400) {
    return cachedToken;
  }

  const resp = await fetch(`${BASE_URL}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ apikey: getApiKey() }),
  });

  if (!resp.ok) {
    throw new Error(`TheTVDB login error: ${resp.status} ${resp.statusText}`);
  }

  const data = await resp.json();
  cachedToken = data.data.token;
  // JWT tokens from TheTVDB last ~30 days, set expiry conservatively
  tokenExpiry = now + 28 * 24 * 3600;
  return cachedToken!;
}

async function tvdbFetch(path: string): Promise<Record<string, unknown>> {
  const token = await getToken();
  const resp = await fetch(`${BASE_URL}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!resp.ok) {
    throw new Error(`TheTVDB error: ${resp.status} ${resp.statusText} on ${path}`);
  }
  return await resp.json();
}

function getReadableDuration(minutes: number | null | undefined): string | null {
  if (!minutes) return null;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

export async function search(
  mediaType: string,
  query: string,
  page: number,
): Promise<SearchResponse> {
  const tvdbType = mediaType === 'tv' ? 'series' : 'movie';
  const limit = 24;
  const offset = (page - 1) * limit;

  const params = new URLSearchParams({
    query,
    type: tvdbType,
    limit: String(limit),
    offset: String(offset),
  });

  const data = await tvdbFetch(`/search?${params}`);
  const items = (data.data as Array<Record<string, unknown>>) || [];

  const results: SearchResult[] = items
    .filter((item) => item.primary_language !== 'jpn')
    .map((item) => ({
      media_id: String(item.tvdb_id),
      source: 'thetvdb',
      media_type: mediaType,
      title: (item.name as string) || '',
      image_url: (item.image_url as string) || null,
      year: (item.year as string) || null,
      score: null,
    }));

  // TheTVDB search doesn't return total count, estimate from results
  const hasMore = results.length === limit;

  return {
    results,
    page,
    total_pages: hasMore ? page + 1 : page,
    per_page: limit,
  };
}

export async function detail(sourceId: string, mediaType: string): Promise<MediaDetail> {
  const isMovie = mediaType === 'movie';
  const endpoint = isMovie ? 'movies' : 'series';

  const data = await tvdbFetch(`/${endpoint}/${sourceId}/extended`);
  const r = data.data as Record<string, unknown>;

  // Movies don't include overview in extended — fetch from translations
  let overview = (r.overview as string) || '';
  if (!overview) {
    try {
      const transData = await tvdbFetch(`/${endpoint}/${sourceId}/translations/eng`);
      const trans = transData.data as Record<string, unknown>;
      overview = (trans.overview as string) || '';
    } catch {
      // translation fetch is optional
    }
  }

  const genres = ((r.genres as Array<Record<string, string>>) || []).map((g) => g.name);

  const statusObj = r.status as Record<string, unknown> | undefined;
  const statusName = statusObj?.name as string | undefined;

  // Build details based on type
  const details: Record<string, unknown> = {
    format: isMovie ? 'Movie' : 'TV',
    status: statusName || null,
  };

  if (isMovie) {
    // Movie-specific fields
    const releases = (r.releases as Array<Record<string, string>>) || [];
    const usRelease = releases.find((rel) => rel.country === 'usa');
    details.release_date = usRelease?.date || releases[0]?.date || null;
    const movieRuntime = r.runtime as number | null;
    details.runtime = getReadableDuration(movieRuntime);
    if (movieRuntime) details.runtime_minutes = movieRuntime;

    const studios = (r.studios as Array<Record<string, unknown>>) || [];
    details.studios = studios.length > 0 ? studios.map((s) => s.name as string) : null;

    // Extract director from characters
    const characters = (r.characters as Array<Record<string, unknown>>) || [];
    const director = characters.find((c) => (c.peopleType as string) === 'Director');
    details.director = director ? (director.personName as string) : null;
  } else {
    // TV series-specific fields
    details.first_air_date = (r.firstAired as string) || null;
    details.end_date = (r.lastAired as string) || null;
    const avgRuntime = r.averageRuntime as number | null;
    details.runtime = getReadableDuration(avgRuntime);
    if (avgRuntime) details.runtime_minutes = avgRuntime;

    const network = r.originalNetwork as Record<string, unknown> | undefined;
    details.network = network?.name || null;

    // Count episodes from seasons
    const seasons = (r.seasons as Array<Record<string, unknown>>) || [];
    // Filter to official aired seasons (type.id === 1), exclude specials (number === 0)
    const officialSeasons = seasons.filter((s) => {
      const sType = s.type as Record<string, unknown> | undefined;
      return sType?.id === 1 && (s.number as number) > 0;
    });
    details.seasons = officialSeasons.length || null;

    const companies = (r.companies as Array<Record<string, unknown>>) || [];
    details.studios =
      companies.length > 0 ? companies.slice(0, 3).map((c) => c.name as string) : null;
  }

  // Episode count for TV series
  let maxProgress: number | null = null;
  if (isMovie) {
    maxProgress = 1;
  } else {
    try {
      let totalEpisodes = 0;
      let page = 0;
      const pageSize = 100;
      while (true) {
        const epData = await tvdbFetch(`/series/${sourceId}/episodes/official?page=${page}`);
        const epRecord = epData.data as Record<string, unknown> | null;
        const episodes = (epRecord?.episodes as Array<unknown>) || [];
        totalEpisodes += episodes.length;
        if (episodes.length < pageSize) break;
        page++;
      }
      if (totalEpisodes > 0) {
        maxProgress = totalEpisodes;
        details.episodes = totalEpisodes;
      }
    } catch {
      // episode count is optional
    }
  }

  // TheTVDB score is a popularity hint, not a user rating — don't display it
  const score = null;

  // Fetch similar titles via genre-based search
  const recommendations = await fetchSimilar(sourceId, mediaType, genres);

  return {
    media_id: String(r.id),
    source: 'thetvdb',
    media_type: mediaType,
    source_url: isMovie
      ? `https://www.thetvdb.com/movies/${r.slug}`
      : `https://www.thetvdb.com/series/${r.slug}`,
    title: (r.name as string) || '',
    image_url: (r.image as string) || null,
    synopsis: overview || 'No synopsis available.',
    genres,
    score,
    score_count: null,
    max_progress: maxProgress,
    details,
    related: recommendations.length > 0 ? { recommendations } : null,
  };
}

/**
 * Find similar titles by searching for the primary genre and filtering out the
 * current item. TheTVDB doesn't have a dedicated recommendations endpoint, so
 * genre-based search is the best proxy.
 */
async function fetchSimilar(
  currentId: string,
  mediaType: string,
  genres: string[],
): Promise<SearchResult[]> {
  if (genres.length === 0) return [];

  try {
    const tvdbType = mediaType === 'tv' ? 'series' : 'movie';
    // Search by the first (most specific) genre
    const params = new URLSearchParams({
      query: genres[0],
      type: tvdbType,
      limit: '12',
    });

    const data = await tvdbFetch(`/search?${params}`);
    const items = (data.data as Array<Record<string, unknown>>) || [];

    return items
      .filter(
        (item) =>
          String(item.tvdb_id) !== currentId && item.primary_language !== 'jpn' && item.image_url,
      )
      .slice(0, 4)
      .map((item) => ({
        media_id: String(item.tvdb_id),
        source: 'thetvdb',
        media_type: mediaType,
        title: (item.name as string) || '',
        image_url: (item.image_url as string) || null,
        year: (item.year as string) || null,
        score: null,
      }));
  } catch {
    // Recommendations are non-critical — don't fail the detail request
    return [];
  }
}
