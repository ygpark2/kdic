import { apiFetch } from '$lib/api';
import type { SearchResponse } from '$lib/types';

export async function load({ fetch, url }) {
  const q = url.searchParams.get('q')?.trim() ?? '';
  const path = q ? `/api/search?q=${encodeURIComponent(q)}` : '/api/search';
  const data = await apiFetch<SearchResponse>(fetch, path);
  return { ...data, q };
}
