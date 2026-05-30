import { createClient } from 'jsr:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import * as thetvdb from '../_shared/providers/tmdb.ts';
import * as kitsu from '../_shared/providers/mal.ts';
import * as openlibrary from '../_shared/providers/openlibrary.ts';
import type { MediaDetail } from '../_shared/types.ts';

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { source, source_id, media_type } = await req.json();

    if (!source || !source_id || !media_type) {
      return new Response(
        JSON.stringify({
          error: 'source, source_id, and media_type are required',
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    let detail: MediaDetail;

    switch (source) {
      case 'thetvdb':
        detail = await thetvdb.detail(source_id, media_type);
        break;
      case 'kitsu':
        detail = await kitsu.detail(source_id, media_type);
        break;
      case 'openlibrary':
        detail = await openlibrary.detail(source_id);
        break;
      default:
        return new Response(JSON.stringify({ error: `Unsupported source: ${source}` }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    // Upsert into media_items using service role
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: upserted, error: dbError } = await supabase
      .from('media_items')
      .upsert(
        {
          source: detail.source,
          source_id: detail.media_id,
          media_type: detail.media_type,
          title: detail.title,
          image_url: detail.image_url,
          year: detail.details.release_date
            ? String(detail.details.release_date).substring(0, 4)
            : detail.details.start_date
              ? String(detail.details.start_date).substring(0, 4)
              : detail.details.first_air_date
                ? String(detail.details.first_air_date).substring(0, 4)
                : detail.details.publish_date
                  ? String(detail.details.publish_date).substring(0, 4)
                  : null,
          genres: detail.genres,
          score: detail.score,
          score_count: detail.score_count,
          synopsis: detail.synopsis,
          details: detail.details,
        },
        { onConflict: 'source,source_id' },
      )
      .select('id')
      .single();

    if (dbError) {
      console.error('media_items upsert error:', dbError);
    }

    const response = {
      ...detail,
      db_id: upserted?.id || null,
    };

    return new Response(JSON.stringify(response), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600',
      },
    });
  } catch (error) {
    console.error('media-detail error:', error);
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
