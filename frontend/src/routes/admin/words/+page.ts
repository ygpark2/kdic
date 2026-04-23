import { loadAdminJson } from '$lib/admin';
import type { AdminWordsResponse } from '$lib/types';

export async function load({ fetch }) {
  return loadAdminJson<AdminWordsResponse>(fetch, '/api/admin/words', 'Failed to load words.');
}
