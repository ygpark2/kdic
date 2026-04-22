import { apiFetch } from '$lib/api';
import type { WordDetailResponse } from '$lib/types';

export async function load({ fetch, params }) {
  return apiFetch<WordDetailResponse>(fetch, `/api/word/${params.id}`);
}
