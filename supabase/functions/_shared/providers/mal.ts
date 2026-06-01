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
  const titles = attrs.titles as Record<string, string> | undefined;
  return titles?.en || (attrs.canonicalTitle as string) || titles?.en_jp || '';
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

  const resp = await fetch(`${BASE_URL}/${kitsuType}/${sourceId}?include=genres`, {
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

  // Parse genres from the included sideloaded data (via ?include=genres)
  const included = (data.included || []) as Array<Record<string, unknown>>;
  const genres: string[] = included
    .filter((item) => item.type === 'genres')
    .map((g) => (g.attributes as Record<string, string>)?.name || '')
    .filter(Boolean);

  const ratingCount = attrs.userCount as number | null;

  // Fetch similar titles — combine direct relationships + category-based discovery
  const recommendations = await fetchSimilar(sourceId, mediaType, kitsuType);

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
    related: recommendations.length > 0 ? { recommendations } : null,
  };
}

/**
 * Smart similar-content discovery for Kitsu.
 *
 * Strategy:
 * 1. Fetch direct media-relationships (sequels, prequels, side stories,
 *    adaptations, spin-offs) with the destination media sideloaded.
 * 2. If we still have fewer than 4, fetch the item's categories and search
 *    for other highly-rated titles in the same categories to fill the gap.
 *
 * Results are capped at 4 and deduplicated against the current item.
 */
async function fetchSimilar(
  sourceId: string,
  mediaType: string,
  kitsuType: string,
): Promise<SearchResult[]> {
  const results: SearchResult[] = [];
  const seenIds = new Set<string>([sourceId]);

  // --- Phase 1: Direct relationships ---
  try {
    const relResp = await fetch(
      `${BASE_URL}/${kitsuType}/${sourceId}/media-relationships?include=destination&page[limit]=10`,
      { headers: JSONAPI_HEADERS },
    );

    if (relResp.ok) {
      const relData = await relResp.json();
      const included = (relData.included || []) as Array<Record<string, unknown>>;

      // Build a lookup of included media by type+id
      const mediaMap = new Map<string, Record<string, unknown>>();
      for (const item of included) {
        if (item.type === 'anime' || item.type === 'manga') {
          mediaMap.set(`${item.type}:${item.id}`, item);
        }
      }

      // Walk relationships and resolve destinations
      const rels = (relData.data || []) as Array<Record<string, unknown>>;
      for (const rel of rels) {
        if (results.length >= 4) break;

        const dest = (rel.relationships as Record<string, unknown>)?.destination as
          | Record<string, unknown>
          | undefined;
        const destData = (dest?.data as Record<string, unknown>) || null;
        if (!destData) continue;

        const key = `${destData.type}:${destData.id}`;
        const media = mediaMap.get(key);
        if (!media || seenIds.has(String(media.id))) continue;

        const attrs = media.attributes as Record<string, unknown>;
        const img = imageUrl(attrs.posterImage as Record<string, unknown>);
        if (!img) continue; // skip items with no poster

        seenIds.add(String(media.id));
        results.push({
          media_id: String(media.id),
          source: 'kitsu',
          media_type: mediaType,
          title: getTitle(attrs),
          image_url: img,
          year: getYear(attrs.startDate as string),
          score: getScore(attrs.averageRating as string),
        });
      }
    }
  } catch {
    // Non-critical — continue to phase 2
  }

  // --- Phase 2: Category-based discovery (fill remaining slots) ---
  if (results.length < 4) {
    try {
      // Get categories for this item
      const catResp = await fetch(`${BASE_URL}/${kitsuType}/${sourceId}/categories?page[limit]=3`, {
        headers: JSONAPI_HEADERS,
      });

      if (catResp.ok) {
        const catData = await catResp.json();
        const categories = (catData.data || []) as Array<Record<string, unknown>>;

        if (categories.length > 0) {
          // Pick the most specific category (smallest totalMediaCount)
          const sorted = [...categories].sort((a, b) => {
            const countA =
              ((a.attributes as Record<string, unknown>)?.totalMediaCount as number) || Infinity;
            const countB =
              ((b.attributes as Record<string, unknown>)?.totalMediaCount as number) || Infinity;
            return countA - countB;
          });

          const catSlug = (sorted[0].attributes as Record<string, unknown>)?.slug as string;
          if (catSlug) {
            const needed = 4 - results.length;
            // Fetch popular titles in this category, sorted by rating
            const discoverResp = await fetch(
              `${BASE_URL}/${kitsuType}?filter[categories]=${catSlug}&sort=-averageRating&page[limit]=${needed + 5}`,
              { headers: JSONAPI_HEADERS },
            );

            if (discoverResp.ok) {
              const discoverData = await discoverResp.json();
              const items = (discoverData.data || []) as Array<Record<string, unknown>>;

              for (const item of items) {
                if (results.length >= 4) break;
                if (seenIds.has(String(item.id))) continue;

                const attrs = item.attributes as Record<string, unknown>;
                const img = imageUrl(attrs.posterImage as Record<string, unknown>);
                if (!img) continue;

                seenIds.add(String(item.id));
                results.push({
                  media_id: String(item.id),
                  source: 'kitsu',
                  media_type: mediaType,
                  title: getTitle(attrs),
                  image_url: img,
                  year: getYear(attrs.startDate as string),
                  score: getScore(attrs.averageRating as string),
                });
              }
            }
          }
        }
      }
    } catch {
      // Non-critical
    }
  }

  return results;
}
