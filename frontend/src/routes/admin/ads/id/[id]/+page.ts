import { loadAdminJson } from '$lib/admin';
import type { AdminAdDetailResponse } from '$lib/types';

export async function load({ fetch, params }) {
  return loadAdminJson<AdminAdDetailResponse>(
    fetch,
    `/api/admin/ads/${params.id}`,
    'Failed to load ad.'
  );
}
