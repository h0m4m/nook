import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import * as thetvdb from '../_shared/providers/thetvdb.ts';
import * as kitsu from '../_shared/providers/kitsu.ts';
import * as openlibrary from '../_shared/providers/openlibrary.ts';
import * as igdb from '../_shared/providers/igdb.ts';
import type { SearchResult, SearchResponse } from '../_shared/types.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { query, media_type, page = 1, warm = false } = await req.json();

    // Warm ping (from a scheduled cron job): keep the worker hot and pre-fetch
    // provider auth tokens so real searches skip the cold-start + token round-trip.
    if (warm) {
      await Promise.allSettled([thetvdb.warm(), igdb.warm()]);
      return new Response(JSON.stringify({ warmed: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!query || !media_type) {
      return new Response(JSON.stringify({ error: 'query and media_type are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // DB-first search: check media_items cache for matches. Serving from the
    // (now trigram-indexed) catalog avoids the slow external provider round-trip;
    // the threshold is the min number of good cached matches before we skip it.
    const CACHE_HIT_THRESHOLD = 6;
    const cached = await searchCachedMedia(query, media_type, page);
    if (cached && cached.results.length >= CACHE_HIT_THRESHOLD) {
      return new Response(JSON.stringify(cached), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300',
        },
      });
    }

    // Fall through to provider
    let result: SearchResponse;

    switch (media_type) {
      case 'movie':
      case 'tv':
        result = await thetvdb.search(media_type, query, page);
        break;
      case 'anime':
      case 'manga':
        result = await kitsu.search(media_type, query, page);
        break;
      case 'book':
        result = await openlibrary.search(query, page);
        break;
      case 'game':
        result = await igdb.search(query, page);
        break;
      default:
        return new Response(JSON.stringify({ error: `Unsupported media_type: ${media_type}` }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    // Upsert search results into media_items catalog (fire-and-forget)
    cacheSearchResults(result.results).catch((err) =>
      console.error('search cache upsert error:', err),
    );

    return new Response(JSON.stringify(result), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300',
      },
    });
  } catch (error) {
    console.error('search-media error:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Internal server error',
      }),
      {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});

async function searchCachedMedia(
  query: string,
  mediaType: string,
  page: number,
): Promise<SearchResponse | null> {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const limit = 24;
    const offset = (page - 1) * limit;

    const { data, error } = await supabase
      .from('media_items')
      .select('source, source_id, media_type, title, image_url, year, score')
      .eq('media_type', mediaType)
      .ilike('title', `%${query}%`)
      .order('score', { ascending: false, nullsFirst: false })
      .range(offset, offset + limit - 1);

    if (error || !data || data.length === 0) return null;

    // Sort by title relevance: exact match → starts with → contains
    const q = query.toLowerCase();
    const ranked = (data as Record<string, unknown>[]).slice().sort((a, b) => {
      const ta = (a.title as string).toLowerCase();
      const tb = (b.title as string).toLowerCase();
      const scoreA = ta === q ? 0 : ta.startsWith(q) ? 1 : 2;
      const scoreB = tb === q ? 0 : tb.startsWith(q) ? 1 : 2;
      return scoreA - scoreB;
    });

    const results: SearchResult[] = ranked.map((row) => ({
      media_id: row.source_id as string,
      source: row.source as string,
      media_type: row.media_type as string,
      title: row.title as string,
      image_url: (row.image_url as string) || null,
      year: (row.year as string) || null,
      score: (row.score as number) || null,
    }));

    return {
      results,
      page,
      total_pages: results.length === limit ? page + 1 : page,
      per_page: limit,
    };
  } catch {
    return null;
  }
}

async function cacheSearchResults(results: SearchResult[]): Promise<void> {
  if (!results || results.length === 0) return;

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const rows = results.map((r) => ({
    source: r.source,
    source_id: r.media_id,
    media_type: r.media_type,
    title: r.title,
    image_url: r.image_url,
    year: r.year,
    score: r.score,
  }));

  await supabase
    .from('media_items')
    .upsert(rows, { onConflict: 'source,source_id', ignoreDuplicates: false })
    .select('id');
}
