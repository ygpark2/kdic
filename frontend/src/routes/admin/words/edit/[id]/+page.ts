import { loadAdminJson } from '$lib/admin';
import type { AdminWordDetailResponse } from '$lib/types';

export async function load({ fetch, params }) {
  return loadAdminJson<AdminWordDetailResponse>(
    fetch,
    `/api/admin/words/${params.id}`,
    'Failed to load word.'
  );
}
