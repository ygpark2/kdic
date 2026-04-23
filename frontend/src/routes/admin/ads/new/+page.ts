import { loadAdminJson } from '$lib/admin';
import type { AdminAdsResponse } from '$lib/types';

export async function load({ fetch }) {
  return loadAdminJson<AdminAdsResponse>(fetch, '/api/admin/ads', 'Failed to load ad options.');
}
