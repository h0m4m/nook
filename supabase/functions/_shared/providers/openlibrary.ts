import type { SearchResponse, SearchResult, MediaDetail } from '../types.ts';

const SEARCH_URL = 'https://openlibrary.org/search.json';
const USER_AGENT = 'Nook (mhdhomam2003@gmail.com)';

function olFetch(url: string): Promise<Response> {
  return fetch(url, { headers: { 'User-Agent': USER_AGENT } });
}

function imageUrl(coverId: number | undefined): string | null {
  if (!coverId) return null;
  return `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`;
}

function extractId(path: string | undefined): string | null {
  if (!path) return null;
  return path.replace(/\/$/, '').split('/').pop() || null;
}

export async function search(query: string, page: number): Promise<SearchResponse> {
  const limit = 15;
  const params = new URLSearchParams({
    q: query,
    fields: 'title,key,editions,editions.key,editions.cover_i,editions.title',
    limit: String(limit),
    page: String(page),
  });

  const resp = await olFetch(`${SEARCH_URL}?${params}`);
  if (!resp.ok) {
    throw new Error(`Open Library search error: ${resp.status} ${resp.statusText}`);
  }

  const data = await resp.json();

  const results: SearchResult[] = [];
  const seenTitles = new Set<string>();

  for (const doc of data.docs || []) {
    const editions = doc.editions?.docs;
    if (!editions || editions.length === 0) continue;

    const topEdition = editions[0];
    const mediaId = extractId(topEdition.key);
    if (!mediaId) continue;

    const title = doc.title;
    const editionTitle = topEdition.title;
    const displayTitle =
      editionTitle && editionTitle !== title ? `${editionTitle}: ${title}` : title;

    // Deduplicate by normalized title to collapse near-identical works
    const normalizedTitle = title.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (seenTitles.has(normalizedTitle)) continue;
    seenTitles.add(normalizedTitle);

    results.push({
      media_id: mediaId,
      source: 'openlibrary',
      media_type: 'book',
      title: displayTitle,
      image_url: imageUrl(topEdition.cover_i),
      year: null,
      score: null,
    });
  }

  const totalResults = data.numFound || 0;
  const totalPages = Math.max(1, Math.ceil(totalResults / limit));

  return {
    results,
    page,
    total_pages: totalPages,
    per_page: limit,
  };
}

export async function detail(sourceId: string): Promise<MediaDetail> {
  // sourceId is an edition key like "OL12345M"
  const bookUrl = `https://openlibrary.org/books/${sourceId}.json`;
  const bookResp = await olFetch(bookUrl);
  if (!bookResp.ok) {
    throw new Error(`Open Library book error: ${bookResp.status} ${bookResp.statusText}`);
  }
  const book = await bookResp.json();

  // Get the work for synopsis, authors, ratings
  let work: Record<string, unknown> = {};
  const works = book.works as Array<Record<string, string>> | undefined;
  let workId: string | null = null;

  if (works && works.length > 0) {
    workId = extractId(works[0].key);
    if (workId) {
      const workResp = await olFetch(`https://openlibrary.org/works/${workId}.json`);
      if (workResp.ok) {
        work = await workResp.json();
      }
    }
  }

  // Fetch ratings and authors in parallel
  const [ratingResult, authors] = await Promise.all([
    workId ? fetchRatings(workId) : Promise.resolve({ score: null, scoreCount: null }),
    fetchAuthors(work),
  ]);

  // Get cover image
  const covers = book.covers as number[] | undefined;
  const coverUrl = covers?.length ? `https://covers.openlibrary.org/b/id/${covers[0]}-L.jpg` : null;

  // Get description
  let synopsis = 'No synopsis available.';
  const bookDesc = book.description;
  const workDesc = work.description;
  const rawDesc = bookDesc || workDesc;
  if (rawDesc) {
    synopsis =
      typeof rawDesc === 'string' ? rawDesc : (rawDesc as Record<string, string>).value || synopsis;
  }

  // Get subjects as genres
  const genres: string[] = ((work.subjects as string[]) || []).slice(0, 5);

  // Get publishers
  const publishers = (book.publishers as string[]) || [];

  // Get publish date
  let publishDate: string | null = null;
  if (book.publish_date) {
    publishDate = book.publish_date as string;
  }

  const details: Record<string, unknown> = {
    format: book.physical_format
      ? (book.physical_format as string).replace(/\b\w/g, (c: string) => c.toUpperCase())
      : null,
    pages: book.number_of_pages || null,
    publish_date: publishDate,
    authors: authors,
    publishers: publishers.slice(0, 5),
  };

  return {
    media_id: sourceId,
    source: 'openlibrary',
    media_type: 'book',
    source_url: `https://openlibrary.org/books/${sourceId}`,
    title: book.title,
    image_url: coverUrl,
    synopsis,
    genres,
    score: ratingResult.score,
    score_count: ratingResult.scoreCount,
    max_progress: (book.number_of_pages as number) || null,
    details,
    related: null,
  };
}

async function fetchRatings(
  workId: string,
): Promise<{ score: number | null; scoreCount: number | null }> {
  try {
    const resp = await olFetch(`https://openlibrary.org/works/${workId}/ratings.json`);
    if (!resp.ok) return { score: null, scoreCount: null };

    const data = await resp.json();
    const summary = data.summary;
    if (summary?.average && summary?.count) {
      return {
        score: Math.round(summary.average * 2 * 10) / 10,
        scoreCount: summary.count,
      };
    }
  } catch {
    // ignore rating fetch errors
  }
  return { score: null, scoreCount: null };
}

async function fetchAuthors(work: Record<string, unknown>): Promise<string[] | null> {
  const authorEntries = work.authors as Array<{ author: { key: string } }> | undefined;
  if (!authorEntries || authorEntries.length === 0) return null;

  const names: string[] = [];

  await Promise.all(
    authorEntries.map(async (entry) => {
      if (!entry.author?.key) return;
      try {
        const resp = await olFetch(`https://openlibrary.org${entry.author.key}.json`);
        if (resp.ok) {
          const data = await resp.json();
          if (data.name) names.push(data.name);
        }
      } catch {
        // skip failed author fetches
      }
    }),
  );

  return names.length > 0 ? names : null;
}
