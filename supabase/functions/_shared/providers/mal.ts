// Kitsu provider — anime + manga
// Replaces MAL. No auth required, uses JSON:API format.
import type { SearchResponse, SearchResult, MediaDetail } from '../types.ts';

const BASE_URL = 'https://kitsu.io/api/edge';

const JSONAPI_HEADERS: HeadersInit = {
  Accept: 'application/vnd.api+json',
  'Content-Type': 'application/vnd.api+json',
};

function imageUrl(posterImage: Record<string, unknown> | undefined): string | null {
  if (!posterImage) return null;
  return (
    (posterImage.large as string) ||
    (posterImage.medium as string) ||
    (posterImage.original as string) ||
    null
  );
}

function getTitle(attrs: Record<string, unknown>): string {
  return (
    (attrs.canonicalTitle as string) ||
    ((attrs.titles as Record<string, string>)?.en as string) ||
    ((attrs.titles as Record<string, string>)?.en_jp as string) ||
    ''
  );
}

function getScore(averageRating: string | undefined): number | null {
  if (!averageRating) return null;
  const val = parseFloat(averageRating);
  if (isNaN(val)) return null;
  // Kitsu rating is 0-100, convert to 0-10
  return Math.round((val / 10) * 10) / 10;
}

function getYear(startDate: string | undefined): string | null {
  if (!startDate) return null;
  return startDate.substring(0, 4);
}

const STATUS_MAP: Record<string, string> = {
  current: 'Airing',
  finished: 'Finished',
  tba: 'TBA',
  unreleased: 'Upcoming',
  upcoming: 'Upcoming',
};

function getFormat(subtype: string | undefined): string {
  if (!subtype) return 'Unknown';
  const map: Record<string, string> = {
    TV: 'Anime',
    tv: 'Anime',
    OVA: 'OVA',
    ova: 'OVA',
    ONA: 'ONA',
    ona: 'ONA',
    movie: 'Movie',
    special: 'Special',
    music: 'Music',
    manga: 'Manga',
    novel: 'Novel',
    oneshot: 'One-shot',
    doujin: 'Doujin',
    manhua: 'Manhua',
    manhwa: 'Manhwa',
    oel: 'OEL',
  };
  return map[subtype] || subtype.charAt(0).toUpperCase() + subtype.slice(1);
}

export async function search(
  mediaType: string,
  query: string,
  page: number,
): Promise<SearchResponse> {
  const kitsuType = mediaType === 'manga' ? 'manga' : 'anime';
  const limit = 20;
  const offset = (page - 1) * limit;

  const params = new URLSearchParams({
    'filter[text]': query,
    'page[limit]': String(limit),
    'page[offset]': String(offset),
  });

  const resp = await fetch(`${BASE_URL}/${kitsuType}?${params}`, {
    headers: JSONAPI_HEADERS,
  });

  if (!resp.ok) {
    throw new Error(`Kitsu search error: ${resp.status} ${resp.statusText}`);
  }

  const data = await resp.json();
  const items = (data.data || []) as Array<Record<string, unknown>>;

  const results: SearchResult[] = items.map((item) => {
    const attrs = item.attributes as Record<string, unknown>;
    return {
      media_id: item.id as string,
      source: 'kitsu',
      media_type: mediaType,
      title: getTitle(attrs),
      image_url: imageUrl(attrs.posterImage as Record<string, unknown>),
      year: getYear(attrs.startDate as string),
      score: getScore(attrs.averageRating as string),
    };
  });

  // Use meta.count if available, otherwise estimate
  const totalCount =
    (data.meta?.count as number) || (data.links?.next ? (page + 1) * limit : page * limit);
  const totalPages = Math.max(1, Math.ceil(totalCount / limit));

  return {
    results,
    page,
    total_pages: totalPages,
    per_page: limit,
  };
}

export async function detail(sourceId: string, mediaType: string): Promise<MediaDetail> {
  const isAnime = mediaType === 'anime';
  const kitsuType = isAnime ? 'anime' : 'manga';

  const resp = await fetch(`${BASE_URL}/${kitsuType}/${sourceId}`, {
    headers: JSONAPI_HEADERS,
  });

  if (!resp.ok) {
    throw new Error(`Kitsu detail error: ${resp.status} ${resp.statusText}`);
  }

  const data = await resp.json();
  const attrs = data.data.attributes as Record<string, unknown>;

  const details: Record<string, unknown> = {
    format: getFormat(attrs.subtype as string),
    start_date: (attrs.startDate as string) || null,
    end_date: (attrs.endDate as string) || null,
    status: STATUS_MAP[attrs.status as string] || (attrs.status as string) || null,
  };

  let maxProgress: number | null;

  if (isAnime) {
    const episodeCount = attrs.episodeCount as number | null;
    maxProgress = episodeCount || null;
    details.episodes = episodeCount || null;

    const epLength = attrs.episodeLength as number | null;
    if (epLength) {
      const h = Math.floor(epLength / 60);
      const m = epLength % 60;
      details.runtime = h > 0 ? `${h}h ${m}m` : `${m} min`;
    }
  } else {
    const chapterCount = attrs.chapterCount as number | null;
    const volumeCount = attrs.volumeCount as number | null;
    maxProgress = chapterCount || null;
    details.chapters = chapterCount || null;
    details.volumes = volumeCount || null;
  }

  // Kitsu doesn't include genres in the main attributes — they're in relationships
  // We'd need a separate request with ?include=genres, but for now we return empty
  // and can enhance later
  let genres: string[] = [];
  try {
    const genreResp = await fetch(`${BASE_URL}/${kitsuType}/${sourceId}/genres`, {
      headers: JSONAPI_HEADERS,
    });
    if (genreResp.ok) {
      const genreData = await genreResp.json();
      genres = ((genreData.data || []) as Array<Record<string, unknown>>)
        .map((g) => (g.attributes as Record<string, string>)?.name || '')
        .filter(Boolean);
    }
  } catch {
    // genres are optional, don't fail the whole detail
  }

  const ratingCount = attrs.userCount as number | null;

  return {
    media_id: String(data.data.id),
    source: 'kitsu',
    media_type: mediaType,
    source_url: `https://kitsu.io/${kitsuType}/${attrs.slug || sourceId}`,
    title: getTitle(attrs),
    image_url: imageUrl(attrs.posterImage as Record<string, unknown>),
    synopsis: (attrs.synopsis as string) || 'No synopsis available.',
    genres,
    score: getScore(attrs.averageRating as string),
    score_count: ratingCount,
    max_progress: maxProgress,
    details,
    related: null,
  };
}
