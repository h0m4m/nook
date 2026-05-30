export interface SearchResult {
  media_id: string;
  source: string;
  media_type: string;
  title: string;
  image_url: string | null;
  year: string | null;
  score: number | null;
}

export interface SearchResponse {
  results: SearchResult[];
  page: number;
  total_pages: number;
  per_page: number;
}

export interface MediaDetail {
  media_id: string;
  source: string;
  media_type: string;
  source_url: string;
  title: string;
  image_url: string | null;
  synopsis: string;
  genres: string[];
  score: number | null;
  score_count: number | null;
  max_progress: number | null;
  details: Record<string, unknown>;
  related: { recommendations: SearchResult[] } | null;
  db_id?: string;
}
